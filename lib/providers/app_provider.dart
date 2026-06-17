import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class AppProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _firebase = FirebaseService();

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

  AppProvider() {
    try {
      _initDemoData();
    } catch (e) {
      debugPrint('[AppProvider] Erreur _initDemoData: $e');
    }
    try {
      _startAlertTimer();
    } catch (e) {
      debugPrint('[AppProvider] Erreur _startAlertTimer: $e');
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

  // =================== INIT DEMO DATA ===================
  void _initDemoData() {
    // Users
    _users = [
      AppUser(id: 'u1', name: 'Kouamé Admin', email: 'admin@sankadio.com', phone: '+225 07 11 22 33', role: UserRole.admin),
      AppUser(id: 'u2', name: 'Aya Koné', email: 'aya@sankadio.com', phone: '+225 05 44 55 66', role: UserRole.cashier),
      AppUser(id: 'u3', name: 'Mamadou Chef', email: 'mamadou@sankadio.com', phone: '+225 01 77 88 99', role: UserRole.kitchen),
      AppUser(id: 'u4', name: 'Fatou Servante', email: 'fatou@sankadio.com', phone: '+225 07 22 33 44', role: UserRole.server),
      AppUser(id: 'u5', name: 'Ibrahim Manager', email: 'ibrahim@sankadio.com', phone: '+225 05 55 66 77', role: UserRole.manager),
    ];

    _currentUser = _users[0];

    // Products
    _products = [
      Product(id: 'p1', name: 'Poisson Braisé', category: 'Plats', price: 3500, prepTime: 25, stockQuantity: 20),
      Product(id: 'p2', name: 'Poulet Braisé', category: 'Plats', price: 3000, prepTime: 20, stockQuantity: 15),
      Product(id: 'p3', name: 'Kedjenou de Poulet', category: 'Plats', price: 3500, prepTime: 35, stockQuantity: 10),
      Product(id: 'p4', name: 'Riz Sauce', category: 'Plats', price: 2000, prepTime: 10, stockQuantity: 30),
      Product(id: 'p5', name: 'Garba', category: 'Plats', price: 1500, prepTime: 8, stockQuantity: 25),
      Product(id: 'p6', name: 'Attiéké', category: 'Accompagnements', price: 500, prepTime: 5, stockQuantity: 50),
      Product(id: 'p7', name: 'Foutou Banane', category: 'Accompagnements', price: 800, prepTime: 15, stockQuantity: 20),
      Product(id: 'p8', name: 'Alloco', category: 'Accompagnements', price: 600, prepTime: 10, stockQuantity: 30),
      Product(id: 'p9', name: 'Coca-Cola', category: 'Boissons', price: 500, prepTime: 1, stockQuantity: 100),
      Product(id: 'p10', name: 'Eau Minérale', category: 'Boissons', price: 300, prepTime: 1, stockQuantity: 150),
      Product(id: 'p11', name: 'Jus de Bissap', category: 'Boissons', price: 400, prepTime: 2, stockQuantity: 40),
      Product(id: 'p12', name: 'Bière Fraîche', category: 'Boissons', price: 700, prepTime: 1, stockQuantity: 60),
      Product(id: 'p13', name: 'Thiéboudienne', category: 'Plats', price: 4000, prepTime: 40, stockQuantity: 8),
      Product(id: 'p14', name: 'Mafé', category: 'Plats', price: 3500, prepTime: 30, stockQuantity: 12),
      Product(id: 'p15', name: 'Café', category: 'Boissons', price: 200, prepTime: 3, stockQuantity: 0, isAvailable: false),
    ];

    // Stock
    _stockItems = [
      StockItem(id: 's1', name: 'Poisson Tilapia', unit: 'kg', currentQuantity: 15, minQuantity: 5, maxQuantity: 50, unitCost: 2000, category: 'Viandes & Poissons'),
      StockItem(id: 's2', name: 'Poulet', unit: 'kg', currentQuantity: 3, minQuantity: 5, maxQuantity: 30, unitCost: 2500, category: 'Viandes & Poissons'),
      StockItem(id: 's3', name: 'Huile de palme', unit: 'L', currentQuantity: 20, minQuantity: 5, maxQuantity: 50, unitCost: 800, category: 'Épices & Huiles'),
      StockItem(id: 's4', name: 'Attiéké', unit: 'kg', currentQuantity: 30, minQuantity: 10, maxQuantity: 100, unitCost: 300, category: 'Féculents'),
      StockItem(id: 's5', name: 'Riz', unit: 'kg', currentQuantity: 50, minQuantity: 15, maxQuantity: 150, unitCost: 450, category: 'Féculents'),
      StockItem(id: 's6', name: 'Tomates', unit: 'kg', currentQuantity: 2, minQuantity: 3, maxQuantity: 20, unitCost: 600, category: 'Légumes'),
      StockItem(id: 's7', name: 'Oignons', unit: 'kg', currentQuantity: 0, minQuantity: 3, maxQuantity: 20, unitCost: 400, category: 'Légumes'),
      StockItem(id: 's8', name: 'Coca-Cola 1L', unit: 'bouteilles', currentQuantity: 100, minQuantity: 20, maxQuantity: 200, unitCost: 350, category: 'Boissons'),
      StockItem(id: 's9', name: 'Eau Minérale', unit: 'bouteilles', currentQuantity: 150, minQuantity: 30, maxQuantity: 300, unitCost: 200, category: 'Boissons'),
      StockItem(id: 's10', name: 'Piment', unit: 'kg', currentQuantity: 1, minQuantity: 2, maxQuantity: 10, unitCost: 1500, category: 'Épices & Huiles', expiryDate: DateTime.now().add(const Duration(days: 3))),
    ];

    // Suppliers
    _suppliers = [
      Supplier(id: 'sup1', name: 'Poissonnerie Adjoua', contact: 'Adjoua Koné', phone: '+225 07 33 44 55'),
      Supplier(id: 'sup2', name: 'Élevage Bamory', contact: 'Bamory Traoré', phone: '+225 05 66 77 88'),
      Supplier(id: 'sup3', name: 'Marché Légumes Yopou', contact: 'Yaya Diallo', phone: '+225 01 99 00 11'),
    ];

    // Sample orders
    final now = DateTime.now();
    _orders = [
      Order(
        id: 'o1', orderNumber: 151, tableNumber: '05',
        serverName: 'Fatou', status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 12)),
        startedAt: now.subtract(const Duration(minutes: 10)),
        items: [
          OrderItem(productId: 'p1', productName: 'Poisson Braisé', quantity: 2, unitPrice: 3500),
          OrderItem(productId: 'p6', productName: 'Attiéké', quantity: 2, unitPrice: 500),
          OrderItem(productId: 'p9', productName: 'Coca-Cola', quantity: 3, unitPrice: 500),
        ],
      ),
      Order(
        id: 'o2', orderNumber: 152, tableNumber: '03',
        serverName: 'Fatou', status: OrderStatus.pending,
        isUrgent: true,
        createdAt: now.subtract(const Duration(minutes: 3)),
        items: [
          OrderItem(productId: 'p2', productName: 'Poulet Braisé', quantity: 1, unitPrice: 3000),
          OrderItem(productId: 'p8', productName: 'Alloco', quantity: 1, unitPrice: 600),
          OrderItem(productId: 'p10', productName: 'Eau Minérale', quantity: 2, unitPrice: 300),
        ],
      ),
      Order(
        id: 'o3', orderNumber: 153, tableNumber: '08',
        serverName: 'Fatou', status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 28)),
        startedAt: now.subtract(const Duration(minutes: 25)),
        readyAt: now.subtract(const Duration(minutes: 2)),
        items: [
          OrderItem(productId: 'p5', productName: 'Garba', quantity: 3, unitPrice: 1500),
          OrderItem(productId: 'p11', productName: 'Jus de Bissap', quantity: 3, unitPrice: 400),
        ],
      ),
    ];

    // Messages
    _messages = [
      ChatMessage(id: 'm1', senderId: 'u3', senderName: 'Mamadou Chef', content: 'La commande 151 sera bientôt prête !', type: MessageType.text, sentAt: now.subtract(const Duration(minutes: 5))),
      ChatMessage(id: 'm2', senderId: 'u2', senderName: 'Aya Koné', content: 'Merci, j\'attends !', type: MessageType.text, sentAt: now.subtract(const Duration(minutes: 4))),
      ChatMessage(id: 'm3', senderId: 'u1', senderName: 'Kouamé Admin', content: 'Bonjour équipe, bonne journée à tous !', type: MessageType.text, sentAt: now.subtract(const Duration(hours: 2))),
    ];

    // Today's attendance
    final today = DateTime.now();
    _attendances = [
      Attendance(id: 'a1', userId: 'u2', userName: 'Aya Koné', date: today, morningPresent: true, morningTime: DateTime(today.year, today.month, today.day, 8, 0)),
      Attendance(id: 'a2', userId: 'u3', userName: 'Mamadou Chef', date: today, morningPresent: true, morningTime: DateTime(today.year, today.month, today.day, 7, 30)),
      Attendance(id: 'a3', userId: 'u4', userName: 'Fatou Servante', date: today, morningPresent: true, morningTime: DateTime(today.year, today.month, today.day, 8, 15)),
      Attendance(id: 'a4', userId: 'u5', userName: 'Ibrahim Manager', date: today, morningPresent: false),
    ];

    // Supplier orders
    _supplierOrders = [
      SupplierOrder(
        id: 'so1', supplierId: 'sup1', supplierName: 'Poissonnerie Adjoua',
        items: [{'name': 'Poisson Tilapia', 'quantity': 20, 'unit': 'kg', 'unitPrice': 2000}],
        totalAmount: 40000, paidAmount: 20000,
        paymentStatus: SupplierPaymentStatus.partial,
        paymentMethod: 'Espèces',
        orderDate: DateTime.now().subtract(const Duration(days: 2)),
        expectedDelivery: DateTime.now().add(const Duration(days: 1)),
      ),
    ];
  }

  // =================== LOGIN Firebase ===================
  Future<bool> loginWithFirebase(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebase.signIn(email, password);
      final uid  = credential?.user?.uid ?? _uuid.v4();
      final mail = credential?.user?.email ?? email;

      // Profil local immédiat
      UserRole role = UserRole.server;
      final low = mail.toLowerCase();
      if (low.contains('admin'))                                      role = UserRole.admin;
      else if (low.contains('manager'))                              role = UserRole.manager;
      else if (low.contains('caiss') || low.contains('cashier'))    role = UserRole.cashier;
      else if (low.contains('cuisine') || low.contains('kitchen'))  role = UserRole.kitchen;

      final namePart = mail.split('@').first;
      final displayName = namePart.isNotEmpty
          ? namePart[0].toUpperCase() + namePart.substring(1).replaceAll(RegExp(r'[._0-9]+'), ' ').trim()
          : 'Utilisateur';

      _currentUser = AppUser(id: uid, name: displayName, email: mail, phone: '', role: role);

      // Démarrer les streams Firestore
      _startFirebaseStreams();

      // Charger le vrai profil en arrière-plan
      _firebase.getUserByUid(uid).then((u) {
        if (u != null) { _currentUser = u; notifyListeners(); }
        else {
          _firebase.saveUser(_currentUser!).catchError((e) {
            debugPrint('[bg] saveUser: $e');
            return null;
          });
        }
      }).catchError((e) { debugPrint('[bg] getUserByUid: $e'); return null; });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e, st) {
      debugPrint('[AppProvider] loginWithFirebase error: $e');
      debugPrint('[AppProvider] stacktrace: $st');
      _errorMessage = _mapAuthError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;  // Ne propage JAMAIS l'exception
    }
  }

  // Garde la compatibilité avec l'ancien code
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
    _subUsers = _firebase.streamUsers().listen((list) {
      _users = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] users: $e'));

    _subProducts = _firebase.streamProducts().listen((list) {
      _products = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] products: $e'));

    _subOrders = _firebase.streamOrders().listen((list) {
      _orders = List<Order>.from(list); notifyListeners();
    }, onError: (e) => debugPrint('[stream] orders: $e'));

    _subStock = _firebase.streamStock().listen((list) {
      _stockItems = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] stock: $e'));

    _subMessages = _firebase.streamMessages().listen((list) {
      _messages = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] messages: $e'));

    _subSuppliers = _firebase.streamSuppliers().listen((list) {
      _suppliers = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] suppliers: $e'));

    _subSupplierOrders = _firebase.streamSupplierOrders().listen((list) {
      _supplierOrders = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] supplierOrders: $e'));

    _subAttendances = _firebase.streamAttendances().listen((list) {
      _attendances = list; notifyListeners();
    }, onError: (e) => debugPrint('[stream] attendances: $e'));
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

  // =================== ORDER MANAGEMENT ===================
  Order createOrder({
    required String tableNumber,
    required List<OrderItem> items,
    String? serverName,
    String? specialInstructions,
    bool isUrgent = false,
  }) {
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
    _orders.insert(0, order);
    
    // Deduct stock
    for (var item in items) {
      final product = _products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', name: '', category: '', price: 0, prepTime: 0));
      if (product.id.isNotEmpty && product.stockQuantity > 0) {
        product.stockQuantity -= item.quantity;
        if (product.stockQuantity <= 0) {
          product.stockQuantity = 0;
          product.isAvailable = false;
        }
      }
    }

    onNewOrder?.call(order);
    notifyListeners();
    return order;
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final order = _orders.firstWhere((o) => o.id == orderId);
    order.status = status;
    if (status == OrderStatus.preparing) order.startedAt = DateTime.now();
    if (status == OrderStatus.ready) order.readyAt = DateTime.now();
    if (status == OrderStatus.served) order.servedAt = DateTime.now();
    notifyListeners();
  }

  void updateOrderItemQuantity(String orderId, String productId, int newQuantity) {
    final order = _orders.firstWhere((o) => o.id == orderId);
    final itemIndex = order.items.indexWhere((i) => i.productId == productId);
    if (itemIndex != -1) {
      if (newQuantity <= 0) {
        order.items.removeAt(itemIndex);
      } else {
        order.items[itemIndex].quantity = newQuantity;
      }
      notifyListeners();
    }
  }

  void payOrder(String orderId, String paymentMethod, double discount, {double amountPaid = 0}) {
    final order = _orders.firstWhere((o) => o.id == orderId);
    order.isPaid = true;
    order.paymentMethod = paymentMethod;
    order.discount = discount;
    order.amountPaid = amountPaid;
    order.status = OrderStatus.served;
    order.servedAt = DateTime.now();
    notifyListeners();
  }

  // =================== PRODUCT MANAGEMENT ===================
  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
    }
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void toggleProductAvailability(String id) {
    final p = _products.firstWhere((p) => p.id == id);
    p.isAvailable = !p.isAvailable;
    notifyListeners();
  }

  // =================== STOCK MANAGEMENT ===================
  void updateStock(String id, double newQuantity) {
    final item = _stockItems.firstWhere((s) => s.id == id);
    item.currentQuantity = newQuantity;
    notifyListeners();
  }

  void addStockItem(StockItem item) {
    _stockItems.add(item);
    notifyListeners();
  }

  // =================== USER MANAGEMENT (simple) ===================
  void addUserDirect(AppUser user) {
    _users.add(user);
    notifyListeners();
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

  // =================== MESSAGING ===================
  void sendMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  List<ChatMessage> getConversation(String userId1, String userId2) {
    return _messages.where((m) =>
      (m.senderId == userId1 && m.receiverId == userId2) ||
      (m.senderId == userId2 && m.receiverId == userId1)
    ).toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  // =================== SUPPLIERS ===================
  void addSupplier(Supplier supplier) {
    _suppliers.add(supplier);
    notifyListeners();
  }

  void addSupplierOrder(SupplierOrder order) {
    _supplierOrders.add(order);
    notifyListeners();
  }

  void updateSupplierOrderPayment(String id, double amount, String method) {
    final order = _supplierOrders.firstWhere((o) => o.id == id);
    order.paidAmount += amount;
    order.paymentMethod = method;
    if (order.paidAmount >= order.totalAmount) {
      order.paymentStatus = SupplierPaymentStatus.paid;
    } else {
      order.paymentStatus = SupplierPaymentStatus.partial;
    }
    notifyListeners();
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

  void addUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) {
    final newUser = AppUser(
      id: _uuid.v4(),
      name: name,
      email: email,
      phone: phone,
      role: role,
    );
    _users.add(newUser);
    notifyListeners();
  }

  void updateUser(
    String id, {
    required String name,
    required String email,
    required String phone,
    required UserRole role,
  }) {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      _users[idx].name = name;
      _users[idx].email = email;
      _users[idx].phone = phone;
      _users[idx].role = role;
      notifyListeners();
    }
  }

  void deleteUser(String id) {
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  void toggleUserActive(String id) {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      _users[idx].isActive = !_users[idx].isActive;
      notifyListeners();
    }
  }

  void changeUserRole(String id, UserRole role) {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx != -1) {
      _users[idx].role = role;
      notifyListeners();
    }
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
