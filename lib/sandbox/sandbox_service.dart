import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/client_models.dart';
import '../models/models.dart';
import 'sandbox_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SANDBOX SERVICE — Service in-memory qui remplace ClientFirebaseService
// Zéro Firebase, zéro Firestore — toutes les données vivent en mémoire
// ═══════════════════════════════════════════════════════════════════════════

class SandboxService {
  static final SandboxService _instance = SandboxService._();
  factory SandboxService() => _instance;
  SandboxService._() {
    _reset();
  }

  final _uuid = const Uuid();

  // ── État in-memory ──────────────────────────────────────────────────────
  late ClientUser _client;
  late List<ClientOrder> _orders;
  late List<DeliveryAddress> _addresses;
  late List<Promotion> _promotions;
  late List<LoyaltyTransaction> _loyaltyHistory;
  late List<Product> _products;
  late OnlineOrderSettings _settings;
  int _orderCounter = 1042;

  // ── StreamControllers pour simuler les streams Firestore ───────────────
  final _ordersController = StreamController<List<ClientOrder>>.broadcast();
  final _addressesController = StreamController<List<DeliveryAddress>>.broadcast();
  final _promotionsController = StreamController<List<Promotion>>.broadcast();
  final _loyaltyController = StreamController<List<LoyaltyTransaction>>.broadcast();
  final _productsController = StreamController<List<Product>>.broadcast();
  final _settingsController = StreamController<OnlineOrderSettings>.broadcast();
  final _clientController = StreamController<ClientUser?>.broadcast();

  // ── Délai simulé pour imiter le réseau ─────────────────────────────────
  static const _delay = Duration(milliseconds: 350);

  // ── Réinitialisation complète (nouveau parcours de test) ───────────────

  void _reset() {
    _client = ClientUser(
      id: SandboxData.demoClient.id,
      name: SandboxData.demoClient.name,
      email: SandboxData.demoClient.email,
      phone: SandboxData.demoClient.phone,
      isActive: true,
      loyaltyPoints: SandboxData.demoClient.loyaltyPoints,
      totalOrders: SandboxData.demoClient.totalOrders,
      totalSpent: SandboxData.demoClient.totalSpent,
      favoriteProductIds: List.from(SandboxData.demoClient.favoriteProductIds),
      createdAt: SandboxData.demoClient.createdAt,
    );
    _orders = List.from(SandboxData.initialOrders);
    _addresses = List.from(SandboxData.addresses);
    _promotions = List.from(SandboxData.promotions);
    _loyaltyHistory = List.from(SandboxData.loyaltyHistory);
    _products = List.from(SandboxData.products);
    _settings = SandboxData.settings;
    _orderCounter = 1042;
  }

  Future<void> resetAll() async {
    await Future.delayed(_delay);
    _reset();
    _notifyAll();
  }

  void _notifyAll() {
    if (!_ordersController.isClosed) _ordersController.add(List.from(_orders));
    if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
    if (!_promotionsController.isClosed) _promotionsController.add(List.from(_promotions));
    if (!_loyaltyController.isClosed) _loyaltyController.add(List.from(_loyaltyHistory));
    if (!_productsController.isClosed) _productsController.add(List.from(_products));
    if (!_settingsController.isClosed) _settingsController.add(_settings);
    if (!_clientController.isClosed) _clientController.add(_client);
  }

  // ── Profil client ──────────────────────────────────────────────────────

  Future<ClientUser?> getClientProfile(String uid) async {
    await Future.delayed(_delay);
    return _client;
  }

