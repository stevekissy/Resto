import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../models/client_models.dart';
import '../services/firebase_service.dart';
import '../services/client_firebase_service.dart';
import '../services/print_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  /// true si Firebase.initializeApp() a réussi dans main()
  /// Accessible depuis l'UI pour afficher un badge de statut
  final bool firebaseReady;

  // FirebaseService créé seulement si Firebase est initialisé
  FirebaseService? _firebaseInstance;
  FirebaseService get _firebase {
    _firebaseInstance ??= FirebaseService();
    return _firebaseInstance!;
  }

  // ── Streams Firestore ──
  StreamSubscription? _subUsers;
  StreamSubscription? _subProducts;
  StreamSubscription? _subOrders;
  StreamSubscription? _subStock;
  StreamSubscription? _subMessages;
  StreamSubscription? _subSuppliers;
  StreamSubscription? _subSupplierOrders;
  StreamSubscription? _subSupplierPayments;
  StreamSubscription? _subAttendances;
  StreamSubscription? _subDailyCharges;
  StreamSubscription? _subPermissions;
  StreamSubscription? _subCategories;
  StreamSubscription? _subInvoiceHistory;
  StreamSubscription? _subIncomingCall;
  StreamSubscription? _subContracts;
  StreamSubscription? _subContractAlerts;
  StreamSubscription? _subSalaries;
  StreamSubscription? _subSalaryPayments;
  StreamSubscription? _subReservations;
  StreamSubscription? _subReservationPayments;
  StreamSubscription? _subReservationAlerts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // =================== CURRENT USER ===================
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  // =================== USERS ===================
  List<AppUser> _users = [];
  List<AppUser> get users => _users;

  // =================== ORDERS ===================
  List<Order> _orders = [];
  List<Order> get orders => _orders;
  List<Order> get pendingOrders => _orders.where((o) => o.status == OrderStatus.pending).toList();
  List<Order> get preparingOrders => _orders.where((o) => o.status == OrderStatus.preparing).toList();
  List<Order> get readyOrders => _orders.where((o) {
    // Commandes en ligne : basé sur kitchenStatus
    if (o.isOnlineOrder) return o.sentToKitchen && o.kitchenStatus == 'ready';
    // Commandes POS : basé sur status
    return o.status == OrderStatus.ready;
  }).toList();
  List<Order> get servedOrders => _orders.where((o) => o.status == OrderStatus.served).toList();

  // ── Getters caisse 2 étapes ─────────────────────────────────────────
  /// Commandes prêtes/servies non encore encaissées (Tab 1 — bouton Encaisser)
  List<Order> get pendingCashoutOrders => _orders.where((o) =>
    (o.status == OrderStatus.ready || o.status == OrderStatus.served) &&
    o.cashStatus == CashStatus.pending_cashout &&
    !o.isPaid
  ).toList();

  /// Commandes avec facture d'encaissement provisoire, en attente de règlement (Tab 2 — bouton Régler)
  List<Order> get awaitingPaymentOrders => _orders.where((o) =>
    o.cashStatus == CashStatus.awaiting_payment && !o.isPaid
  ).toList();

  /// Commandes réglées définitivement (Tab 3 — Point de caisse)
  List<Order> get settledOrders => _orders.where((o) =>
    o.settlementInvoiceGenerated && o.isPaid
  ).toList();

  // =================== PRODUCTS ===================
  List<Product> _products = [];
  List<Product> get products => _products;
  List<Product> get availableProducts => _products.where((p) => p.isAvailable && p.stockQuantity > 0).toList();

  // =================== STOCK ===================
  List<StockItem> _stockItems = [];
  List<StockItem> get stockItems => _stockItems;
  List<StockItem> get lowStockItems => _stockItems.where((s) => s.isLow).toList();
  List<StockItem> get outOfStockItems => _stockItems.where((s) => s.isOut).toList();

  // =================== ATTENDANCE ===================
  List<Attendance> _attendances = [];
  List<Attendance> get attendances => _attendances;

  // =================== MESSAGES ===================
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;
  List<ChatMessage> get groupMessages => _messages.where((m) => m.receiverId == null).toList();

  // =================== SUPPLIERS ===================
  List<Supplier> _suppliers = [];
  /// Uniquement les fournisseurs actifs (non soft-deleted)
  List<Supplier> get suppliers => _suppliers.where((s) => s.active).toList();
  /// Tous les fournisseurs (y compris désactivés) pour les références
  List<Supplier> get allSuppliers => _suppliers;

  List<SupplierOrder> _supplierOrders = [];
  List<SupplierOrder> get supplierOrders => _supplierOrders;

  // Filtres commandes
  List<SupplierOrder> get paidOrders =>
      _supplierOrders.where((o) => o.paymentStatus == SupplierPaymentStatus.paid).toList();
  List<SupplierOrder> get partialOrders =>
      _supplierOrders.where((o) => o.paymentStatus == SupplierPaymentStatus.partial).toList();
  List<SupplierOrder> get unpaidOrders =>
      _supplierOrders.where((o) => o.paymentStatus == SupplierPaymentStatus.unpaid).toList();
  List<SupplierOrder> get overdueOrders =>
      _supplierOrders.where((o) => o.isOverdue).toList();

  // Totaux commandes
  double get totalOrdersAmount =>
      _supplierOrders.fold(0, (s, o) => s + o.totalAmount);
  double get totalPaidAmount =>
      _supplierOrders.fold(0, (s, o) => s + o.paidAmount);
  double get totalRemainingAmount =>
      _supplierOrders.fold(0, (s, o) => s + o.remainingAmount);

  // Paiements
  List<SupplierPayment> _supplierPayments = [];
  List<SupplierPayment> get supplierPayments => _supplierPayments;
  List<SupplierPayment> paymentsForOrder(String orderId) =>
      _supplierPayments.where((p) => p.supplierOrderId == orderId).toList();

  // =================== CATEGORIES PERSONNALISÉES (Firestore) ===================
  static const _defaultCategories = ['Plats', 'Accompagnements', 'Boissons', 'Desserts', 'Entrées', 'Snacks'];
  List<String> _customCategories = List.from(_defaultCategories);
  List<String> get customCategories => _customCategories;

  // ── Historique factures ──────────────────────────────────────────────
  List<Map<String, dynamic>> _invoiceHistory = [];
  List<Map<String, dynamic>> get invoiceHistory => _invoiceHistory;

  // =================== CONTRACTS ===================
  List<EmployeeContract> _contracts = [];
  List<EmployeeContract> get contracts => _contracts;
  List<EmployeeContract> get activeContracts =>
      _contracts.where((c) => c.computedStatus == ContractStatus.actif).toList();
  List<EmployeeContract> get expiringContracts =>
      _contracts.where((c) => c.computedStatus == ContractStatus.bientotExpire).toList();
  List<EmployeeContract> get expiredContracts =>
      _contracts.where((c) => c.computedStatus == ContractStatus.expire).toList();

  List<ContractAlert> _contractAlerts = [];
  List<ContractAlert> get contractAlerts => _contractAlerts;
  int get unreadContractAlertsCount => _contractAlerts.where((a) => !a.isRead).length;

  // ── Salaires ─────────────────────────────────────────────────────────
  List<EmployeeSalary> _salaries = [];
  List<EmployeeSalary> get salaries => _salaries;
  List<SalaryPayment>  _salaryPayments = [];
  List<SalaryPayment>  get salaryPayments => _salaryPayments;

  List<EmployeeSalary> salariesForPeriod(int annee, int mois) =>
      _salaries.where((s) => s.annee == annee && s.mois == mois).toList();

  List<EmployeeSalary> salariesForEmployee(String employeeId) =>
      _salaries.where((s) => s.employeeId == employeeId).toList();

  List<SalaryPayment> paymentsForSalary(String salaryId) =>
      _salaryPayments.where((p) => p.salaryId == salaryId).toList();

  // ── Réservations & Événements ─────────────────────────────────────────
  List<Reservation>        _reservations        = [];
  List<Reservation>        get reservations     => _reservations;
  List<ReservationPayment> _reservationPayments = [];
  List<ReservationPayment> get reservationPayments => _reservationPayments;
  List<ReservationAlert>   _reservationAlerts   = [];
  List<ReservationAlert>   get reservationAlerts => _reservationAlerts;

  List<Reservation> get reservationsToday =>
      _reservations.where((r) => r.isToday).toList();

  List<Reservation> get reservationsAVenir =>
      _reservations.where((r) => !r.isPast && r.status != ReservationStatus.annule).toList();

  List<Reservation> get reservationsConfirmees =>
      _reservations.where((r) => r.status == ReservationStatus.confirme).toList();

  List<Reservation> get reservationsEnAttente =>
      _reservations.where((r) => r.status == ReservationStatus.enAttente).toList();

  List<Reservation> get reservationsAnnulees =>
      _reservations.where((r) => r.status == ReservationStatus.annule).toList();

  double get reservationsMontantAttendu =>
      _reservations.where((r) => r.status != ReservationStatus.annule)
          .fold(0, (s, r) => s + r.montantNet);

  double get reservationsMontantEncaisse =>
      _reservations.fold(0, (s, r) => s + r.montantPaye);

  double get reservationsSoldeRestant =>
      reservationsMontantAttendu - reservationsMontantEncaisse;

  List<ReservationPayment> paymentsForReservation(String reservationId) =>
      _reservationPayments.where((p) => p.reservationId == reservationId).toList();

  List<ReservationAlert> get unreadReservationAlerts =>
      _reservationAlerts.where((a) => !a.isRead).toList();

  // ── Appel entrant ────────────────────────────────────────────────────
  CallSession? _incomingCall;
  CallSession? get incomingCall => _incomingCall;
  String? _activeCallId;
  String? get activeCallId => _activeCallId;

  // ── Méthodes catégories avec persistance Firestore ───────────────────

  void addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_customCategories.contains(trimmed)) {
      _customCategories.add(trimmed);
      notifyListeners();
      _firebase.addCategoryFirestore(trimmed).catchError((e) =>
          debugPrint('[AppProvider] addCategory Firestore error: $e'));
    }
  }

  void renameCategory(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isNotEmpty && !_customCategories.contains(trimmed)) {
      final idx = _customCategories.indexOf(oldName);
      if (idx != -1) {
        _customCategories[idx] = trimmed;
        for (final p in _products) {
          if (p.category == oldName) p.category = trimmed;
        }
        notifyListeners();
        _firebase.renameCategoryFirestore(oldName, trimmed).catchError((e) =>
            debugPrint('[AppProvider] renameCategory Firestore error: $e'));
      }
    }
  }

  void deleteCategory(String name) {
    _customCategories.remove(name);
    final fallback = _customCategories.isNotEmpty ? _customCategories.first : 'Divers';
    for (final p in _products) {
      if (p.category == name) p.category = fallback;
    }
    notifyListeners();
    _firebase.deleteCategoryFirestore(name).catchError((e) =>
        debugPrint('[AppProvider] deleteCategory Firestore error: $e'));
  }

  // =================== CHARGES DU JOUR ===================
  // Alimentée exclusivement par le stream Firestore daily_charges
  List<Map<String, dynamic>> _charges = [];

  /// Liste des charges du jour (filtrée par le stream Firestore côté client)
  List<Map<String, dynamic>> get dailyCharges => _charges;

  /// Alias conservé pour compatibilité avec cashier_screen.dart
  List<Map<String, dynamic>> get todayCharges => _charges;

  /// Total des charges du jour (déjà filtré par le stream)
  double get todayTotalCharges =>
      _charges.fold(0.0, (sum, c) => sum + ((c['amount'] as num?)?.toDouble() ?? 0.0));

  Future<void> addDailyCharge({required String label, required double amount, String? note}) async {
    final id        = _uuid.v4();
    final createdBy = _currentUser?.name ?? 'Admin';
    try {
      await _firebase.addDailyCharge(
        id: id, label: label, amount: amount,
        note: note ?? '', createdBy: createdBy,
      );
      // Le stream Firestore met _charges à jour automatiquement
    } catch (e) {
      debugPrint('[AppProvider] addDailyCharge erreur: $e');
      rethrow;
    }
  }

  Future<void> removeDailyCharge(String id) async {
    try {
      await _firebase.removeDailyCharge(id);
      // Le stream Firestore met _charges à jour automatiquement
    } catch (e) {
      debugPrint('[AppProvider] removeDailyCharge erreur: $e');
      rethrow;
    }
  }

  // =================== NOTIFICATION CALLBACK ===================
  Function(Order)? onNewOrder;
  Function(Order)? onOrderDelayed;

  Timer? _alertTimer;

  AppProvider({this.firebaseReady = false}) {
    // ✅ PAS DE DONNÉES DÉMO — toutes les données viennent exclusivement de Firestore
    try { _startAlertTimer(); } catch (e) { debugPrint('[AppProvider] alertTimer: $e'); }
    // Aucun accès Firebase dans le constructeur
  }

  /// Appelé par main() APRÈS Firebase.initializeApp() + setPersistence.
  ///
  /// IMPORTANT : utilise resolveAuthState() (authStateChanges().first)
  /// et NON currentUser synchrone — sur Web, currentUser peut être null
  /// pendant ~100-300ms pendant que Firebase recharge le token localStorage.
  ///
  /// Retourne true si une session active a été restaurée, false sinon.
  Future<bool> checkExistingSession() async {
    if (!firebaseReady) return false;
    // ─── LOG DIAGNOSTIC ───────────────────────────────────────────────
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('[DIAG][app_provider.dart:224] checkExistingSession() — resolveAuthState...');
    debugPrint('════════════════════════════════════════════════════════');
    // ──────────────────────────────────────────────────────────────────
    try {
      // Attendre que Firebase Auth ait chargé la session depuis localStorage
      final fbUser = await _firebase.resolveAuthState();
      if (fbUser == null) {
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:229] resolveAuthState = NULL → hasSession=false');
        // ────────────────────────────────────────────────────────────
        debugPrint('[AppProvider] checkExistingSession → aucune session active');
        return false;
      }
      debugPrint('[AppProvider] ✅ Session Auth restaurée : ${fbUser.email}');
      // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:233] resolveAuthState OK → uid=${fbUser.uid} email=${fbUser.email}');
      debugPrint('[DIAG][app_provider.dart:233] getUserByUid Firestore...');
      // ──────────────────────────────────────────────────────────────

      // Lire le profil Firestore pour vérifier active + canLogin
      final firestoreUser = await _firebase.getUserByUid(fbUser.uid);

      // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:236] getUserByUid → ${firestoreUser?.name ?? "NULL"}');
      if (firestoreUser != null) {
        debugPrint('[DIAG][app_provider.dart:236]   isActive=${firestoreUser.isActive} canLogin=${firestoreUser.canLogin} role=${firestoreUser.role}');
      }
      // ──────────────────────────────────────────────────────────────

      if (firestoreUser != null) {
        // Bloquer les clients de l'interface staff
        if (firestoreUser.role == UserRole.client) {
          debugPrint('[DIAG][app_provider.dart:239] ▶▶▶ signOut() — role=client → SESSION STAFF REFUSÉE');
          await _firebase.signOut();
          return false;
        }
        // Vérification sécurité : active + canLogin obligatoires
        if (!firestoreUser.isActive || !firestoreUser.canLogin) {
          // ─── LOG DIAGNOSTIC ─────────────────────────────────────
          debugPrint('[DIAG][app_provider.dart:241] ▶▶▶ signOut() — isActive=${firestoreUser.isActive} canLogin=${firestoreUser.canLogin}');
          debugPrint('[DIAG][app_provider.dart:241]   REDIRECTION LOGIN DÉCLENCHÉE PAR : app_provider.dart — checkExistingSession — ligne 241');
          // ────────────────────────────────────────────────────────
          await _firebase.signOut();
          debugPrint('[AppProvider] Session refusée : active=${firestoreUser.isActive} canLogin=${firestoreUser.canLogin}');
          return false;
        }
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:245] ✅ Session restaurée — profil valide');
        // ────────────────────────────────────────────────────────────
        _currentUser = firestoreUser;
      } else {
        // Doc absent — créer avec rôle déduit de l'email
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:247] Doc absent → ensureUserDoc()');
        // ────────────────────────────────────────────────────────────
        final role = _roleFromEmail(fbUser.email ?? '');
        final displayName = _displayNameFromEmail(fbUser.email ?? '');
        final newUser = await _firebase.ensureUserDoc(
          fbUser.uid, fbUser.email ?? '', role, displayName,
        );
        _currentUser = newUser;
      }

      // Démarrer les streams Firestore temps réel
      _startFirebaseStreams();
      notifyListeners();
      // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:259] checkExistingSession → return true');
      // ──────────────────────────────────────────────────────────────
      return true;
    } catch (e) {
      // ─── LOG DIAGNOSTIC ───────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:261] checkExistingSession CATCH: $e');
      // ──────────────────────────────────────────────────────────────
      debugPrint('[AppProvider] checkExistingSession erreur: $e');
      return false;
    }
  }

  void _startAlertTimer() {
    _alertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkDelayedOrders();
    });
  }

  void _checkDelayedOrders() {
    for (var order in pendingOrders) {
      if (order.elapsedMinutes >= 20) {
        onOrderDelayed?.call(order);
      }
    }
  }

  // =================== LOGIN Firebase ===================
  Future<bool> loginWithFirebase(String email, String password) async {
    if (!firebaseReady) {
      _errorMessage = 'Firebase non initialisé. Relancez l\'application.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ÉTAPE 1 — Authentification Firebase Auth
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('[DIAG][app_provider.dart:293] loginWithFirebase — ÉTAPE 1 signIn');
      debugPrint('[DIAG][app_provider.dart:293]   email = $email');
      debugPrint('════════════════════════════════════════════════════════');
      // ────────────────────────────────────────────────────────────────
      final credential = await _firebase.signIn(email, password);
      if (credential?.user == null) throw Exception('Aucun utilisateur retourné par Firebase');

      final uid  = credential!.user!.uid;
      final mail = credential.user!.email ?? email;

      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:299] ÉTAPE 1 OK — Auth Firebase');
      debugPrint('[DIAG][app_provider.dart:299]   UID   = $uid');
      debugPrint('[DIAG][app_provider.dart:299]   EMAIL = $mail');
      // ────────────────────────────────────────────────────────────────

      // ÉTAPE 2 — Lire le profil Firestore (nécessaire pour vérifier active + canLogin)
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:300] ÉTAPE 2 — getUserByUid Firestore...');
      // ────────────────────────────────────────────────────────────────
      final firestoreUser = await _firebase.getUserByUid(uid);

      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:302] getUserByUid retourné');
      debugPrint('[DIAG][app_provider.dart:302]   firestoreUser = ${firestoreUser?.name ?? "NULL (doc absent)"}');
      if (firestoreUser != null) {
        debugPrint('[DIAG][app_provider.dart:302]   role     = ${firestoreUser.role}');
        debugPrint('[DIAG][app_provider.dart:302]   isActive = ${firestoreUser.isActive}');
        debugPrint('[DIAG][app_provider.dart:302]   canLogin = ${firestoreUser.canLogin}');
      }
      // ────────────────────────────────────────────────────────────────

      if (firestoreUser != null) {
        // VÉRIFICATION SÉCURITÉ 0 : bloquer les clients de l'interface staff
        if (firestoreUser.role == UserRole.client) {
          debugPrint('[DIAG][app_provider.dart:303] ▶▶▶ signOut() — role=client → ACCÈS STAFF REFUSÉ');
          await _firebase.signOut();
          _errorMessage = 'Ce compte est un compte client. Utilisez l\'Espace Client pour vous connecter.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // VÉRIFICATION SÉCURITÉ 1 : active = true obligatoire
        if (!firestoreUser.isActive) {
          // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
          debugPrint('[DIAG][app_provider.dart:305] ▶▶▶ signOut() — isActive=false → RETOUR LOGIN');
          debugPrint('[DIAG][app_provider.dart:305]   REDIRECTION LOGIN DÉCLENCHÉE PAR : app_provider.dart — loginWithFirebase — ligne 305');
          // ────────────────────────────────────────────────────────────
          await _firebase.signOut(); // Déconnecter immédiatement
          _errorMessage = 'Accès non autorisé. Contactez l\'administrateur.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // VÉRIFICATION SÉCURITÉ 2 : canLogin = true obligatoire
        if (!firestoreUser.canLogin) {
          // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
          debugPrint('[DIAG][app_provider.dart:313] ▶▶▶ signOut() — canLogin=false → RETOUR LOGIN');
          debugPrint('[DIAG][app_provider.dart:313]   REDIRECTION LOGIN DÉCLENCHÉE PAR : app_provider.dart — loginWithFirebase — ligne 313');
          // ────────────────────────────────────────────────────────────
          await _firebase.signOut(); // Déconnecter immédiatement
          _errorMessage = 'Accès non autorisé. Contactez l\'administrateur.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // ✅ Tout est valide — utiliser le profil Firestore complet
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:320] ✅ Profil Firestore valide');
        debugPrint('[DIAG][app_provider.dart:320]   AUTH CONNECTÉ');
        debugPrint('[DIAG][app_provider.dart:320]   UID         : $uid');
        debugPrint('[DIAG][app_provider.dart:320]   EMAIL       : $mail');
        debugPrint('[DIAG][app_provider.dart:320]   ROLE        : ${firestoreUser.role}');
        debugPrint('[DIAG][app_provider.dart:320]   ACTIVE      : ${firestoreUser.isActive}');
        debugPrint('[DIAG][app_provider.dart:320]   CANLOGIN    : ${firestoreUser.canLogin}');
        // ────────────────────────────────────────────────────────────
        _currentUser = firestoreUser;
      } else {
        // Document Firestore absent (utilisateur créé directement dans Auth console)
        // Créer le doc automatiquement avec les permissions par défaut
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:322] Doc Firestore absent — ensureUserDoc()');
        // ────────────────────────────────────────────────────────────
        final role = _roleFromEmail(mail);
        final displayName = _displayNameFromEmail(mail);
        final newUser = await _firebase.ensureUserDoc(uid, mail, role, displayName);
        // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
        debugPrint('[DIAG][app_provider.dart:327] ensureUserDoc() OK → role=$role displayName=$displayName');
        // ────────────────────────────────────────────────────────────
        _currentUser = newUser;
      }

      notifyListeners(); // UI réactive

      // ÉTAPE 3 — Initialiser les documents permissions si absents (fire-and-forget)
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:333] ÉTAPE 3 — initRolePermissions() (fire-and-forget)');
      // ────────────────────────────────────────────────────────────────
      _firebase.initRolePermissions().catchError((e) {
        debugPrint('[DIAG][app_provider.dart:333] initRolePermissions ERREUR: $e');
        debugPrint('[AppProvider] initRolePermissions: $e');
      });

      // ÉTAPE 4 — Démarrer les streams temps réel
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:336] ÉTAPE 4 — _startFirebaseStreams()');
      // ────────────────────────────────────────────────────────────────
      _startFirebaseStreams();

      _isLoading = false;
      notifyListeners();
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:340] loginWithFirebase → return true');
      debugPrint('[DIAG][app_provider.dart:340]   currentUser = ${_currentUser?.name}');
      debugPrint('[DIAG][app_provider.dart:340]   PERMISSIONS = ${_rolePermissions.keys.join(", ")}');
      // ────────────────────────────────────────────────────────────────
      return true;

    } catch (e, st) {
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:343] loginWithFirebase CATCH — exception inattendue');
      debugPrint('[DIAG][app_provider.dart:343]   ERREUR = $e');
      // ────────────────────────────────────────────────────────────────
      debugPrint('[AppProvider] loginWithFirebase ERROR: $e');
      debugPrint('[AppProvider] STACKTRACE: $st');
      _errorMessage = _mapAuthError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  UserRole _roleFromEmail(String email) {
    final low = email.toLowerCase();
    if (low.contains('admin'))                                    return UserRole.admin;
    if (low.contains('manager'))                                  return UserRole.manager;
    if (low.contains('caiss') || low.contains('cashier'))        return UserRole.cashier;
    if (low.contains('cuisine') || low.contains('kitchen'))      return UserRole.kitchen;
    return UserRole.server;
  }

  String _displayNameFromEmail(String email) {
    final namePart = email.split('@').first;
    if (namePart.isEmpty) return 'Utilisateur';
    return namePart[0].toUpperCase() +
        namePart.substring(1).replaceAll(RegExp(r'[._0-9]+'), ' ').trim();
  }

  // Compatibilité — non utilisé
  bool login(String email, String password) => false;

  String _mapAuthError(String error) {
    final e = error.toLowerCase();
    if (e.contains('user-not-found') || e.contains('no user record'))
      return 'Aucun compte trouvé avec cet email.';
    if (e.contains('wrong-password') || e.contains('invalid-credential') ||
        e.contains('invalid-login-credentials'))
      return 'Email ou mot de passe incorrect.';
    if (e.contains('too-many-requests'))
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    if (e.contains('network-request-failed') || e.contains('network'))
      return 'Pas de connexion Internet. Vérifiez votre réseau.';
    if (e.contains('user-disabled')) return 'Ce compte a été désactivé.';
    if (e.contains('invalid-email')) return 'Format d\'email invalide.';
    if (e.contains('firebase_auth') || e.contains('platformexception'))
      return 'Erreur Firebase Auth. Vérifiez votre connexion Internet.';
    // Retourner le message brut pour diagnostic (tronqué à 100 chars)
    final raw = error.replaceAll('\n', ' ').trim();
    return raw.length > 100 ? raw.substring(0, 100) : raw;
  }

  // =================== STREAMS FIRESTORE ===================
  void _startFirebaseStreams() {
    // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
    debugPrint('[DIAG][app_provider.dart:493] _startFirebaseStreams() appelé');
    // ────────────────────────────────────────────────────────────────
    // GARDE : ne jamais ouvrir de stream Firestore si Firebase non prêt ou user non connecté
    if (!firebaseReady) {
      debugPrint('[AppProvider] _startFirebaseStreams ignoré — Firebase non prêt');
      return;
    }
    final fbUser = _firebase.currentFirebaseUser;
    if (fbUser == null) {
      // ─── LOG DIAGNOSTIC ─────────────────────────────────────────
      debugPrint('[DIAG][app_provider.dart:500] ▶▶ _startFirebaseStreams IGNORÉ — currentFirebaseUser==null AU MOMENT DE L\'APPEL');
      // ────────────────────────────────────────────────────────────
      debugPrint('[AppProvider] _startFirebaseStreams ignoré — currentUser == null');
      return;
    }
    debugPrint('[AppProvider] Démarrage streams Firestore pour ${fbUser.email}');

    _stopFirebaseStreams(); // Annuler les anciens streams si existants

    // ✅ 100% Firestore — on accepte TOUJOURS la liste reçue, même vide
    // Si Firestore renvoie [], l'UI affiche "Aucune donnée enregistrée"
    _subUsers = _firebase.streamUsers().listen(
      (list) { _users = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.users] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subProducts = _firebase.streamProducts().listen(
      (list) { _products = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.products] ERREUR: $e'); },
      cancelOnError: false,
    );
    // IDs des commandes déjà connues — pour ne déclencher le son que sur les nouvelles
    final Set<String> _knownOrderIds = {};
    _subOrders = _firebase.streamOrders().listen(
      (list) {
        final newOrders = list.where((o) => !_knownOrderIds.contains(o.id)).toList();
        for (final o in newOrders) {
          _knownOrderIds.add(o.id);
          // Ne pas sonner au premier chargement (liste déjà existante au démarrage)
          if (_knownOrderIds.length > list.length - newOrders.length) {
            // Commande en ligne : notification spéciale prioritaire
            final isOnline = (o.source == 'online' || o.tableNumber == 'Livraison Yango'
                || o.tableNumber == 'À Emporter');
            if (o.isUrgent) {
              NotificationService().trigger(
                NotifEvent.commandeUrgente,
                message: '🚨 Commande urgente #${o.orderNumber} — Table ${o.tableNumber}',
              );
            } else if (isOnline) {
              NotificationService().trigger(
                NotifEvent.nouvelleCommandeEnLigne,
                message: '📱 NOUVELLE COMMANDE EN LIGNE #${o.orderNumber} — ${o.serverName ?? o.tableNumber}',
              );
            } else {
              NotificationService().trigger(
                NotifEvent.nouvelleCommande,
                message: '🍽️ Nouvelle commande #${o.orderNumber} — Table ${o.tableNumber}',
              );
            }
          }
        }
        // Commandes prêtes — sonner quand statut passe à ready
        for (final o in list) {
          final wasReady = _orders.any((old) => old.id == o.id && old.status == OrderStatus.ready);
          if (!wasReady && o.status == OrderStatus.ready) {
            NotificationService().trigger(
              NotifEvent.commandePrete,
              message: '✅ Commande #${o.orderNumber} prête à servir — Table ${o.tableNumber}',
            );
          }
        }
        _orders = List<Order>.from(list);
        notifyListeners();
      },
      onError: (e) { debugPrint('[stream.orders] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subStock = _firebase.streamStock().listen(
      (list) {
        // Détecter les nouveaux articles en rupture ou stock faible
        for (final item in list) {
          final prev = _stockItems.firstWhere((s) => s.id == item.id, orElse: () => item);
          if (!prev.isOut && item.isOut) {
            NotificationService().trigger(
              NotifEvent.ruptureStock,
              message: '🚫 Rupture de stock : ${item.name}',
            );
          } else if (!prev.isLow && item.isLow && !item.isOut) {
            NotificationService().trigger(
              NotifEvent.stockFaible,
              message: '⚠️ Stock faible : ${item.name} (${item.currentQuantity.toStringAsFixed(0)} ${item.unit})',
            );
          }
        }
        _stockItems = list;
        notifyListeners();
      },
      onError: (e) { debugPrint('[stream.stock] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subMessages = _firebase.streamMessages().listen(
      (list) { _messages = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.messages] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subSuppliers = _firebase.streamSuppliers().listen(
      (list) { _suppliers = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.suppliers] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subSupplierOrders = _firebase.streamSupplierOrders().listen(
      (list) { _supplierOrders = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.supplierOrders] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subSupplierPayments = _firebase.streamSupplierPayments().listen(
      (list) { _supplierPayments = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.supplier_payments] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subAttendances = _firebase.streamAttendances().listen(
      (list) {
        // Attendances peuvent être vides — on accepte []
        _attendances = list;
        notifyListeners();
      },
      onError: (e) { debugPrint('[stream.attendances] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subDailyCharges = _firebase.streamDailyCharges().listen(
      (list) { _charges = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.daily_charges] ERREUR: $e'); },
      cancelOnError: false,
    );

    // Stream permissions Firestore — met à jour en temps réel
    _subPermissions = _firebase.streamRolePermissions().listen(
      (permsMap) {
        _rolePermissions = permsMap;
        notifyListeners();
        debugPrint('[stream.permissions] Permissions rechargées depuis Firestore');
      },
      onError: (e) { debugPrint('[stream.permissions] ERREUR: $e'); },
      cancelOnError: false,
    );

    // Stream catégories depuis Firestore
    _subCategories = _firebase.streamCategories().listen(
      (list) {
        if (list.isNotEmpty) {
          _customCategories = list;
          notifyListeners();
        }
      },
      onError: (e) { debugPrint('[stream.categories] ERREUR: $e'); },
      cancelOnError: false,
    );

    // Initialiser catégories par défaut si vide
    _firebase.initDefaultCategories(_defaultCategories)
        .catchError((e) => debugPrint('[categories.init] $e'));

    // Stream historique factures (caisse)
    _subInvoiceHistory = _firebase.streamInvoiceHistory().listen(
      (list) { _invoiceHistory = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.invoiceHistory] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subContracts = _firebase.streamContracts().listen(
      (list) {
        // Détecter nouveaux contrats proches expiration
        for (final c in list) {
          final alreadyKnown = _contracts.any((old) => old.id == c.id);
          if (!alreadyKnown && c.computedStatus == ContractStatus.bientotExpire) {
            NotificationService().trigger(
              NotifEvent.contratExpiration,
              message: '📋 Contrat proche expiration : ${c.employeeName}',
            );
          }
        }
        _contracts = list; _refreshContractAlerts(); notifyListeners();
      },
      onError: (e) { debugPrint('[stream.contracts] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subContractAlerts = _firebase.streamContractAlerts().listen(
      (list) { _contractAlerts = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.contractAlerts] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subSalaries = _firebase.streamSalaries().listen(
      (list) {
        // Détecter nouveaux salaires impayés
        for (final sal in list) {
          final alreadyKnown = _salaries.any((s) => s.id == sal.id);
          if (!alreadyKnown && sal.paymentStatus == PaymentStatus.nonPaye) {
            NotificationService().trigger(
              NotifEvent.salaireAPayer,
              message: '👥 Salaire à payer : ${sal.employeeName} — ${sal.netAPayer.toStringAsFixed(0)} F CFA',
            );
          }
        }
        _salaries = list;
        notifyListeners();
      },
      onError: (e) { debugPrint('[stream.salaries] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subSalaryPayments = _firebase.streamAllPayments().listen(
      (list) { _salaryPayments = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.salaryPayments] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subReservations = _firebase.streamReservations().listen(
      (list) {
        // Détecter nouvelles réservations aujourd'hui / demain
        final today = DateTime.now();
        for (final r in list) {
          final alreadyKnown = _reservations.any((old) => old.id == r.id);
          if (!alreadyKnown) {
            final d = r.dateEvenement;
            if (d.year == today.year && d.month == today.month && d.day == today.day) {
              NotificationService().trigger(
                NotifEvent.reservationAujourdhui,
                message: '📆 Réservation aujourd\'hui : ${r.nomClient} — ${r.heureDebut}',
              );
            } else {
              final tomorrow = today.add(const Duration(days: 1));
              if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
                NotificationService().trigger(
                  NotifEvent.reservationDemain,
                  message: '🗓️ Réservation demain : ${r.nomClient} — ${r.typeEvenement.label}',
                );
              }
            }
          }
        }
        _reservations = list;
        notifyListeners();
        _generateReservationAlerts();
      },
      onError: (e) { debugPrint('[stream.reservations] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subReservationPayments = _firebase.streamAllReservationPayments().listen(
      (list) { _reservationPayments = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.reservationPayments] ERREUR: $e'); },
      cancelOnError: false,
    );

    _subReservationAlerts = _firebase.streamReservationAlerts().listen(
      (list) { _reservationAlerts = list; notifyListeners(); },
      onError: (e) { debugPrint('[stream.reservationAlerts] ERREUR: $e'); },
      cancelOnError: false,
    );

    // Stream appels entrants (pour l'utilisateur connecté)
    final uid = _currentUser?.id;
    if (uid != null) {
      _subIncomingCall = _firebase.streamIncomingCall(uid).listen(
        (call) {
          _incomingCall = call;
          notifyListeners();
        },
        onError: (e) { debugPrint('[stream.incomingCall] ERREUR: $e'); },
        cancelOnError: false,
      );
    }
  }

  void _stopFirebaseStreams() {
    _subUsers?.cancel();
    _subProducts?.cancel();
    _subOrders?.cancel();
    _subStock?.cancel();
    _subMessages?.cancel();
    _subSuppliers?.cancel();
    _subSupplierOrders?.cancel();
    _subSupplierPayments?.cancel();
    _subAttendances?.cancel();
    _subDailyCharges?.cancel();
    _subPermissions?.cancel();
    _subCategories?.cancel();
    _subInvoiceHistory?.cancel();
    _subIncomingCall?.cancel();
    _subContracts?.cancel();
    _subContractAlerts?.cancel();
    _subSalaries?.cancel();
    _subSalaryPayments?.cancel();
    _subReservations?.cancel();
    _subReservationPayments?.cancel();
    _subReservationAlerts?.cancel();
  }

  /// Déconnexion complète : signOut Firebase + nettoyage local.
  /// Appelé uniquement par un bouton "Déconnexion" explicite de l'utilisateur.
  /// NE PAS appeler automatiquement dans initState, dispose ou guard route.
  Future<void> logout() async {
    // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('[DIAG][app_provider.dart:logout] ▶▶▶ logout() APPELÉ (déconnexion volontaire)');
    debugPrint('[DIAG][app_provider.dart:logout]   currentUser = ${_currentUser?.name ?? "NULL"}');
    debugPrint(StackTrace.current.toString().split('\n').take(6).join('\n'));
    debugPrint('════════════════════════════════════════════════════════');
    // ────────────────────────────────────────────────────────────────
    _stopFirebaseStreams();
    if (_currentUser != null) {
      await _firebase.setUserOnline(_currentUser!.id, false).catchError((_) {});
    }
    await _firebase.signOut().catchError((e) => debugPrint('[logout] $e'));
    _currentUser = null;
    _users = []; _orders = []; _products = []; _stockItems = [];
    _suppliers = []; _supplierOrders = []; _supplierPayments = []; _messages = []; _attendances = [];
    _charges = []; _invoiceHistory = []; _incomingCall = null; _activeCallId = null;
    notifyListeners();
  }

  /// Nettoyage local uniquement (sans signOut Firebase).
  /// Utilisé par _AuthGate quand authStateChanges détecte une déconnexion
  /// déclenchée par Firebase (ex: token expiré) plutôt que par l'utilisateur.
  void clearSessionLocally() {
    // ─── LOG DIAGNOSTIC ─────────────────────────────────────────────
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('[DIAG][app_provider.dart:clearSessionLocally] ▶▶▶ APPELÉ');
    debugPrint('[DIAG][app_provider.dart:clearSessionLocally]   currentUser avant = ${_currentUser?.name ?? "NULL"}');
    debugPrint(StackTrace.current.toString().split('\n').take(6).join('\n'));
    debugPrint('════════════════════════════════════════════════════════');
    // ────────────────────────────────────────────────────────────────
    _stopFirebaseStreams();
    _currentUser = null;
    _users = []; _orders = []; _products = []; _stockItems = [];
    _suppliers = []; _supplierOrders = []; _supplierPayments = []; _messages = []; _attendances = [];
    _charges = []; _invoiceHistory = []; _incomingCall = null; _activeCallId = null;
    notifyListeners();
  }

  // =================== ORDER MANAGEMENT (Firestore) ===================
  // ── Vérification stock avant création de commande ─────────────────────
  /// Retourne la liste des noms produits stock insuffisants.
  /// Seuls les liens obligatoires (mandatory=true) bloquent la commande.
  Future<List<String>> checkStockForItems(List<OrderItem> items) async {
    // Filtrer uniquement les produits avec des liens obligatoires
    final filtered = items.where((item) {
      final product = _products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(id: '', name: '', category: '', price: 0, prepTime: 0),
      );
      return product.stockLinks.any((l) => l.mandatory);
    }).toList();
    if (filtered.isEmpty) return [];
    return _firebase.checkStockAvailability(
      items: filtered,
      products: _products,
    );
  }

  Future<Order> createOrder({
    required String tableNumber,
    required List<OrderItem> items,
    String? serverName,
    String? serverId,
    String? serverEmail,
    String? specialInstructions,
    bool isUrgent = false,
    String orderType = 'dine_in',
  }) async {
    // Numéro de commande unique via transaction Firestore (pas de RAM)
    final orderNumber = await _firebase.getNextOrderNumber();
    final order = Order(
      id: _uuid.v4(),
      orderNumber: orderNumber,
      tableNumber: tableNumber,
      serverName: serverName ?? _currentUser?.name,
      serverId: serverId,
      serverEmail: serverEmail,
      items: items,
      specialInstructions: specialInstructions,
      isUrgent: isUrgent,
      orderType: orderType,
    );
    await _firebase.saveOrder(order);

    // Déduction automatique du stock (fire-and-forget — non bloquant)
    _firebase.deductStockForOrder(
      order: order,
      products: _products,
      createdBy: _currentUser?.name ?? 'Inconnu',
    ).catchError((e) {
      debugPrint('[stock.deduct] Erreur déduction stock: $e');
    });

    onNewOrder?.call(order);
    return order;
  }

  /// Modifie les articles / infos d'une commande existante (tant que non servie)
  Future<void> updateOrderItems({
    required String orderId,
    required List<OrderItem> items,
    required String tableNumber,
    String? serverName,
    String? serverId,
    String? serverEmail,
    String? specialInstructions,
    bool? isUrgent,
    double discount = 0,
  }) async {
    // Récupérer l'ancienne commande pour le delta stock
    final oldOrder = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []),
    );

    await _firebase.updateOrderItems(
      orderId: orderId,
      items: items,
      tableNumber: tableNumber,
      serverName: serverName,
      serverId: serverId,
      serverEmail: serverEmail,
      specialInstructions: specialInstructions,
      isUrgent: isUrgent,
      discount: discount,
    );

    // Ajustement stock si la commande avait des items précédents
    if (oldOrder.id.isNotEmpty) {
      _firebase.adjustStockForOrderUpdate(
        oldOrder: oldOrder,
        newItems: items,
        products: _products,
        createdBy: _currentUser?.name ?? 'Inconnu',
      ).catchError((e) {
        debugPrint('[stock.adjust] Erreur ajustement stock: $e');
      });
    }
  }

  /// Annule une commande (orderStatus = cancelled)
  Future<void> cancelOrder({
    required String orderId,
    required String cancelReason,
  }) async {
    final cancelledBy = _currentUser?.name ?? 'Inconnu';

    // Restaurer le stock avant l'annulation (on a encore les items en mémoire)
    final order = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []),
    );
    if (order.id.isNotEmpty) {
      _firebase.restoreStockForOrder(
        order: order,
        products: _products,
        createdBy: cancelledBy,
      ).catchError((e) {
        debugPrint('[stock.restore] Erreur restauration stock: $e');
      });
    }

    await _firebase.cancelOrder(
      orderId: orderId,
      cancelledBy: cancelledBy,
      cancelReason: cancelReason,
    );
  }

  /// Rôles autorisés à changer le statut de préparation d'une commande.
  /// Seuls cuisine, admin et manager peuvent passer pending→preparing→ready→served.
  static bool _canChangeOrderStatus(UserRole? role) {
    return role == UserRole.kitchen ||
           role == UserRole.admin   ||
           role == UserRole.manager;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    // Guard : seuls cuisine / admin / manager peuvent changer le statut de préparation
    final role = _currentUser?.role;
    final isStatusChange = status == OrderStatus.preparing ||
                           status == OrderStatus.ready     ||
                           status == OrderStatus.served;
    if (isStatusChange && !_canChangeOrderStatus(role)) {
      debugPrint('[AppProvider] updateOrderStatus REFUSÉ — rôle $role non autorisé pour statut $status');
      throw Exception('Action réservée à la cuisine');
    }
    // Mise à jour dans 'orders' (avec kitchenStatus maintenant)
    await _firebase.updateOrderStatus(orderId, status);

    // ── Synchronisation commandes en ligne → client_orders ────────────
    // Si c'est une commande online, synchroniser aussi le statut dans client_orders
    try {
      final order = _orders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []),
      );
      if (order.isOnlineOrder && order.id.isNotEmpty) {
        // Mapper OrderStatus → ClientOrderStatus pour la sync
        ClientOrderStatus? clientStatus;
        switch (status) {
          case OrderStatus.preparing:
            clientStatus = ClientOrderStatus.preparing;
            break;
          case OrderStatus.ready:
            clientStatus = ClientOrderStatus.ready;
            break;
          case OrderStatus.served:
            clientStatus = ClientOrderStatus.delivered;
            break;
          case OrderStatus.cancelled:
            clientStatus = ClientOrderStatus.cancelled;
            break;
          default:
            break;
        }
        if (clientStatus != null) {
          // Trouver le clientOrderId dans le doc orders
          final clientSvc = ClientFirebaseService();
          // L'id du client_orders est stocké dans 'clientOrderId' du doc orders
          // On passe l'orderId (internalOrderId) à updateOrderStatus de client_firebase_service
          // mais la méthode cherche par clientOrderId dans orders → on doit passer le clientOrderId
          // Récupérer depuis les données en mémoire si disponible
          // Utiliser directement FirebaseFirestore via un appel séparé
          await clientSvc.syncKitchenStatusToClientOrder(
            internalOrderId: orderId,
            clientStatus: clientStatus,
          );
        }
      }
    } catch (e) {
      debugPrint('[AppProvider] sync client_orders: $e');
    }
  }

  /// Envoie une commande en ligne en cuisine (depuis l'écran OnlineOrdersAdmin).
  /// [clientOrderId]   = widget.order.id (id du doc client_orders)
  /// [internalOrderId] = widget.order.internalOrderId (id du doc orders — optionnel)
  Future<void> sendOnlineOrderToKitchen(
    String clientOrderId, {
    String? internalOrderId,
  }) async {
    final clientSvc = ClientFirebaseService();
    await clientSvc.sendToKitchen(clientOrderId, internalOrderId: internalOrderId);
    debugPrint('[AppProvider] sendOnlineOrderToKitchen: clientOrderId=$clientOrderId internalOrderId=$internalOrderId');
  }

  Future<void> updateOrderItemQuantity(String orderId, String productId, int newQuantity) async {
    final order = _orders.firstWhere((o) => o.id == orderId, orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []));
    if (order.id.isEmpty) return;
    final itemIndex = order.items.indexWhere((i) => i.productId == productId);
    if (itemIndex != -1) {
      if (newQuantity <= 0) {
        order.items.removeAt(itemIndex);
      } else {
        order.items[itemIndex].quantity = newQuantity;
      }
      await _firebase.updateOrder(order);
    }
  }

  /// Méthode héritée — conservée pour compatibilité (préférer cashoutOrder/settleOrder)
  Future<void> payOrder(String orderId, String paymentMethod, double discount, {double amountPaid = 0}) async {
    final order = _orders.firstWhere((o) => o.id == orderId, orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []));
    if (order.id.isEmpty) return;
    order.isPaid = true;
    order.paymentMethod = paymentMethod;
    order.discount = discount;
    order.amountPaid = amountPaid;
    order.status = OrderStatus.served;
    order.servedAt = DateTime.now();
    await _firebase.updateOrder(order);
  }

  // ── CAISSE 2 ÉTAPES ────────────────────────────────────────────────

  /// ÉTAPE 1 — Encaissement : génère la facture d'encaissement provisoire.
  /// cashStatus → awaiting_payment  |  cashoutInvoiceGenerated = true
  /// NE compte PAS dans le total caisse.
  /// Retourne le numéro de facture généré pour que l'UI l'utilise
  /// immédiatement (même numéro sauvegardé en Firestore et imprimé).
  Future<String> cashoutOrder(String orderId, {double discount = 0}) async {
    final order = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []),
    );
    if (order.id.isEmpty) return '';

    final cashierId   = _currentUser?.id   ?? '';
    final cashierName = _currentUser?.name ?? 'Caissier';
    final invoiceNumber = PrintService.generateReceiptNumber(order.orderNumber);

    await _firebase.cashoutOrder(
      orderId: orderId,
      cashoutInvoiceNumber: invoiceNumber,
      cashierId: cashierId,
      cashierName: cashierName,
      amountDue: order.totalAmount - discount,
      discount: discount,
      items: order.items.map((i) => i.toMap()).toList(),
      orderNumber: order.orderNumber,
      tableNumber: order.tableNumber,
      serverName: order.serverName,
    );
    // Le stream Firestore met _orders à jour automatiquement
    return invoiceNumber;
  }

  /// ÉTAPE 2 — Règlement : finalise le paiement définitif.
  /// cashStatus → paid  |  isPaid = true  |  settlementInvoiceGenerated = true
  /// COMPTE dans le total caisse (todayRevenue).
  Future<void> settleOrder(
    String orderId, {
    required String paymentMethod,
    required double amountPaid,
    double discount = 0,
  }) async {
    final order = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => Order(id: '', orderNumber: 0, tableNumber: '', items: []),
    );
    if (order.id.isEmpty) return;

    final cashierId   = _currentUser?.id   ?? '';
    final cashierName = _currentUser?.name ?? 'Caissier';
    final amountDue   = order.totalAmount - discount;
    final change      = (amountPaid - amountDue).clamp(0.0, double.infinity);
    final settlementNumber = PrintService.generateSettlementNumber(order.orderNumber);
    final cashoutNumber    = order.cashoutInvoiceNumber ?? PrintService.generateReceiptNumber(order.orderNumber);

    await _firebase.settleOrder(
      orderId: orderId,
      settlementInvoiceNumber: settlementNumber,
      cashoutInvoiceNumber: cashoutNumber,
      cashierId: cashierId,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      amountDue: amountDue,
      amountPaid: amountPaid,
      changeAmount: change,
      orderNumber: order.orderNumber,
      tableNumber: order.tableNumber,
      items: order.items.map((i) => i.toMap()).toList(),
      serverName: order.serverName,
    );
    // Son paiement enregistré
    NotificationService().trigger(
      NotifEvent.paiementEnregistre,
      message: '💰 Paiement enregistré : ${amountDue.toStringAsFixed(0)} F CFA — Commande #${order.orderNumber} ($paymentMethod)',
    );
    // Le stream Firestore met _orders à jour automatiquement
  }

  /// Sauvegarde un reçu dans Firestore (collection receipts)
  Future<void> saveReceipt({
    required String receiptId,
    required String type,
    required String orderId,
    required int orderNumber,
    required double amount,
    required String paymentMethod,
    String? receiptNumber,
    String? settlementNumber,
  }) async {
    final cashierName = _currentUser?.name ?? 'Caissier';
    await _firebase.saveReceipt(
      receiptId: receiptId,
      type: type,
      orderId: orderId,
      orderNumber: orderNumber,
      amount: amount,
      paymentMethod: paymentMethod,
      createdBy: cashierName,
      receiptNumber: receiptNumber,
      settlementNumber: settlementNumber,
    );
  }

  /// Met à jour les flags d'impression sur une commande Firestore
  Future<void> updateOrderPrintStatus({
    required String orderId,
    bool? receiptPrinted,
    bool? settlementPrinted,
  }) async {
    await _firebase.updateOrderPrintStatus(
      orderId: orderId,
      receiptPrinted: receiptPrinted,
      settlementPrinted: settlementPrinted,
    );
  }

  // =================== PRODUCT MANAGEMENT (Firestore) ===================
  Future<void> addProduct(Product product) async {
    await _firebase.saveProduct(product);
    // Le stream Firestore met _products à jour automatiquement
  }

  Future<void> updateProduct(Product product) async {
    await _firebase.updateProduct(product);
  }

  /// Met à jour uniquement les stockLinks d'un produit.
  Future<void> updateProductStockLinks(
      String productId, List<StockLink> links) async {
    final p = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
          id: '', name: '', category: '', price: 0, prepTime: 0),
    );
    if (p.id.isEmpty) return;
    p.stockLinks = links;
    await _firebase.updateProduct(p);
  }

  Future<void> deleteProduct(String id) async {
    await _firebase.deleteProduct(id);
  }

  Future<void> toggleProductAvailability(String id) async {
    final p = _products.firstWhere((p) => p.id == id, orElse: () => Product(id: '', name: '', category: '', price: 0, prepTime: 0));
    if (p.id.isEmpty) return;
    p.isAvailable = !p.isAvailable;
    await _firebase.updateProduct(p);
  }

  // =================== STOCK MANAGEMENT (Firestore) ===================
  Future<void> updateStock(String id, double newQuantity) async {
    final item = _stockItems.firstWhere((s) => s.id == id, orElse: () => StockItem(id: '', name: '', unit: '', currentQuantity: 0, minQuantity: 0, maxQuantity: 0, unitCost: 0, category: ''));
    if (item.id.isEmpty) return;
    item.currentQuantity = newQuantity;
    await _firebase.updateStockItem(item);
  }

  /// Crée un article + enregistre dans stock_history (action: création)
  Future<void> addStockItem(StockItem item) async {
    await _firebase.saveStockItem(item);
    final userName = _currentUser?.name ?? 'Admin';
    await _firebase.addStockHistoryEntry(
      stockItemId: item.id,
      stockItemName: item.name,
      action: 'creation',
      oldQuantity: 0,
      newQuantity: item.currentQuantity,
      userName: userName,
      comment: 'Création du produit',
    );
  }

  /// Met à jour les infos d'un article + enregistre dans stock_history (action: modification_info)
  Future<void> updateStockItem(StockItem item) async {
    await _firebase.updateStockItem(item);
    final userName = _currentUser?.name ?? 'Admin';
    await _firebase.addStockHistoryEntry(
      stockItemId: item.id,
      stockItemName: item.name,
      action: 'modification_info',
      oldQuantity: item.currentQuantity,
      newQuantity: item.currentQuantity,
      userName: userName,
      comment: 'Modification des informations',
    );
  }

  /// Modifie la quantité d'un article + enregistre dans stock_history (action: modification_quantite)
  Future<void> adjustStockQuantity({
    required String id,
    required double newQuantity,
    required String motif,
  }) async {
    final item = _stockItems.firstWhere((s) => s.id == id, orElse: () => StockItem(id: '', name: '', unit: '', currentQuantity: 0, minQuantity: 0, maxQuantity: 0, unitCost: 0, category: ''));
    if (item.id.isEmpty) return;
    final oldQuantity = item.currentQuantity;
    item.currentQuantity = newQuantity;
    await _firebase.updateStockItem(item);
    final userName = _currentUser?.name ?? 'Admin';
    await _firebase.addStockHistoryEntry(
      stockItemId: item.id,
      stockItemName: item.name,
      action: 'modification_quantite',
      oldQuantity: oldQuantity,
      newQuantity: newQuantity,
      userName: userName,
      comment: motif,
    );
  }

  Future<void> deleteStockItem(String id) async {
    await _firebase.deleteStockItem(id);
  }

  /// Soft-delete : active=false + deletedAt + deletedBy + stock_history
  Future<void> softDeleteStockItem(String id) async {
    final userName = currentUser?.name ?? 'Inconnu';
    // Récupérer les infos avant suppression
    final item = _stockItems.firstWhere((s) => s.id == id, orElse: () => StockItem(id: '', name: '', unit: '', currentQuantity: 0, minQuantity: 0, maxQuantity: 0, unitCost: 0, category: ''));
    await _firebase.softDeleteStockItem(id, userName);
    if (item.id.isNotEmpty) {
      await _firebase.addStockHistoryEntry(
        stockItemId: item.id,
        stockItemName: item.name,
        action: 'suppression',
        oldQuantity: item.currentQuantity,
        newQuantity: 0,
        userName: userName,
        comment: 'Produit désactivé',
      );
    }
  }

  // ── Catégories stock (Firestore stock_categories) ────────────────────────
  Future<List<String>> fetchStockCategories() => _firebase.fetchStockCategories();
  Future<void> addStockCategory(String name) => _firebase.addStockCategory(name);
  Future<void> updateStockCategory(String oldName, String newName) => _firebase.updateStockCategory(oldName, newName);
  Future<void> deleteStockCategory(String name) => _firebase.deleteStockCategory(name);

  /// Stream historique stock
  Stream<List<Map<String, dynamic>>> streamStockHistory() => _firebase.streamStockHistory();

  /// Approvisionne un article de stock (entrée + stock_movements + stock_history)
  Future<void> restockItem({
    required String stockItemId,
    required double qty,
    double? purchasePrice,
    String? supplierId,
    String? supplierName,
    String? note,
  }) async {
    final createdBy = _currentUser?.name ?? 'Admin';
    await _firebase.restockItem(
      stockItemId: stockItemId,
      qty: qty,
      purchasePrice: purchasePrice,
      supplierId: supplierId,
      supplierName: supplierName,
      note: note,
      createdBy: createdBy,
    );
    // Le stream Firestore met _stockItems à jour automatiquement
  }

  // =================== CALL MANAGEMENT (Firestore) ===================

  /// Initie un appel 1-to-1 ou une conférence
  Future<String> initiateCall({
    required String calleeId,
    required String calleeName,
    bool isConference = false,
  }) async {
    final caller = _currentUser;
    if (caller == null) throw Exception('Utilisateur non connecté');
    final callId = await _firebase.initiateCall(
      callerId: caller.id,
      callerName: caller.name,
      calleeId: isConference ? null : calleeId,
      calleeName: isConference ? null : calleeName,
      isConference: isConference,
    );
    _activeCallId = callId;
    notifyListeners();
    return callId;
  }

  /// Accepte un appel entrant
  Future<void> answerCall(String callId) async {
    await _firebase.updateCallStatus(callId, CallStatus.accepted);
    _activeCallId = callId;
    _incomingCall = null;
    notifyListeners();
    // Rejoindre comme participant si pas déjà ajouté
    final user = _currentUser;
    if (user != null) {
      await _firebase.joinConference(callId, user.id, user.name)
          .catchError((e) => debugPrint('[answerCall] joinConference: $e'));
    }
  }

  /// Refuse un appel entrant
  Future<void> rejectCall(String callId) async {
    await _firebase.updateCallStatus(callId, CallStatus.rejected);
    _incomingCall = null;
    notifyListeners();
  }

  /// Termine un appel actif
  Future<void> endCall(String callId) async {
    await _firebase.updateCallStatus(callId, CallStatus.ended);
    _activeCallId = null;
    notifyListeners();
  }

  /// Rejoindre une conférence
  Future<void> joinConference(String callId) async {
    final user = _currentUser;
    if (user == null) return;
    await _firebase.joinConference(callId, user.id, user.name);
    _activeCallId = callId;
    notifyListeners();
  }

  /// Stream des participants d'un appel
  Stream<List<CallParticipant>> streamCallParticipants(String callId) =>
      _firebase.streamCallParticipants(callId);

  Future<void> deleteUserFirestore(String id) async {
    await _firebase.deleteUser(id);
  }

  Future<void> updateUserFirestore(AppUser user) async {
    await _firebase.updateUser(user);
  }

  // =================== ATTENDANCE ===================
  Future<void> markAttendance(String userId, AttendanceType type) async {
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day);

    // Trouver ou créer la ligne de présence en mémoire
    Attendance? attendance;
    final idx = _attendances.indexWhere(
      (a) => a.userId == userId &&
             DateTime(a.date.year, a.date.month, a.date.day) == dateKey,
    );

    if (idx != -1) {
      attendance = _attendances[idx];
    } else {
      final user = _users.firstWhere(
        (u) => u.id == userId,
        orElse: () => AppUser(id: userId, name: 'Inconnu', email: '', phone: '', role: UserRole.server),
      );
      attendance = Attendance(
        id: _uuid.v4(),
        userId: userId,
        userName: user.name,
        date: today,
      );
      _attendances.add(attendance);
    }

    // Mise à jour de la ligne en mémoire
    if (type == AttendanceType.morning) {
      attendance.morningPresent = true;
      attendance.morningTime = DateTime.now();
    } else {
      attendance.eveningPresent = true;
      attendance.eveningTime = DateTime.now();
    }

    // Persistance Firestore
    try {
      await _firebase.saveAttendance(attendance);
    } catch (e) {
      debugPrint('[AppProvider] markAttendance — saveAttendance erreur: $e');
    }

    notifyListeners();
  }

  List<Attendance> getAttendanceForDate(DateTime date) {
    return _attendances.where((a) =>
      a.date.year == date.year && a.date.month == date.month && a.date.day == date.day
    ).toList();
  }

  // =================== MESSAGING (Firestore) ===================
  Future<void> sendMessage(ChatMessage message) async {
    await _firebase.sendMessage(message);
  }

  List<ChatMessage> getConversation(String userId1, String userId2) {
    return _messages.where((m) =>
      (m.senderId == userId1 && m.receiverId == userId2) ||
      (m.senderId == userId2 && m.receiverId == userId1)
    ).toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  // =================== SUPPLIERS (Firestore) ===================
  Future<void> addSupplier(Supplier supplier) async {
    await _firebase.saveSupplier(supplier);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _firebase.updateSupplier(supplier);
  }

  /// Supprime ou désactive un fournisseur selon son historique de commandes.
  Future<void> deleteOrDeactivateSupplier(String id) async {
    final hasOrders = await _firebase.supplierHasOrders(id);
    if (hasOrders) {
      // Soft-delete : conserver l'historique
      final deletedBy = _currentUser?.name ?? 'Inconnu';
      await _firebase.softDeleteSupplier(id, deletedBy);
    } else {
      // Hard-delete : aucun historique
      await _firebase.hardDeleteSupplier(id);
    }
  }

  Future<void> addSupplierOrder(SupplierOrder order) async {
    await _firebase.saveSupplierOrder(order);
  }

  /// Ajoute un paiement partiel ou total sur une commande fournisseur.
  Future<void> addSupplierPayment({
    required String supplierOrderId,
    required String supplierId,
    required double amount,
    required String paymentMethod,
    required DateTime paymentDate,
    String? note,
  }) async {
    final order = _supplierOrders.firstWhere(
      (o) => o.id == supplierOrderId,
      orElse: () => SupplierOrder(
        id: '', supplierId: '', supplierName: '',
        items: [], totalAmount: 0,
      ),
    );
    if (order.id.isEmpty) return;

    final payment = SupplierPayment(
      id: _uuid.v4(),
      supplierOrderId: supplierOrderId,
      supplierId: supplierId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentDate: paymentDate,
      note: note,
      createdAt: DateTime.now(),
      createdBy: _currentUser?.name ?? 'Inconnu',
    );

    await _firebase.addSupplierPayment(payment: payment, order: order);
  }

  // Conserve la méthode historique pour rétrocompat (redirige vers addSupplierPayment)
  Future<void> updateSupplierOrderPayment(String id, double amount, String method) async {
    await addSupplierPayment(
      supplierOrderId: id,
      supplierId: _supplierOrders.firstWhere(
        (o) => o.id == id,
        orElse: () => SupplierOrder(id: '', supplierId: '', supplierName: '', items: [], totalAmount: 0),
      ).supplierId,
      amount: amount,
      paymentMethod: method,
      paymentDate: DateTime.now(),
    );
  }

  // =================== STATISTICS ===================
  /// Revenu du jour — compte UNIQUEMENT les règlements définitifs.
  /// Filtre sur settledAt (heure du règlement) et NON createdAt (heure de commande).
  /// Les factures provisoires (cashStatus == awaiting_payment) ne sont PAS comptées.
  double get todayRevenue {
    final today = DateTime.now();
    return _orders
      .where((o) {
        if (!o.settlementInvoiceGenerated || !o.isPaid) return false;
        final settled = o.settledAt;
        if (settled == null) return false;
        return settled.day   == today.day   &&
               settled.month == today.month &&
               settled.year  == today.year;
      })
      .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  /// Revenu du jour par mode de paiement (point de caisse détaillé)
  /// Filtre sur settledAt — même règle que todayRevenue.
  Map<String, double> get todayRevenueByPaymentMethod {
    final today = DateTime.now();
    final settled = _orders.where((o) {
      if (!o.settlementInvoiceGenerated || !o.isPaid) return false;
      final s = o.settledAt;
      if (s == null) return false;
      return s.day == today.day && s.month == today.month && s.year == today.year;
    });
    final map = <String, double>{};
    for (final o in settled) {
      final method = o.paymentMethod ?? 'Espèces';
      map[method] = (map[method] ?? 0) + o.totalAmount;
    }
    return map;
  }

  Map<String, int> get topProducts {
    final map = <String, int>{};
    for (var order in _orders.where((o) => o.status == OrderStatus.served)) {
      for (var item in order.items) {
        map[item.productName] = (map[item.productName] ?? 0) + item.quantity;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  double get avgPrepTime {
    final completed = _orders.where((o) => o.readyAt != null && o.startedAt != null).toList();
    if (completed.isEmpty) return 0;
    final total = completed.fold(0, (sum, o) => sum + o.readyAt!.difference(o.startedAt!).inMinutes);
    return total / completed.length;
  }

  int get todayOrderCount {
    final today = DateTime.now();
    return _orders.where((o) => o.createdAt.day == today.day && o.createdAt.month == today.month).length;
  }

  // =================== GESTION UTILISATEURS ADMIN ===================

  /// CAS 1 — Personnel simple : Firestore uniquement, pas de compte Auth.
  /// canLogin = false — l'employé ne peut pas se connecter.
  Future<AppUser> addStaff({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    bool isActive = true,
  }) async {
    final createdBy = _currentUser?.name ?? 'Admin';
    final newUser = await _firebase.addStaffOnly(
      name: name,
      email: email,
      phone: phone,
      role: role,
      isActive: isActive,
      createdBy: createdBy,
    );
    return newUser;
  }

  /// CAS 2 — Utilisateur avec accès application.
  /// Auth-first : createUserWithEmailAndPassword PUIS Firestore.
  /// Si Auth échoue → exception propagée (pas de doc Firestore créé).
  Future<AppUser> addUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    bool isActive = true,
  }) async {
    final createdBy = _currentUser?.name ?? 'Admin';
    final newUser = await _firebase.createUserWithAuth(
      name: name,
      email: email,
      password: password,
      phone: phone,
      role: role,
      isActive: isActive,
      createdBy: createdBy,
    );
    return newUser;
  }

  Future<void> updateUser(
    String id, {
    required String name,
    required String email,
    required String phone,
    required UserRole role,
  }) async {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    final updated = AppUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: role,
      isActive: _users[idx].isActive,
    );
    await _firebase.updateUser(updated);
  }

  Future<void> deleteUser(String id) async {
    await _firebase.deleteUser(id);
  }

  Future<void> toggleUserActive(String id) async {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    final u = _users[idx];
    u.isActive = !u.isActive;
    await _firebase.updateUser(u);
  }

  Future<void> changeUserRole(String id, UserRole role) async {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    final u = _users[idx];
    u.role = role;
    await _firebase.updateUser(u);
  }

  // =================== PERMISSIONS PAR RÔLE ===================
  // Chargées depuis Firestore (collection role_permissions)
  // Initialisées avec les valeurs par défaut de FirebaseService.defaultPermissions()

  Map<UserRole, Map<String, bool>> _rolePermissions = {
    for (final r in UserRole.values)
      r: Map<String, bool>.from(FirebaseService.defaultPermissions(r)),
  };

  Map<String, bool> getRolePermissions(UserRole role) {
    return Map<String, bool>.from(_rolePermissions[role] ?? FirebaseService.defaultPermissions(role));
  }

  List<String> getUserPermissions(UserRole role) {
    final perms = _rolePermissions[role] ?? FirebaseService.defaultPermissions(role);
    return perms.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  /// Modifie une permission en mémoire ET la persiste en Firestore.
  /// L'admin ne peut pas être modifié.
  Future<void> setRolePermission(UserRole role, String module, bool value) async {
    if (role == UserRole.admin) return;
    _rolePermissions[role] ??= Map<String, bool>.from(FirebaseService.defaultPermissions(role));
    _rolePermissions[role]![module] = value;
    notifyListeners();
    // Persistance Firestore
    try {
      await _firebase.saveRolePermission(role, module, value);
    } catch (e) {
      debugPrint('[AppProvider] setRolePermission erreur Firestore: $e');
    }
  }

  bool hasPermission(UserRole role, String module) {
    return _rolePermissions[role]?[module] ?? FirebaseService.defaultPermissions(role)[module] ?? false;
  }

  // =================== INVENTORY ===================

  Future<InventorySession> createInventorySession({
    required String site,
  }) async {
    final user = currentUser;
    return _firebase.createInventorySession(
      responsibleId: user?.id ?? '',
      responsibleName: user?.name ?? 'Inconnu',
      site: site,
      stockItems: _stockItems,
    );
  }

  Future<List<InventorySession>> fetchInventorySessions() =>
      _firebase.fetchInventorySessions();

  Future<List<InventoryItem>> fetchInventoryItems(String sessionId) =>
      _firebase.fetchInventoryItems(sessionId);

  Future<void> saveInventoryLine(InventoryItem line) =>
      _firebase.saveInventoryLine(line);

  Future<void> completeInventorySession(
    String sessionId,
    List<InventoryItem> items,
  ) => _firebase.completeInventorySession(sessionId, items);

  Future<void> applyInventoryCorrections({
    required String sessionId,
    required List<InventoryItem> items,
  }) => _firebase.applyInventoryCorrections(
    sessionId: sessionId,
    items: items,
    validatedByName: currentUser?.name ?? 'Inconnu',
  );

  Future<void> deleteInventorySession(String sessionId) =>
      _firebase.deleteInventorySession(sessionId);

  // ══════════════════════════════════════════════════════════════════════
  //  CONTRACTS — CRUD + alertes automatiques
  // ══════════════════════════════════════════════════════════════════════

  Future<void> addContract(EmployeeContract c) => _firebase.addContract(c);

  Future<void> updateContract(EmployeeContract c) => _firebase.updateContract(c);

  Future<void> deleteContract(String id) => _firebase.deleteContract(id);

  Future<void> renewContract({
    required EmployeeContract contract,
    required DateTime newEndDate,
    required String decision,
  }) async {
    final old = contract.toMap().toString();
    contract.endDate = newEndDate;
    contract.status = ContractStatus.renouvele;
    contract.comment = decision.isNotEmpty ? decision : contract.comment;
    await _firebase.updateContract(contract);

    final h = ContractHistory(
      id: '', contractId: contract.id,
      employeeId: contract.employeeId, employeeName: contract.employeeName,
      action: 'renewed', oldData: old, newData: contract.toMap().toString(),
      decision: decision, responsable: currentUser?.name ?? 'Inconnu',
    );
    await _firebase.addContractHistory(h);
  }

  Future<void> declineRenewal({
    required EmployeeContract contract,
    required String decision,
  }) async {
    final old = contract.toMap().toString();
    contract.status = ContractStatus.nonRenouvele;
    contract.comment = decision.isNotEmpty ? decision : contract.comment;
    await _firebase.updateContract(contract);

    final h = ContractHistory(
      id: '', contractId: contract.id,
      employeeId: contract.employeeId, employeeName: contract.employeeName,
      action: 'not_renewed', oldData: old, newData: contract.toMap().toString(),
      decision: decision, responsable: currentUser?.name ?? 'Inconnu',
    );
    await _firebase.addContractHistory(h);
  }

  Future<void> addCommentToContract(EmployeeContract c, String comment) async {
    c.comment = comment;
    await _firebase.updateContract(c);
    final h = ContractHistory(
      id: '', contractId: c.id,
      employeeId: c.employeeId, employeeName: c.employeeName,
      action: 'comment', decision: comment,
      responsable: currentUser?.name ?? 'Inconnu',
    );
    await _firebase.addContractHistory(h);
  }

  Future<List<ContractHistory>> fetchContractHistory(String contractId) async {
    final snap = await _firebase.streamContractHistory(contractId).first;
    return snap;
  }

  Future<void> markAlertRead(String alertId) => _firebase.markAlertRead(alertId);

  /// Génère automatiquement les alertes Firestore pour les contrats proches d'expiration
  void _refreshContractAlerts() {
    for (final c in _contracts) {
      if (c.endDate == null) continue;
      final days = c.daysLeft!;
      if (days <= 30) {
        final alert = ContractAlert(
          id: '', contractId: c.id,
          employeeId: c.employeeId, employeeName: c.employeeName,
          daysLeft: days,
        );
        _firebase.upsertContractAlert(alert).catchError((_) {});
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SALAIRES — CRUD + PAIEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addSalary(EmployeeSalary s) => _firebase.addSalary(s);

  Future<void> updateSalary(EmployeeSalary s) => _firebase.updateSalary(s);

  Future<void> deleteSalary(String id) => _firebase.deleteSalary(id);

  /// Enregistre un paiement (total ou partiel) et met à jour la fiche salaire.
  Future<void> paySalary({
    required EmployeeSalary salary,
    required double montant,
    required PaymentMode mode,
    String note = '',
  }) async {
    final payment = SalaryPayment(
      id: '',
      salaryId: salary.id,
      employeeId: salary.employeeId,
      employeeName: salary.employeeName,
      periode: salary.periode,
      montant: montant,
      mode: mode,
      date: DateTime.now(),
      responsable: currentUser?.name ?? 'Inconnu',
      note: note,
    );
    await _firebase.addSalaryPayment(payment);

    final totalPaye = salary.montantPaye + montant;
    salary.montantPaye = totalPaye;
    salary.modePaiement = mode;
    salary.datePaiement = DateTime.now();
    if (totalPaye >= salary.netAPayer) {
      salary.paymentStatus = PaymentStatus.paye;
    } else if (totalPaye > 0) {
      salary.paymentStatus = PaymentStatus.partiel;
    }
    await _firebase.updateSalary(salary);
  }

  /// Génère (ou met à jour) le rapport de paie pour un mois donné.
  Future<void> generatePayrollReport(int annee, int mois) async {
    final list = salariesForPeriod(annee, mois);
    if (list.isEmpty) return;
    final periodeStr = list.first.periode;
    final report = PayrollReport(
      id: '',
      periode: periodeStr,
      annee: annee,
      mois: mois,
      totalEmployes: list.length,
      totalBrut: list.fold(0, (s, e) => s + e.brut),
      totalPrimes: list.fold(0, (s, e) => s + e.primes),
      totalRetenues: list.fold(0, (s, e) => s + e.totalRetenues),
      totalNet: list.fold(0, (s, e) => s + e.netAPayer),
      totalPaye: list.fold(0, (s, e) => s + e.montantPaye),
    );
    await _firebase.savePayrollReport(report);
  }

  // ── RÉSERVATIONS CRUD ────────────────────────────────────────────────────

  Future<void> addReservation(Reservation r) async {
    try {
      await _firebase.addReservation(r);
      NotificationService().trigger(
        NotifEvent.nouvelleReservation,
        message: '📅 Nouvelle réservation : ${r.nomClient} — ${r.typeEvenement.label} le ${r.dateEvenement.day}/${r.dateEvenement.month}/${r.dateEvenement.year}',
      );
    } catch (e) { debugPrint('[addReservation] $e'); rethrow; }
  }

  Future<void> updateReservation(Reservation r) async {
    try { await _firebase.updateReservation(r); }
    catch (e) { debugPrint('[updateReservation] $e'); rethrow; }
  }

  Future<void> deleteReservation(String id) async {
    try {
      await _firebase.deleteReservation(id);
      await _firebase.deleteReservationAlertsByReservation(id);
    } catch (e) { debugPrint('[deleteReservation] $e'); rethrow; }
  }

  Future<void> addReservationPayment(ReservationPayment p) async {
    try {
      await _firebase.addReservationPayment(p);
      NotificationService().trigger(
        NotifEvent.paiementEnregistre,
        message: '💰 Paiement réservation : ${p.montant.toStringAsFixed(0)} F CFA — ${p.nomClient}',
      );
    } catch (e) { debugPrint('[addReservationPayment] $e'); rethrow; }
  }

  Future<void> markReservationAlertRead(String id) async {
    try { await _firebase.markReservationAlertRead(id); }
    catch (e) { debugPrint('[markReservationAlertRead] $e'); }
  }

  Future<void> markAllReservationAlertsRead() async {
    for (final a in _reservationAlerts.where((x) => !x.isRead)) {
      await _firebase.markReservationAlertRead(a.id);
    }
  }

  /// Génère automatiquement les alertes pour les réservations à venir
  Future<void> _generateReservationAlerts() async {
    final now = DateTime.now();
    for (final r in _reservations) {
      if (r.status == ReservationStatus.annule) continue;
      final days = r.dateEvenement.difference(now).inDays;
      final thresholds = [30, 15, 7, 3, 1, 0];
      for (final t in thresholds) {
        if (days == t || (t == 1 && days == 0 && r.dateEvenement.day == now.day)) {
          final typeAlerte = t == 30 ? '30j' : t == 15 ? '15j' : t == 7 ? '7j'
              : t == 3 ? '3j' : t == 1 ? '24h' : 'auj';
          final msg = t == 0
              ? "Événement aujourd'hui : ${r.typeEvenement.label} — ${r.nomClient}"
              : t == 1
              ? "Demain : ${r.typeEvenement.label} de ${r.nomClient} (${r.nombrePersonnes} pers.)"
              : "Dans ${t == 30 ? '30' : t == 15 ? '15' : t == 7 ? '7' : '3'} jours : ${r.typeEvenement.label} — ${r.nomClient}";
          await _firebase.upsertReservationAlert(ReservationAlert(
            id: '', reservationId: r.id, nomClient: r.nomClient,
            typeAlerte: typeAlerte, message: msg, dateAlerte: now,
          ));
        }
      }
      // Alerte impayé
      if (r.soldeRestant > 0 && days <= 7 && days >= 0) {
        await _firebase.upsertReservationAlert(ReservationAlert(
          id: '', reservationId: r.id, nomClient: r.nomClient,
          typeAlerte: 'impaye',
          message: 'Solde impayé de ${r.soldeRestant.toStringAsFixed(0)} F CFA — ${r.nomClient}',
          dateAlerte: now,
        ));
      }
    }
  }

  @override
  void dispose() {
    _stopFirebaseStreams();
    _alertTimer?.cancel();
    super.dispose();
  }
}
