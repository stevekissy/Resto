import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_models.dart';
import '../models/models.dart';
import 'sandbox_service.dart';
import 'sandbox_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SANDBOX PROVIDER — ChangeNotifier miroir de ClientProvider
// Utilise SandboxService (in-memory) à la place de ClientFirebaseService
// Permet un parcours client complet sans aucune connexion Firebase
// ═══════════════════════════════════════════════════════════════════════════

class SandboxProvider extends ChangeNotifier {
  final SandboxService _svc = SandboxService();
  final _uuid = const Uuid();

  // ── Flag mode sandbox ──────────────────────────────────────────────────
  bool _isSandboxActive = false;
  bool get isSandboxActive => _isSandboxActive;

  // ── État utilisateur ───────────────────────────────────────────────────
  ClientUser? _client;
  ClientUser? get client => _client;
  bool get isLoggedIn => _client != null;

  // ── Chargement ─────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  // ── Panier ─────────────────────────────────────────────────────────────
  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);
  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);
  double get cartTotal => _cart.fold(0.0, (s, i) => s + i.totalPrice);

  // ── Commandes ──────────────────────────────────────────────────────────
  List<ClientOrder> _orders = [];
  List<ClientOrder> get orders => _orders;
  List<ClientOrder> get activeOrders => _orders
      .where((o) =>
          o.status != ClientOrderStatus.delivered &&
          o.status != ClientOrderStatus.cancelled)
      .toList();

  // ── Adresses ───────────────────────────────────────────────────────────
  List<DeliveryAddress> _addresses = [];
  List<DeliveryAddress> get addresses => _addresses;
  DeliveryAddress? get defaultAddress =>
      _addresses.where((a) => a.isDefault).isNotEmpty
          ? _addresses.firstWhere((a) => a.isDefault)
          : (_addresses.isNotEmpty ? _addresses.first : null);

  // ── Promotions ─────────────────────────────────────────────────────────
  List<Promotion> _promotions = [];
  List<Promotion> get promotions => _promotions;

  // ── Fidélité ───────────────────────────────────────────────────────────
  List<LoyaltyTransaction> _loyaltyHistory = [];
  List<LoyaltyTransaction> get loyaltyHistory => _loyaltyHistory;

  // ── Produits menu ───────────────────────────────────────────────────────
  List<Product> _products = [];
  List<Product> get products => _products;
  List<String> _categories = [];
  List<String> get categories => _categories;

  // ── Paramètres en ligne ─────────────────────────────────────────────────
  OnlineOrderSettings _settings = SandboxData.settings;
  OnlineOrderSettings get settings => _settings;

  // ── Promotion active sélectionnée ──────────────────────────────────────
  Promotion? _selectedPromotion;
  Promotion? get selectedPromotion => _selectedPromotion;

  // ── Type de commande ───────────────────────────────────────────────────
  OrderType _orderType = OrderType.delivery;
  OrderType get orderType => _orderType;
  DeliveryAddress? _selectedAddress;
  DeliveryAddress? get selectedAddress => _selectedAddress ?? defaultAddress;

  // ── Subscriptions ──────────────────────────────────────────────────────
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _addressesSubscription;
  StreamSubscription? _promotionsSubscription;
  StreamSubscription? _productsSubscription;
  StreamSubscription? _loyaltySubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _clientSubscription;

  // ── Statistiques de session sandbox ────────────────────────────────────
  int _ordersCreatedInSession = 0;
  int get ordersCreatedInSession => _ordersCreatedInSession;
  List<String> _completedScenarios = [];
  List<String> get completedScenarios => _completedScenarios;

  // ── Initialisation du mode sandbox ─────────────────────────────────────

  Future<void> initSandbox() async {
    _isSandboxActive = true;
    _isLoading = true;
    notifyListeners();

    try {
      // Réinitialiser le service sandbox avec les données fraîches
      await _svc.resetAll();

      // Charger le profil démo
      _client = await _svc.getClientProfile(SandboxData.demoClient.id);

      // Démarrer les streams
      _startStreams(SandboxData.demoClient.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startStreams(String uid) {
    // Profil temps réel
    _clientSubscription?.cancel();
    _clientSubscription = _svc.streamClientProfile(uid).listen((c) {
      if (c != null) _client = c;
      notifyListeners();
    });

    // Commandes
    _ordersSubscription?.cancel();
    _ordersSubscription = _svc.streamClientOrders(uid).listen((orders) {
      _orders = orders;
      notifyListeners();
    });

    // Adresses
    _addressesSubscription?.cancel();
    _addressesSubscription = _svc.streamAddresses(uid).listen((addr) {
      _addresses = addr;
      notifyListeners();
    });

    // Promotions
    _promotionsSubscription?.cancel();
    _promotionsSubscription = _svc.streamActivePromotions().listen((promos) {
      _promotions = promos;
      notifyListeners();
    });

    // Produits menu
    _productsSubscription?.cancel();
    _productsSubscription = _svc.streamAvailableProducts().listen((prods) {
      _products = prods;
      _categories = prods.map((p) => p.category).toSet().toList()..sort();
      notifyListeners();
    });

    // Fidélité
    _loyaltySubscription?.cancel();
    _loyaltySubscription = _svc.streamLoyaltyHistory(uid).listen((txs) {
      _loyaltyHistory = txs;
      notifyListeners();
    });

    // Paramètres
    _settingsSubscription?.cancel();
    _settingsSubscription = _svc.streamOnlineSettings().listen((s) {
      _settings = s;
      notifyListeners();
    });
  }

  // ── Quitter le mode sandbox ─────────────────────────────────────────────

  Future<void> exitSandbox() async {
    _cancelStreams();
    _isSandboxActive = false;
    _client = null;
    _orders = [];
    _addresses = [];
    _promotions = [];
    _products = [];
    _categories = [];
    _loyaltyHistory = [];
    _cart.clear();
    _selectedPromotion = null;
    _ordersCreatedInSession = 0;
    _completedScenarios = [];
    notifyListeners();
  }

  void _cancelStreams() {
    _clientSubscription?.cancel();
    _ordersSubscription?.cancel();
    _addressesSubscription?.cancel();
    _promotionsSubscription?.cancel();
    _productsSubscription?.cancel();
    _loyaltySubscription?.cancel();
    _settingsSubscription?.cancel();
  }

  // ── Réinitialiser la session (nouveau test) ─────────────────────────────

  Future<void> resetSession() async {
    _cancelStreams();
    _cart.clear();
    _selectedPromotion = null;
    _ordersCreatedInSession = 0;
    await initSandbox();
  }

  // ── Gestion du panier (identique à ClientProvider) ──────────────────────

  void addToCart(Product product, {int quantity = 1, String? comment}) {
    final existing = _cart.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      _cart[existing] = _cart[existing].copyWith(
        quantity: _cart[existing].quantity + quantity,
      );
    } else {
      _cart.add(CartItem(
        productId: product.id,
        productName: product.name,
        categoryName: product.category,
        unitPrice: product.price,
        quantity: quantity,
        comment: comment,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void updateCartQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(quantity: quantity);
      notifyListeners();
    }
  }

  void updateCartItemComment(String productId, String comment) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(comment: comment);
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _selectedPromotion = null;
    notifyListeners();
  }

  // ── Calculs panier ──────────────────────────────────────────────────────

  void setOrderType(OrderType type) {
    _orderType = type;
    notifyListeners();
  }

  void setSelectedAddress(DeliveryAddress? address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void applyPromotion(Promotion? promo) {
    _selectedPromotion = promo;
    notifyListeners();
  }

  double get deliveryFee => 0; // Yango gère les frais — toujours 0

  double get discountAmount {
    if (_selectedPromotion == null) return 0;
    if (_selectedPromotion!.type == PromotionType.freeDelivery) return 0;
    return _selectedPromotion!.computeDiscount(cartTotal);
  }

  double get finalTotal => cartTotal - discountAmount;
  double get depositAmount => _settings.computeDeposit(finalTotal);
  double get remainingAmount => finalTotal - depositAmount;
  int get loyaltyPointsToEarn =>
      (finalTotal / _settings.loyaltyPointsPerFCFA).floor();

  /// Réduction fidélité : X points → Y FCFA
  double loyaltyDiscount(int pointsUsed) =>
      pointsUsed * _settings.loyaltyPointValue.toDouble();

  // ── Passage de commande ─────────────────────────────────────────────────

  Future<String?> placeOrder({
    required ClientPaymentMethod paymentMethod,
    required DeliveryAddress? deliveryAddress,
    String? notes,
    bool payDepositNow = false,
    int loyaltyPointsUsed = 0,
    String? deliveryNote,
  }) async {
    if (_client == null || _cart.isEmpty) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final loyaltyDisc = loyaltyDiscount(loyaltyPointsUsed);
      final total = cartTotal - discountAmount - loyaltyDisc;
      final deposit = payDepositNow ? _settings.computeDeposit(total) : 0.0;

      final order = ClientOrder(
        id: '',
        clientId: _client!.id,
        clientName: _client!.name,
        clientPhone: _client!.phone,
        items: List.from(_cart),
        status: ClientOrderStatus.pending,
        orderType: _orderType,
        deliveryAddress: _orderType == OrderType.delivery ? deliveryAddress : null,
        paymentMethod: paymentMethod,
        paymentStatus: payDepositNow
            ? ClientPaymentStatus.depositPaid
            : ClientPaymentStatus.pending,
        totalAmount: total,
        deliveryFee: 0,
        depositAmount: deposit,
        remainingAmount: total - deposit,
        notes: notes,
        loyaltyPointsEarned: loyaltyPointsToEarn,
        orderSource: 'online',
        depositRequired: _settings.depositRequired,
        depositPaid: payDepositNow,
        loyaltyPointsUsed: loyaltyPointsUsed,
        loyaltyDiscountAmount: loyaltyDisc,
        deliveryPartner: _orderType == OrderType.delivery ? 'Yango' : '',
        deliveryFeePaidTo: _orderType == OrderType.delivery ? 'driver' : '',
        deliveryFeeIncluded: false,
        deliveryNote: deliveryNote,
      );

      final orderId = await _svc.createOrder(order);
      _ordersCreatedInSession++;

      // Créditer les points fidélité immédiatement en sandbox
      if (loyaltyPointsToEarn > 0) {
        await _svc.addLoyaltyTransaction(LoyaltyTransaction(
          id: '',
          clientId: _client!.id,
          type: LoyaltyType.earn,
          points: loyaltyPointsToEarn,
          description: 'Points gagnés (sandbox)',
          orderId: orderId,
        ));
      }

      clearCart();
      return orderId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await _svc.cancelOrder(orderId);
  }

  /// Mise à jour du statut Yango (sandbox — ne fait rien réellement)
  Future<void> updateYangoStatus(String orderId, YangoDeliveryStatus yangoStatus) async {
    // En mode sandbox, mettre à jour localement
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      _orders[idx] = _orders[idx].copyWith(yangoStatus: yangoStatus);
      notifyListeners();
    }
  }

  // ── Adresses ────────────────────────────────────────────────────────────

  Future<void> addAddress(DeliveryAddress address) async {
    if (_client == null) return;
    await _svc.addAddress(_client!.id, address);
  }

  Future<void> updateAddress(DeliveryAddress address) async {
    await _svc.updateAddress(address);
  }

  Future<void> deleteAddress(String addressId) async {
    await _svc.deleteAddress(addressId);
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_client == null) return;
    await _svc.setDefaultAddress(_client!.id, addressId);
  }

  // ── Profil ──────────────────────────────────────────────────────────────

  Future<void> updateProfile({String? name, String? phone}) async {
    if (_client == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    await _svc.updateClientProfile(_client!.id, data);
  }

  Future<void> toggleFavorite(String productId) async {
    if (_client == null) return;
    final favs = List<String>.from(_client!.favoriteProductIds);
    if (favs.contains(productId)) {
      favs.remove(productId);
    } else {
      favs.add(productId);
    }
    await _svc.updateClientProfile(_client!.id, {'favoriteProductIds': favs});
  }

  bool isFavorite(String productId) =>
      _client?.favoriteProductIds.contains(productId) ?? false;

  // ── Simulation avancée (tableau de bord) ────────────────────────────────

  Future<ClientOrderStatus?> advanceOrderStatus(String orderId) async {
    return _svc.advanceOrderStatus(orderId);
  }

  Future<void> simulateDepositPayment(String orderId) async {
    await _svc.simulateDepositPayment(orderId);
  }

  Future<void> simulateFullDelivery(String orderId) async {
    // Avancer rapidement à travers tous les statuts
    for (var i = 0; i < 6; i++) {
      final status = await _svc.advanceOrderStatus(orderId);
      if (status == null || status == ClientOrderStatus.delivered) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void markScenarioCompleted(String scenarioId) {
    if (!_completedScenarios.contains(scenarioId)) {
      _completedScenarios.add(scenarioId);
      notifyListeners();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<Product> getProductsByCategory(String category) =>
      _products.where((p) => p.category == category).toList();

  List<Product> get favoriteProducts => _products
      .where((p) => _client?.favoriteProductIds.contains(p.id) ?? false)
      .toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Admin sandbox (compatibilité avec OnlineOrdersAdminScreen) ──────────

  Future<void> initSettingsOnly() async {
    _settingsSubscription?.cancel();
    _settingsSubscription = _svc.streamOnlineSettings().listen((s) {
      _settings = s;
      notifyListeners();
    });
    _promotionsSubscription?.cancel();
    _promotionsSubscription = _svc.streamActivePromotions().listen((promos) {
      _promotions = promos;
      notifyListeners();
    });
  }

  Future<void> saveSettings(OnlineOrderSettings settings) async {
    await _svc.saveOnlineSettings(settings);
  }

  Future<void> updateOrderStatus(String orderId, ClientOrderStatus newStatus) async {
    await _svc.updateOrderStatus(orderId, newStatus);
  }

  Future<List<Map<String, dynamic>>> getAllClients() async {
    return _svc.getAllClientsRaw();
  }

  @override
  void dispose() {
    _cancelStreams();
    super.dispose();
  }
}
