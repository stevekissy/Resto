import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_models.dart';
import '../models/models.dart';
import '../providers/client_provider.dart';
import 'sandbox_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT PROVIDER PROXY — Interface unifiée pour ClientProvider / SandboxProvider
// Usage : final p = ClientProviderProxy.of(context);
// En mode sandbox → délègue à SandboxProvider
// En mode réel   → délègue à ClientProvider
// ═══════════════════════════════════════════════════════════════════════════

class ClientProviderProxy {
  final bool _isSandbox;
  final ClientProvider? _real;
  final SandboxProvider? _sandbox;

  ClientProviderProxy._({
    required bool isSandbox,
    ClientProvider? real,
    SandboxProvider? sandbox,
  })  : _isSandbox = isSandbox,
        _real = real,
        _sandbox = sandbox;

  /// Factory — détecte automatiquement le mode actif
  static ClientProviderProxy watch(BuildContext context) {
    final sb = context.watch<SandboxProvider>();
    if (sb.isSandboxActive) {
      return ClientProviderProxy._(isSandbox: true, sandbox: sb);
    }
    final real = context.watch<ClientProvider>();
    return ClientProviderProxy._(isSandbox: false, real: real);
  }

  static ClientProviderProxy read(BuildContext context) {
    final sb = context.read<SandboxProvider>();
    if (sb.isSandboxActive) {
      return ClientProviderProxy._(isSandbox: true, sandbox: sb);
    }
    final real = context.read<ClientProvider>();
    return ClientProviderProxy._(isSandbox: false, real: real);
  }

  // ── Accesseurs ─────────────────────────────────────────────────────────

  bool get isSandbox => _isSandbox;

  ClientUser? get client => _isSandbox ? _sandbox!.client : _real!.client;
  bool get isLoggedIn => _isSandbox ? _sandbox!.isLoggedIn : _real!.isLoggedIn;
  bool get isLoading => _isSandbox ? _sandbox!.isLoading : _real!.isLoading;
  String? get error => _isSandbox ? _sandbox!.error : _real!.error;

  List<CartItem> get cart => _isSandbox ? _sandbox!.cart : _real!.cart;
  int get cartCount => _isSandbox ? _sandbox!.cartCount : _real!.cartCount;
  double get cartTotal => _isSandbox ? _sandbox!.cartTotal : _real!.cartTotal;

  List<ClientOrder> get orders => _isSandbox ? _sandbox!.orders : _real!.orders;
  List<ClientOrder> get activeOrders =>
      _isSandbox ? _sandbox!.activeOrders : _real!.activeOrders;

  List<DeliveryAddress> get addresses =>
      _isSandbox ? _sandbox!.addresses : _real!.addresses;
  DeliveryAddress? get defaultAddress =>
      _isSandbox ? _sandbox!.defaultAddress : _real!.defaultAddress;
  DeliveryAddress? get selectedAddress =>
      _isSandbox ? _sandbox!.selectedAddress : _real!.selectedAddress;

  List<Promotion> get promotions =>
      _isSandbox ? _sandbox!.promotions : _real!.promotions;
  List<AppBanner> get banners =>
      _isSandbox ? [] : _real!.banners;
  List<AppBanner> get visibleBanners =>
      _isSandbox ? [] : _real!.visibleBanners;
  List<LoyaltyTransaction> get loyaltyHistory =>
      _isSandbox ? _sandbox!.loyaltyHistory : _real!.loyaltyHistory;
  List<Product> get products =>
      _isSandbox ? _sandbox!.products : _real!.products;
  List<String> get categories =>
      _isSandbox ? _sandbox!.categories : _real!.categories;

  OnlineOrderSettings get settings =>
      _isSandbox ? _sandbox!.settings : _real!.settings;
  Promotion? get selectedPromotion =>
      _isSandbox ? _sandbox!.selectedPromotion : _real!.selectedPromotion;
  OrderType get orderType =>
      _isSandbox ? _sandbox!.orderType : _real!.orderType;

  double get deliveryFee =>
      _isSandbox ? _sandbox!.deliveryFee : _real!.deliveryFee;
  double get discountAmount =>
      _isSandbox ? _sandbox!.discountAmount : _real!.discountAmount;
  double get finalTotal =>
      _isSandbox ? _sandbox!.finalTotal : _real!.finalTotal;
  double get depositAmount =>
      _isSandbox ? _sandbox!.depositAmount : _real!.depositAmount;
  double get remainingAmount =>
      _isSandbox ? _sandbox!.remainingAmount : _real!.remainingAmount;
  int get loyaltyPointsToEarn =>
      _isSandbox ? _sandbox!.loyaltyPointsToEarn : _real!.loyaltyPointsToEarn;

  // ── Méthodes ──────────────────────────────────────────────────────────

