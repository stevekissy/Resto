import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_models.dart';
import '../models/models.dart';
import '../services/client_firebase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT PROVIDER — State management de l'espace client
// ═══════════════════════════════════════════════════════════════════════════

class ClientProvider extends ChangeNotifier {
  final ClientFirebaseService _svc = ClientFirebaseService();
  /// Exposé pour permettre aux formulaires admin d'appeler addPromotion/addBanner etc.
  ClientFirebaseService get svc => _svc;
  final _uuid = const Uuid();

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
      .where((o) => o.status != ClientOrderStatus.delivered &&
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

  // ── Bannières espace client ────────────────────────────────────────────
  List<AppBanner> _banners = [];
  List<AppBanner> get banners => _banners;
  List<AppBanner> get visibleBanners => _banners.where((b) => b.isVisible).toList();

  // ── Fidélité ───────────────────────────────────────────────────────────
  List<LoyaltyTransaction> _loyaltyHistory = [];
  List<LoyaltyTransaction> get loyaltyHistory => _loyaltyHistory;

  // ── Produits menu ───────────────────────────────────────────────────────
  List<Product> _products = [];
  List<Product> get products => _products;
  List<String> _categories = [];
  List<String> get categories => _categories;

  // ── Paramètres en ligne ─────────────────────────────────────────────────
  OnlineOrderSettings _settings = OnlineOrderSettings.defaults;
  OnlineOrderSettings get settings => _settings;

  // ── Promotion active sélectionnée ──────────────────────────────────────
  Promotion? _selectedPromotion;
  Promotion? get selectedPromotion => _selectedPromotion;

  // ── Type de commande et adresse sélectionnée ───────────────────────────
  OrderType _orderType = OrderType.delivery;
  OrderType get orderType => _orderType;
  DeliveryAddress? _selectedAddress;
  DeliveryAddress? get selectedAddress => _selectedAddress ?? defaultAddress;

  // ── Subscriptions ──────────────────────────────────────────────────────
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _addressesSubscription;
  StreamSubscription? _promotionsSubscription;
  StreamSubscription? _bannersSubscription;
  StreamSubscription? _productsSubscription;
  StreamSubscription? _loyaltySubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _clientSubscription;

  // ── Initialisation après connexion ─────────────────────────────────────

  Future<void> init(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Charger le profil
      _client = await _svc.getClientProfile(uid);
      if (_client == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Mettre à jour lastLogin
      await _svc.updateLastLogin(uid);

      // Démarrer les streams
      _startStreams(uid);

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
      _client = c;
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

    // Bannières visibles (espace client)
    _bannersSubscription?.cancel();
    _bannersSubscription = _svc.streamVisibleBanners().listen((bans) {
      _banners = bans;
      notifyListeners();
    });

    // Produits menu
    _productsSubscription?.cancel();
    _productsSubscription = _svc.streamAvailableProducts().listen((prods) {
      _products = prods;
      // Reconstruire les catégories
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

  // ── Déconnexion ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    _cancelStreams();
    _client = null;
    _orders = [];
    _addresses = [];
    _promotions = [];
    _banners = [];
    _products = [];
    _categories = [];
    _loyaltyHistory = [];
    _cart.clear();
    _selectedPromotion = null;
    await _svc.signOut();
    notifyListeners();
  }

  void _cancelStreams() {
    _clientSubscription?.cancel();
    _ordersSubscription?.cancel();
    _addressesSubscription?.cancel();
    _promotionsSubscription?.cancel();
    _bannersSubscription?.cancel();
    _productsSubscription?.cancel();
    _loyaltySubscription?.cancel();
    _settingsSubscription?.cancel();
  }

  // ── Gestion du panier ───────────────────────────────────────────────────

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

  // ── Calculs panier ─────────────────────────────────────────────────────

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

  // Yango gère les frais de livraison — le client paie directement au livreur
  double get deliveryFee => 0;

  double get discountAmount {
    double d = 0;
    if (_selectedPromotion != null && _selectedPromotion!.type != PromotionType.freeDelivery) {
      d += _selectedPromotion!.computeDiscount(cartTotal);
    }
    // La réduction fidélité est calculée séparément dans le checkout
    return d;
  }

  double get finalTotal => cartTotal - discountAmount;

  double get depositAmount => _settings.computeDeposit(finalTotal);

  double get remainingAmount => finalTotal - depositAmount;

  int get loyaltyPointsToEarn =>
      (finalTotal / _settings.loyaltyPointsPerFCFA).floor();

  // ── Loyalty: réduction calculée à partir des points utilisés ─────────────
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

      final loyaltyDiscountAmt = loyaltyDiscount(loyaltyPointsUsed);
      final total = cartTotal - discountAmount - loyaltyDiscountAmt;
      final depositAmt = _settings.depositRequired
          ? _settings.computeDeposit(total)
          : 0.0;
      final deposit = payDepositNow ? depositAmt : 0.0;

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
        deliveryFee: 0,          // Yango: frais payés directement au livreur
        depositAmount: deposit,
        remainingAmount: total - deposit,
        notes: notes,
        loyaltyPointsEarned: loyaltyPointsToEarn,
        // Champs online
        orderSource: 'online',
        depositRequired: _settings.depositRequired,
        depositPaid: payDepositNow,
        loyaltyPointsUsed: loyaltyPointsUsed,
        loyaltyDiscountAmount: loyaltyDiscountAmt,
        // Yango delivery
        deliveryPartner: _orderType == OrderType.delivery ? 'Yango' : '',
        deliveryFeePaidTo: _orderType == OrderType.delivery ? 'driver' : '',
        deliveryFeeIncluded: false,
        deliveryNote: deliveryNote,
        geoLocation: _orderType == OrderType.delivery && deliveryAddress != null
            ? '${deliveryAddress.latitude ?? ''},${deliveryAddress.longitude ?? ''}'
            : null,
      );

      final orderId = await _svc.createOrder(order);

      // ── Points fidélité UTILISÉS (débit immédiat — réduction appliquée) ──
      // Le débit des points utilisés est immédiat car la réduction est déjà
      // déduite du total de la commande.
      if (loyaltyPointsUsed > 0) {
        await _svc.addLoyaltyTransaction(LoyaltyTransaction(
          id: '',
          clientId: _client!.id,
          type: LoyaltyType.redeem,
          points: -loyaltyPointsUsed,
          description: 'Points utilisés sur commande (-${loyaltyDiscountAmt.toStringAsFixed(0)} F)',
          orderId: orderId,
        ));
        // Mettre à jour le solde de points localement
        _client!.loyaltyPoints -= loyaltyPointsUsed;
      }

      // ── Points fidélité GAGNÉS (crédit différé — APRÈS livraison) ───────
      // NE PAS créditer ici. L'attribution se fait dans updateOrderStatus()
      // quand le statut passe à 'delivered', via awardLoyaltyPoints().
      // Raison : si la commande est annulée/refusée, aucun point ne doit être attribué.

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

  // ── Statut livraison Yango ──────────────────────────────────────────────

  Future<void> updateYangoStatus(String orderId, YangoDeliveryStatus yangoStatus) async {
    await _svc.updateYangoStatus(orderId, yangoStatus);
  }

  // ── Adresses ───────────────────────────────────────────────────────────

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

  // ── Profil ─────────────────────────────────────────────────────────────

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

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<Product> getProductsByCategory(String category) =>
      _products.where((p) => p.category == category).toList();

  List<Product> get favoriteProducts => _products
      .where((p) => _client?.favoriteProductIds.contains(p.id) ?? false)
      .toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Admin : charger uniquement les paramètres (sans session client) ─────
  // ⚠️  Inclut le stream des commandes en ligne (collection 'orders')
  //     afin que provider.orders soit peuplé pour OnlineOrdersAdminScreen.

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

    // Bannières (admin : toutes les bannières via streamAllBanners)
    _bannersSubscription?.cancel();
    _bannersSubscription = _svc.streamAllBanners().listen((bans) {
      _banners = bans;
      notifyListeners();
    });

    // ── CORRECTION CRITIQUE ───────────────────────────────────────────────
    // Sans ce stream, provider.orders reste [] et l'admin ne voit rien.
    // streamAdminOnlineOrders() lit la collection 'orders' (orderSource==online)
    // et la convertit en List<ClientOrder> pour l'écran admin.
    _ordersSubscription?.cancel();
    _ordersSubscription = _svc.streamAdminOnlineOrders().listen(
      (orders) {
        _orders = orders;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[ClientProvider] streamAdminOnlineOrders erreur: $e');
      },
    );
  }

  // ── Admin : sauvegarder les paramètres en ligne ─────────────────────────

  Future<void> saveSettings(OnlineOrderSettings settings) async {
    await _svc.saveOnlineSettings(settings);
  }

  // ── Admin : mettre à jour le statut d'une commande ─────────────────────

  Future<void> updateOrderStatus(String orderId, ClientOrderStatus newStatus) async {
    await _svc.updateOrderStatus(orderId, newStatus);

    // ── Attribution des points fidélité après livraison OU service sur place ──
    // Règle STRICTE : points crédités UNIQUEMENT quand :
    //   1. paymentStatus == fullyPaid
    //   2. orderStatus IN [delivered, served, paid]
    // awardLoyaltyPoints() gère l'idempotence via loyaltyPointsAwarded
    final shouldAward = newStatus == ClientOrderStatus.delivered ||
                        newStatus == ClientOrderStatus.served ||
                        newStatus == ClientOrderStatus.paid;
    if (shouldAward) {
      try {
        // Récupérer la commande depuis le cache local (mis à jour par le stream)
        final order = _orders.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Commande $orderId non trouvée dans le cache'),
        );
        if (order.clientId.isNotEmpty) {
          // 1. Points fidélité (idempotent via loyaltyPointsAwarded)
          await _svc.awardLoyaltyPoints(
            clientOrderId: orderId,
            clientId: order.clientId,
            pointsToAward: order.loyaltyPointsEarned,
          );
          // 2. Bonus parrainage (idempotent via referralBonusAwarded)
          await _svc.processReferralBonus(
            clientId: order.clientId,
            orderId: orderId,
          );
        }
      } catch (e) {
        // Non bloquant : statut déjà mis à jour — peut être rejoué
        debugPrint('[ClientProvider] post-delivery processing erreur: $e');
      }
    }
  }

  // ── Admin : accepter une commande (étape dédiée avant cuisine) ───────────

  Future<void> acceptOrder(String orderId) async {
    await _svc.acceptOrder(orderId);
    // Pas d'attribution de points ici — seulement après paiement/livraison
  }

  // ── Admin : récupérer tous les clients ──────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllClients() async {
    return _svc.getAllClientsRaw();
  }

