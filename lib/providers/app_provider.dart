import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

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
  StreamSubscription? _subAttendances;

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
  List<Order> get readyOrders => _orders.where((o) => o.status == OrderStatus.ready).toList();
  List<Order> get servedOrders => _orders.where((o) => o.status == OrderStatus.served).toList();

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
  List<Supplier> get suppliers => _suppliers;

  List<SupplierOrder> _supplierOrders = [];
  List<SupplierOrder> get supplierOrders => _supplierOrders;

  // =================== CATEGORIES PERSONNALISÉES ===================
  List<String> _customCategories = ['Plats', 'Accompagnements', 'Boissons', 'Desserts', 'Entrées', 'Snacks'];
  List<String> get customCategories => _customCategories;

  void addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_customCategories.contains(trimmed)) {
      _customCategories.add(trimmed);
      notifyListeners();
    }
  }

  void renameCategory(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isNotEmpty && !_customCategories.contains(trimmed)) {
      final idx = _customCategories.indexOf(oldName);
      if (idx != -1) {
        _customCategories[idx] = trimmed;
        // Mettre à jour les produits qui utilisent cette catégorie
        for (final p in _products) {
          if (p.category == oldName) p.category = trimmed;
        }
        notifyListeners();
      }
    }
  }

  void deleteCategory(String name) {
    _customCategories.remove(name);
    // Déplacer les produits orphelins vers "Plats" (ou première catégorie dispo)
    final fallback = _customCategories.isNotEmpty ? _customCategories.first : 'Divers';
    for (final p in _products) {
      if (p.category == name) p.category = fallback;
    }
    notifyListeners();
  }

  // =================== CHARGES DU JOUR ===================
  final List<Map<String, dynamic>> _dailyCharges = [];
  List<Map<String, dynamic>> get dailyCharges => _dailyCharges;

  double get todayTotalCharges {
    final today = DateTime.now();
    return _dailyCharges
      .where((c) {
        final d = c['date'] as DateTime?;
        return d != null && d.day == today.day && d.month == today.month && d.year == today.year;
      })
      .fold(0.0, (sum, c) => sum + ((c['amount'] as num?)?.toDouble() ?? 0.0));
  }

  List<Map<String, dynamic>> get todayCharges {
    final today = DateTime.now();
    return _dailyCharges.where((c) {
      final d = c['date'] as DateTime?;
      return d != null && d.day == today.day && d.month == today.month && d.year == today.year;
    }).toList();
  }

  void addDailyCharge({required String label, required double amount, String? note}) {
    _dailyCharges.add({
      'id': _uuid.v4(),
      'label': label,
      'amount': amount,
      'note': note ?? '',
      'date': DateTime.now(),
    });
    notifyListeners();
  }

  void removeDailyCharge(String id) {
    _dailyCharges.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }

  // =================== ORDER COUNTER ===================
  int _orderCounter = 100;

  // =================== NOTIFICATION CALLBACK ===================
  Function(Order)? onNewOrder;
  Function(Order)? onOrderDelayed;

  Timer? _alertTimer;

  AppProvider({this.firebaseReady = false}) {
    // ✅ PAS DE DONNÉES DÉMO — toutes les données viennent exclusivement de Firestore
    try { _startAlertTimer(); } catch (e) { debugPrint('[AppProvider] alertTimer: $e'); }
    // Aucun accès Firebase dans le constructeur
  }

  /// Appelé par main() APRÈS Firebase.initializeApp() — reprise de session sécurisée
  Future<void> checkExistingSession() async {
    if (!firebaseReady) return;
    try {
      final fbUser = _firebase.currentFirebaseUser;
      if (fbUser == null) return;
      debugPrint('[AppProvider] Session existante: ${fbUser.email}');
      final role = _roleFromEmail(fbUser.email ?? '');
      final displayName = _displayNameFromEmail(fbUser.email ?? '');
      _currentUser = AppUser(id: fbUser.uid, name: displayName, email: fbUser.email ?? '', phone: '', role: role);
      _startFirebaseStreams();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] checkExistingSession: $e');
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
      // 1. Authentification Firebase
      final credential = await _firebase.signIn(email, password);
      if (credential?.user == null) throw Exception('Aucun utilisateur retourné par Firebase');

      final uid  = credential!.user!.uid;
      final mail = credential.user!.email ?? email;

      // 2. Rôle déduit de l'email (profil immédiat sans attendre Firestore)
      final role = _roleFromEmail(mail);
      final displayName = _displayNameFromEmail(mail);
      _currentUser = AppUser(id: uid, name: displayName, email: mail, phone: '', role: role);
      notifyListeners(); // UI réactive immédiatement

      // 3. S'assurer que le doc Firestore existe (crée si absent)
      final firestoreUser = await _firebase.ensureUserDoc(uid, mail, role, displayName);
      _currentUser = firestoreUser;
      notifyListeners();

      // 4. Démarrer les streams temps réel
      _startFirebaseStreams();

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e, st) {
      debugPrint('[AppProvider] loginWithFirebase ERROR: $e');
      debugPrint('[AppProvider] STACKTRACE: $st');
      _errorMessage = _mapAuthError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false; // Ne propage JAMAIS l'exception
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
    // GARDE : ne jamais ouvrir de stream Firestore si Firebase non prêt ou user non connecté
    if (!firebaseReady) {
      debugPrint('[AppProvider] _startFirebaseStreams ignoré — Firebase non prêt');
      return;
    }
    final fbUser = _firebase.currentFirebaseUser;
    if (fbUser == null) {
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
    _subOrders = _firebase.streamOrders().listen(
      (list) { _orders = List<Order>.from(list); notifyListeners(); },
      onError: (e) { debugPrint('[stream.orders] ERREUR: $e'); },
      cancelOnError: false,
    );
    _subStock = _firebase.streamStock().listen(
      (list) { _stockItems = list; notifyListeners(); },
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
    _subAttendances = _firebase.streamAttendances().listen(
      (list) {
        // Attendances peuvent être vides — on accepte []
        _attendances = list;
        notifyListeners();
      },
      onError: (e) { debugPrint('[stream.attendances] ERREUR: $e'); },
      cancelOnError: false,
    );
  }

  void _stopFirebaseStreams() {
    _subUsers?.cancel();
    _subProducts?.cancel();
    _subOrders?.cancel();
    _subStock?.cancel();
    _subMessages?.cancel();
    _subSuppliers?.cancel();
    _subSupplierOrders?.cancel();
    _subAttendances?.cancel();
  }

  Future<void> logout() async {
    _stopFirebaseStreams();
    if (_currentUser != null) {
      await _firebase.setUserOnline(_currentUser!.id, false).catchError((_) {});
    }
    await _firebase.signOut().catchError((e) => debugPrint('[logout] $e'));
    _currentUser = null;
    _users = []; _orders = []; _products = []; _stockItems = [];
    _suppliers = []; _supplierOrders = []; _messages = []; _attendances = [];
    notifyListeners();
  }

  // =================== ORDER MANAGEMENT (Firestore) ===================
  Future<Order> createOrder({
    required String tableNumber,
    required List<OrderItem> items,
    String? serverName,
    String? specialInstructions,
    bool isUrgent = false,
  }) async {
    _orderCounter++;
    final order = Order(
      id: _uuid.v4(),
      orderNumber: _orderCounter,
      tableNumber: tableNumber,
      serverName: serverName ?? _currentUser?.name,
      items: items,
      specialInstructions: specialInstructions,
      isUrgent: isUrgent,
    );
    await _firebase.saveOrder(order);
    onNewOrder?.call(order);
    return order;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firebase.updateOrderStatus(orderId, status);
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

  // =================== PRODUCT MANAGEMENT (Firestore) ===================
  Future<void> addProduct(Product product) async {
    await _firebase.saveProduct(product);
    // Le stream Firestore met _products à jour automatiquement
  }

  Future<void> updateProduct(Product product) async {
    await _firebase.updateProduct(product);
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

  Future<void> addStockItem(StockItem item) async {
    await _firebase.saveStockItem(item);
  }

  Future<void> updateStockItem(StockItem item) async {
    await _firebase.updateStockItem(item);
  }

  Future<void> deleteStockItem(String id) async {
    await _firebase.deleteStockItem(id);
  }

  // =================== USER MANAGEMENT (Firestore) ===================
  Future<void> addUserDirect(AppUser user) async {
    await _firebase.saveUser(user);
  }

  Future<void> deleteUserFirestore(String id) async {
    await _firebase.deleteUser(id);
  }

  Future<void> updateUserFirestore(AppUser user) async {
    await _firebase.updateUser(user);
  }

  // =================== ATTENDANCE ===================
  void markAttendance(String userId, AttendanceType type) {
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day);
    
    var attendance = _attendances.firstWhere(
      (a) => a.userId == userId && DateTime(a.date.year, a.date.month, a.date.day) == dateKey,
      orElse: () {
        final user = _users.firstWhere((u) => u.id == userId);
        final newAttendance = Attendance(
          id: _uuid.v4(), userId: userId, userName: user.name, date: today,
        );
        _attendances.add(newAttendance);
        return newAttendance;
      },
    );

    if (type == AttendanceType.morning) {
      attendance.morningPresent = true;
      attendance.morningTime = DateTime.now();
    } else {
      attendance.eveningPresent = true;
      attendance.eveningTime = DateTime.now();
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

  Future<void> deleteSupplier(String id) async {
    await _firebase.deleteSupplier(id);
  }

  Future<void> addSupplierOrder(SupplierOrder order) async {
    await _firebase.saveSupplierOrder(order);
  }

  Future<void> updateSupplierOrderPayment(String id, double amount, String method) async {
    final order = _supplierOrders.firstWhere((o) => o.id == id, orElse: () => SupplierOrder(id: '', supplierId: '', supplierName: '', items: [], totalAmount: 0, paidAmount: 0, paymentStatus: SupplierPaymentStatus.pending, paymentMethod: '', orderDate: DateTime.now()));
    if (order.id.isEmpty) return;
    order.paidAmount += amount;
    order.paymentMethod = method;
    if (order.paidAmount >= order.totalAmount) {
      order.paymentStatus = SupplierPaymentStatus.paid;
    } else {
      order.paymentStatus = SupplierPaymentStatus.partial;
    }
    await _firebase.updateSupplierOrder(order);
  }

  // =================== STATISTICS ===================
  double get todayRevenue {
    final today = DateTime.now();
    return _orders
      .where((o) => o.isPaid && o.createdAt.day == today.day && o.createdAt.month == today.month)
      .fold(0, (sum, o) => sum + o.totalAmount);
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

  // =================== GESTION UTILISATEURS (ADMIN) ===================

  // =================== GESTION UTILISATEURS ADMIN (Firestore) ===================

  Future<void> addUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final newUser = AppUser(
      id: _uuid.v4(),
      name: name,
      email: email,
      phone: phone,
      role: role,
      isActive: true,
    );
    await _firebase.saveUser(newUser);
    // Le stream Firestore met _users à jour automatiquement
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

  // Structure : rolePermissions[role][module] = true/false
  final Map<UserRole, Map<String, bool>> _rolePermissions = {
    UserRole.admin: {
      'dashboard': true, 'orders': true, 'kitchen': true, 'cashier': true,
      'stock': true, 'staff': true, 'messaging': true, 'stats': true,
      'suppliers': true, 'products': true, 'admin': true,
    },
    UserRole.manager: {
      'dashboard': true, 'orders': true, 'kitchen': true, 'cashier': true,
      'stock': true, 'staff': true, 'messaging': true, 'stats': true,
      'suppliers': true, 'products': true, 'admin': false,
    },
    UserRole.cashier: {
      'dashboard': true, 'orders': true, 'kitchen': false, 'cashier': true,
      'stock': false, 'staff': false, 'messaging': true, 'stats': false,
      'suppliers': false, 'products': false, 'admin': false,
    },
    UserRole.kitchen: {
      'dashboard': true, 'orders': false, 'kitchen': true, 'cashier': false,
      'stock': true, 'staff': false, 'messaging': true, 'stats': false,
      'suppliers': false, 'products': false, 'admin': false,
    },
    UserRole.server: {
      'dashboard': true, 'orders': true, 'kitchen': false, 'cashier': false,
      'stock': false, 'staff': false, 'messaging': true, 'stats': false,
      'suppliers': false, 'products': false, 'admin': false,
    },
  };

  Map<String, bool> getRolePermissions(UserRole role) {
    return Map<String, bool>.from(_rolePermissions[role] ?? {});
  }

  List<String> getUserPermissions(UserRole role) {
    final perms = _rolePermissions[role] ?? {};
    return perms.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  void setRolePermission(UserRole role, String module, bool value) {
    // L'admin garde toujours tous les accès
    if (role == UserRole.admin) return;
    _rolePermissions[role]?[module] = value;
    notifyListeners();
  }

  bool hasPermission(UserRole role, String module) {
    return _rolePermissions[role]?[module] ?? false;
  }

  @override
  void dispose() {
    _stopFirebaseStreams();
    _alertTimer?.cancel();
    super.dispose();
  }
}