  void addToCart(Product product, {int quantity = 1, String? comment}) {
    if (_isSandbox) {
      _sandbox!.addToCart(product, quantity: quantity, comment: comment);
    } else {
      _real!.addToCart(product, quantity: quantity, comment: comment);
    }
  }

  void removeFromCart(String productId) {
    if (_isSandbox) {
      _sandbox!.removeFromCart(productId);
    } else {
      _real!.removeFromCart(productId);
    }
  }

  void updateCartQuantity(String productId, int quantity) {
    if (_isSandbox) {
      _sandbox!.updateCartQuantity(productId, quantity);
    } else {
      _real!.updateCartQuantity(productId, quantity);
    }
  }

  void clearCart() {
    if (_isSandbox) {
      _sandbox!.clearCart();
    } else {
      _real!.clearCart();
    }
  }

  void setOrderType(OrderType type) {
    if (_isSandbox) {
      _sandbox!.setOrderType(type);
    } else {
      _real!.setOrderType(type);
    }
  }

  void setSelectedAddress(DeliveryAddress? address) {
    if (_isSandbox) {
      _sandbox!.setSelectedAddress(address);
    } else {
      _real!.setSelectedAddress(address);
    }
  }

  void applyPromotion(Promotion? promo) {
    if (_isSandbox) {
      _sandbox!.applyPromotion(promo);
    } else {
      _real!.applyPromotion(promo);
    }
  }

  Future<String?> placeOrder({
    required ClientPaymentMethod paymentMethod,
    required DeliveryAddress? deliveryAddress,
    String? notes,
    bool payDepositNow = false,
    int loyaltyPointsUsed = 0,
    String? deliveryNote,
  }) {
    if (_isSandbox) {
      return _sandbox!.placeOrder(
          paymentMethod: paymentMethod,
          deliveryAddress: deliveryAddress,
          notes: notes,
          payDepositNow: payDepositNow,
          loyaltyPointsUsed: loyaltyPointsUsed,
          deliveryNote: deliveryNote);
    }
    return _real!.placeOrder(
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
        notes: notes,
        payDepositNow: payDepositNow,
        loyaltyPointsUsed: loyaltyPointsUsed,
        deliveryNote: deliveryNote);
  }

  /// Calcul de la réduction fidélité (X points → Y FCFA)
  double loyaltyDiscount(int pointsUsed) {
    if (_isSandbox) return _sandbox!.loyaltyDiscount(pointsUsed);
    return _real!.loyaltyDiscount(pointsUsed);
  }

  /// Mise à jour du statut Yango (admin/cuisine)
  Future<void> updateYangoStatus(String orderId, YangoDeliveryStatus yangoStatus) {
    if (_isSandbox) return _sandbox!.updateYangoStatus(orderId, yangoStatus);
    return _real!.updateYangoStatus(orderId, yangoStatus);
  }

  Future<void> cancelOrder(String orderId) {
    if (_isSandbox) return _sandbox!.cancelOrder(orderId);
    return _real!.cancelOrder(orderId);
  }

  Future<void> addAddress(DeliveryAddress address) {
    if (_isSandbox) return _sandbox!.addAddress(address);
    return _real!.addAddress(address);
  }

  Future<void> updateAddress(DeliveryAddress address) {
    if (_isSandbox) return _sandbox!.updateAddress(address);
    return _real!.updateAddress(address);
  }

  Future<void> deleteAddress(String addressId) {
    if (_isSandbox) return _sandbox!.deleteAddress(addressId);
    return _real!.deleteAddress(addressId);
  }

  Future<void> setDefaultAddress(String addressId) {
    if (_isSandbox) return _sandbox!.setDefaultAddress(addressId);
    return _real!.setDefaultAddress(addressId);
  }

  Future<void> updateProfile({String? name, String? phone}) {
    if (_isSandbox) return _sandbox!.updateProfile(name: name, phone: phone);
    return _real!.updateProfile(name: name, phone: phone);
  }

  Future<void> toggleFavorite(String productId) {
    if (_isSandbox) return _sandbox!.toggleFavorite(productId);
    return _real!.toggleFavorite(productId);
  }

  bool isFavorite(String productId) {
    if (_isSandbox) return _sandbox!.isFavorite(productId);
    return _real!.isFavorite(productId);
  }

  List<Product> getProductsByCategory(String category) {
    if (_isSandbox) return _sandbox!.getProductsByCategory(category);
    return _real!.getProductsByCategory(category);
  }

  List<Product> get favoriteProducts {
    if (_isSandbox) return _sandbox!.favoriteProducts;
    return _real!.favoriteProducts;
  }

  void clearError() {
    if (_isSandbox) {
      _sandbox!.clearError();
    } else {
      _real!.clearError();
    }
  }

  Future<void> logout() async {
    if (_isSandbox) {
      await _sandbox!.exitSandbox();
    } else {
      await _real!.logout();
    }
  }
}