  // ── Notifications ───────────────────────────────────────────────────────

  ClientNotificationSettings? _notifSettings;
  ClientNotificationSettings get notifSettings =>
      _notifSettings ?? ClientNotificationSettings.defaults(_client?.id ?? '');

  Future<void> loadNotifSettings() async {
    if (_client == null) return;
    _notifSettings = await _svc.getNotificationSettings(_client!.id);
    notifyListeners();
  }

  Future<void> saveNotifSettings(ClientNotificationSettings settings) async {
    await _svc.saveNotificationSettings(settings);
    _notifSettings = settings;
    notifyListeners();
  }

  // ── Support tickets ─────────────────────────────────────────────────────

  List<ClientSupportTicket> _tickets = [];
  List<ClientSupportTicket> get tickets => _tickets;
  StreamSubscription? _ticketsSubscription;

  void startTicketsStream() {
    if (_client == null) return;
    _ticketsSubscription?.cancel();
    _ticketsSubscription = _svc.streamSupportTickets(_client!.id).listen((t) {
      _tickets = t;
      notifyListeners();
    });
  }

  Future<String> createTicket(ClientSupportTicket ticket) async {
    return _svc.createSupportTicket(ticket);
  }

  // ── Sécurité avancée ────────────────────────────────────────────────────