  Stream<ClientUser?> streamClientProfile(String uid) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_clientController.isClosed) _clientController.add(_client);
    });
    return _clientController.stream;
  }

  Future<void> updateClientProfile(String uid, Map<String, dynamic> data) async {
    await Future.delayed(_delay);
    if (data['name'] != null) _client.name = data['name'] as String;
    if (data['phone'] != null) _client.phone = data['phone'] as String;
    if (data['favoriteProductIds'] != null) {
      _client.favoriteProductIds = List<String>.from(data['favoriteProductIds'] as List);
    }
    if (!_clientController.isClosed) _clientController.add(_client);
  }

  Future<void> updateLastLogin(String uid) async {
    // no-op en sandbox
    await Future.delayed(const Duration(milliseconds: 50));
    _client.lastLoginAt = DateTime.now();
  }

  // ── Adresses de livraison ──────────────────────────────────────────────

  Stream<List<DeliveryAddress>> streamAddresses(String clientId) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
    });
    return _addressesController.stream;
  }

  Future<String> addAddress(String clientId, DeliveryAddress address) async {
    await Future.delayed(_delay);
    final id = 'addr_${_uuid.v4().substring(0, 8)}';
    final newAddr = DeliveryAddress(
      id: id,
      label: address.label,
      address: address.address,
      details: address.details,
      latitude: address.latitude,
      longitude: address.longitude,
      isDefault: address.isDefault,
      createdAt: DateTime.now(),
    );
    if (address.isDefault) {
      for (var a in _addresses) {
        a.isDefault = false;
      }
    }
    _addresses.insert(0, newAddr);
    if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
    return id;
  }

  Future<void> updateAddress(DeliveryAddress address) async {
    await Future.delayed(_delay);
    final idx = _addresses.indexWhere((a) => a.id == address.id);
    if (idx >= 0) {
      if (address.isDefault) {
        for (var a in _addresses) {
          a.isDefault = false;
        }
      }
      _addresses[idx] = address;
      if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
    }
  }

  Future<void> deleteAddress(String addressId) async {
    await Future.delayed(_delay);
    _addresses.removeWhere((a) => a.id == addressId);
    if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
  }

  Future<void> setDefaultAddress(String clientId, String addressId) async {
    await Future.delayed(_delay);
    for (var a in _addresses) {
      a.isDefault = a.id == addressId;
    }
    if (!_addressesController.isClosed) _addressesController.add(List.from(_addresses));
  }

  // ── Commandes ──────────────────────────────────────────────────────────

  Stream<List<ClientOrder>> streamClientOrders(String clientId) {
    Future.delayed(const Duration(milliseconds: 50), () {
      final sorted = List<ClientOrder>.from(_orders)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!_ordersController.isClosed) _ordersController.add(sorted);
    });
    return _ordersController.stream;
  }

  Stream<List<ClientOrder>> streamAllOnlineOrders() => streamClientOrders('sandbox_demo_001');

  Future<String> createOrder(ClientOrder order) async {
    await Future.delayed(_delay);
    _orderCounter++;
    final id = 'order_sandbox_${_uuid.v4().substring(0, 8)}';
    final orderNumber = '#${_orderCounter.toString().padLeft(4, '0')}';

    final newOrder = ClientOrder(
      id: id,
      clientId: order.clientId,
      clientName: order.clientName,
      clientPhone: order.clientPhone,
      items: List.from(order.items),
      status: ClientOrderStatus.pending,
      orderType: order.orderType,
      deliveryAddress: order.deliveryAddress,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      totalAmount: order.totalAmount,
      deliveryFee: order.deliveryFee,
      depositAmount: order.depositAmount,
      remainingAmount: order.remainingAmount,
      notes: order.notes,
      loyaltyPointsEarned: order.loyaltyPointsEarned,
      orderNumber: orderNumber,
      createdAt: DateTime.now(),
    );

    _orders.insert(0, newOrder);

    // Mettre à jour les stats client
    _client.totalOrders++;
    _client.totalSpent += newOrder.totalAmount + newOrder.deliveryFee;

    final sorted = List<ClientOrder>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!_ordersController.isClosed) _ordersController.add(sorted);
    if (!_clientController.isClosed) _clientController.add(_client);

    return id;
  }

  Future<void> updateOrderStatus(String orderId, ClientOrderStatus status) async {
    await Future.delayed(_delay);
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      _orders[idx].status = status;
      _orders[idx].updatedAt = DateTime.now();

      // Simuler l'assignation d'un livreur quand "En livraison"
      if (status == ClientOrderStatus.delivering) {
        _orders[idx].deliveryPersonName = 'Konan Aya';
        _orders[idx].deliveryPersonPhone = '+225 05 12 34 56';
        _orders[idx].estimatedDeliveryTime = DateTime.now().add(const Duration(minutes: 20));
      }

      final sorted = List<ClientOrder>.from(_orders)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!_ordersController.isClosed) _ordersController.add(sorted);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, ClientOrderStatus.cancelled);
    // Rembourser les points éventuels
    final order = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _orders.first,
    );
    if (order.loyaltyPointsEarned > 0) {
      _client.loyaltyPoints -= order.loyaltyPointsEarned;
      if (!_clientController.isClosed) _clientController.add(_client);
    }
  }

  /// Avance automatiquement le statut d'une commande d'un cran
  Future<ClientOrderStatus?> advanceOrderStatus(String orderId) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return null;

    final current = _orders[idx].status;
    ClientOrderStatus? next;

    switch (current) {
      case ClientOrderStatus.pending:    next = ClientOrderStatus.confirmed;  break;
      case ClientOrderStatus.confirmed:  next = ClientOrderStatus.preparing;  break;
      case ClientOrderStatus.preparing:  next = ClientOrderStatus.ready;      break;
      case ClientOrderStatus.ready:
        // Si livraison → delivering, sinon → delivered (à emporter)
        next = _orders[idx].orderType == OrderType.delivery
            ? ClientOrderStatus.delivering
            : ClientOrderStatus.delivered;
        break;
      case ClientOrderStatus.delivering: next = ClientOrderStatus.delivered;  break;
      case ClientOrderStatus.delivered:  return null;  // Terminé
      case ClientOrderStatus.cancelled:  return null;  // Terminé
    }

    if (next != null) {
      await updateOrderStatus(orderId, next);
      // Créditer les points fidélité si livré
      if (next == ClientOrderStatus.delivered) {
        final pts = _orders[idx].loyaltyPointsEarned;
        if (pts > 0) {
          await addLoyaltyTransaction(LoyaltyTransaction(
            id: '',
            clientId: _client.id,
            type: LoyaltyType.earn,
            points: pts,
            description: 'Points gagnés — ${_orders[idx].orderNumber}',
            orderId: orderId,
          ));
        }
      }
    }
    return next;
  }

  // ── Paramètres en ligne ────────────────────────────────────────────────

  Stream<OnlineOrderSettings> streamOnlineSettings() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_settingsController.isClosed) _settingsController.add(_settings);
    });
    return _settingsController.stream;
  }

  Future<OnlineOrderSettings> getOnlineSettings() async {
    await Future.delayed(_delay);
    return _settings;
  }

  Future<void> saveOnlineSettings(OnlineOrderSettings settings) async {
    await Future.delayed(_delay);
    _settings = settings;
    if (!_settingsController.isClosed) _settingsController.add(_settings);
  }

  // ── Promotions ─────────────────────────────────────────────────────────

  Stream<List<Promotion>> streamActivePromotions() {
    Future.delayed(const Duration(milliseconds: 50), () {
      final active = _promotions.where((p) => p.isValid).toList();
      if (!_promotionsController.isClosed) _promotionsController.add(active);
    });
    return _promotionsController.stream.map((list) => list.where((p) => p.isValid).toList());
  }

  Stream<List<Promotion>> streamAllPromotions() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_promotionsController.isClosed) _promotionsController.add(List.from(_promotions));
    });
    return _promotionsController.stream;
  }

  Future<String> addPromotion(Promotion promo) async {
    await Future.delayed(_delay);
    final id = 'promo_sandbox_${_uuid.v4().substring(0, 8)}';
    _promotions.add(Promotion(
      id: id,
      title: promo.title,
      description: promo.description,
      type: promo.type,
      value: promo.value,
      minOrder: promo.minOrder,
      validUntil: promo.validUntil,
      isActive: promo.isActive,
      code: promo.code,
    ));
    if (!_promotionsController.isClosed) _promotionsController.add(List.from(_promotions));
    return id;
  }

  Future<void> updatePromotion(Promotion promo) async {
    await Future.delayed(_delay);
    final idx = _promotions.indexWhere((p) => p.id == promo.id);
    if (idx >= 0) {
      _promotions[idx] = promo;
      if (!_promotionsController.isClosed) _promotionsController.add(List.from(_promotions));
    }
  }

  Future<void> deletePromotion(String promoId) async {
    await Future.delayed(_delay);
    _promotions.removeWhere((p) => p.id == promoId);
    if (!_promotionsController.isClosed) _promotionsController.add(List.from(_promotions));
  }

  // ── Programme fidélité ─────────────────────────────────────────────────

  Stream<List<LoyaltyTransaction>> streamLoyaltyHistory(String clientId) {
    Future.delayed(const Duration(milliseconds: 50), () {
      final sorted = List<LoyaltyTransaction>.from(_loyaltyHistory)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!_loyaltyController.isClosed) _loyaltyController.add(sorted);
    });
    return _loyaltyController.stream;
  }

  Future<void> addLoyaltyTransaction(LoyaltyTransaction tx) async {
    await Future.delayed(_delay);
    final id = tx.id.isEmpty ? 'tx_sandbox_${_uuid.v4().substring(0, 8)}' : tx.id;
    final newTx = LoyaltyTransaction(
      id: id,
      clientId: tx.clientId,
      type: tx.type,
      points: tx.points,
      description: tx.description,
      createdAt: DateTime.now(),
      orderId: tx.orderId,
    );
    _loyaltyHistory.insert(0, newTx);

    // Mettre à jour le solde
    final delta = tx.type == LoyaltyType.redeem ? -tx.points : tx.points;
    _client.loyaltyPoints += delta;

    final sorted = List<LoyaltyTransaction>.from(_loyaltyHistory)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!_loyaltyController.isClosed) _loyaltyController.add(sorted);
    if (!_clientController.isClosed) _clientController.add(_client);
  }

  // ── Produits menu ──────────────────────────────────────────────────────

  Stream<List<Product>> streamAvailableProducts() {
    Future.delayed(const Duration(milliseconds: 50), () {
      final available = _products.where((p) => p.isAvailable).toList();
      if (!_productsController.isClosed) _productsController.add(available);
    });
    return _productsController.stream.map((list) => list.where((p) => p.isAvailable).toList());
  }

  Stream<List<String>> streamCategories() {
    return streamAvailableProducts().map((prods) {
      return prods.map((p) => p.category).toSet().toList()..sort();
    });
  }

  // ── Gestion clients (admin sandbox) ───────────────────────────────────

  Stream<List<ClientUser>> streamAllClients() {
    return Stream.value([_client]);
  }

  Future<List<Map<String, dynamic>>> getAllClientsRaw() async {
    await Future.delayed(_delay);
    return [_client.toMap()];
  }

  // ── Simulation de paiement d'acompte ──────────────────────────────────

  Future<void> simulateDepositPayment(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      _orders[idx].paymentStatus = ClientPaymentStatus.depositPaid;
      _orders[idx].depositAmount = _orders[idx].totalAmount * 0.3;
      _orders[idx].remainingAmount =
          (_orders[idx].totalAmount + _orders[idx].deliveryFee) -
          _orders[idx].depositAmount;
      _orders[idx].updatedAt = DateTime.now();

      final sorted = List<ClientOrder>.from(_orders)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!_ordersController.isClosed) _ordersController.add(sorted);
    }
  }

  /// Accesseurs directs (lecture) ──────────────────────────────────────────
  ClientUser get currentClient => _client;
  List<ClientOrder> get currentOrders => List.from(_orders);
  List<DeliveryAddress> get currentAddresses => List.from(_addresses);
  OnlineOrderSettings get currentSettings => _settings;

  void dispose() {
    _ordersController.close();
    _addressesController.close();
    _promotionsController.close();
    _loyaltyController.close();
    _productsController.close();
    _settingsController.close();
    _clientController.close();
  }
}