  Future<void> reauthenticate(String email, String password) async {
    await _svc.reauthenticate(email, password);
  }

  Future<void> updatePassword(String newPassword) async {
    await _svc.updatePassword(newPassword);
  }

  Future<void> updateEmail(String newEmail) async {
    await _svc.updateEmail(newEmail);
    if (_client != null) {
      await _svc.updateClientProfile(_client!.id, {'email': newEmail});
    }
  }

  Future<void> signOutAllDevices() async {
    _cancelStreams();
    _client = null;
    _orders = [];
    _addresses = [];
    _promotions = [];
    _banners = [];
    _products = [];
    _categories = [];
    _loyaltyHistory = [];
    _cart.clear();
    _selectedPromotion = null;
    await _svc.signOutAllDevices();
    notifyListeners();
  }


  // ── Parrainage ──────────────────────────────────────────────────────────

  Future<String> initReferralCode() async {
    if (_client == null) throw Exception('Non connecté');
    return _svc.initReferralCode(_client!.id);
  }

  Future<String?> applyReferralCode(String code) async {
    if (_client == null) return 'Non connecté';
    return _svc.applyReferralCode(
      newClientId: _client!.id,
      referralCode: code,
    );
  }

  Future<Map<String, dynamic>?> checkReferralCode(String code) async {
    return _svc.checkReferralCode(code);
  }

  // ── Notifications client ─────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamMyNotifications() {
    if (_client == null) return const Stream.empty();
    return _svc.streamClientNotifications(_client!.id);
  }

  Future<void> markNotificationRead(String notifId) async {
    if (_client == null) return;
    await _svc.markClientNotificationRead(_client!.id, notifId);
  }

  Future<int> getUnreadNotificationsCount() async {
    if (_client == null) return 0;
    return _svc.getUnreadClientNotificationsCount(_client!.id);
  }

  Future<void> deleteAccount() async {
    _cancelStreams();
    _client = null;
    _orders = [];
    _addresses = [];
    _promotions = [];
    _banners = [];
    _products = [];
    _categories = [];
    _loyaltyHistory = [];
    _cart.clear();
    _selectedPromotion = null;
    await _svc.deleteAccount();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticketsSubscription?.cancel();
    _cancelStreams();
    super.dispose();
  }
}
