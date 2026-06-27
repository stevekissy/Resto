import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT MODELS — Espace client SANKADIOKRO
// Collections Firestore : clients, client_orders, client_addresses,
//                         loyalty_transactions, online_settings, promotions
// ═══════════════════════════════════════════════════════════════════════════

// ── Enums ──────────────────────────────────────────────────────────────────

enum ClientOrderStatus {
  pending,      // 0 — Commande reçue, en attente de validation
  confirmed,    // 1 — Acceptée par l'admin
  preparing,    // 2 — Envoyée en cuisine / En préparation
  ready,        // 3 — Prête
  delivering,   // 4 — En livraison
  delivered,    // 5 — Livrée
  cancelled,    // 6 — Annulée
  served,       // 7 — Servie sur place
  paid,         // 8 — Payée / Clôturée
}

extension ClientOrderStatusExt on ClientOrderStatus {
  String get label {
    switch (this) {
      case ClientOrderStatus.pending:    return 'Reçue';
      case ClientOrderStatus.confirmed:  return 'Acceptée';
      case ClientOrderStatus.preparing:  return 'En cuisine';
      case ClientOrderStatus.ready:      return 'Prête';
      case ClientOrderStatus.delivering: return 'En livraison';
      case ClientOrderStatus.delivered:  return 'Livrée';
      case ClientOrderStatus.cancelled:  return 'Annulée';
      case ClientOrderStatus.served:     return 'Servie';
      case ClientOrderStatus.paid:       return 'Payée';
    }
  }

  Color get color {
    switch (this) {
      case ClientOrderStatus.pending:    return const Color(0xFFFFC107);
      case ClientOrderStatus.confirmed:  return const Color(0xFF2196F3);
      case ClientOrderStatus.preparing:  return const Color(0xFFFF9800);
      case ClientOrderStatus.ready:      return const Color(0xFF4CAF50);
      case ClientOrderStatus.delivering: return const Color(0xFF9C27B0);
      case ClientOrderStatus.delivered:  return const Color(0xFF4CAF50);
      case ClientOrderStatus.cancelled:  return const Color(0xFFF44336);
      case ClientOrderStatus.served:     return const Color(0xFF00BCD4);
      case ClientOrderStatus.paid:       return const Color(0xFF4CAF50);
    }
  }

  IconData get icon {
    switch (this) {
      case ClientOrderStatus.pending:    return Icons.hourglass_empty;
      case ClientOrderStatus.confirmed:  return Icons.check_circle_outline;
      case ClientOrderStatus.preparing:  return Icons.restaurant;
      case ClientOrderStatus.ready:      return Icons.done_all;
      case ClientOrderStatus.delivering: return Icons.delivery_dining;
      case ClientOrderStatus.delivered:  return Icons.home;
      case ClientOrderStatus.cancelled:  return Icons.cancel;
      case ClientOrderStatus.served:     return Icons.room_service;
      case ClientOrderStatus.paid:       return Icons.paid;
    }
  }

  int get step {
    switch (this) {
      case ClientOrderStatus.pending:    return 0;
      case ClientOrderStatus.confirmed:  return 1;
      case ClientOrderStatus.preparing:  return 2;
      case ClientOrderStatus.ready:      return 3;
      case ClientOrderStatus.delivering: return 4;
      case ClientOrderStatus.delivered:  return 5;
      case ClientOrderStatus.cancelled:  return -1;
      case ClientOrderStatus.served:     return 5; // même niveau que delivered
      case ClientOrderStatus.paid:       return 6;
    }
  }

  bool get isFinal =>
    this == ClientOrderStatus.delivered ||
    this == ClientOrderStatus.cancelled ||
    this == ClientOrderStatus.served ||
    this == ClientOrderStatus.paid;
}

enum OrderType { delivery, takeaway }

extension OrderTypeExt on OrderType {
  String get label => this == OrderType.delivery ? 'Livraison' : 'À emporter';
  IconData get icon => this == OrderType.delivery ? Icons.delivery_dining : Icons.shopping_bag_outlined;
}

enum ClientPaymentMethod { cashOnDelivery, orangeMoney, mtnMoney, moovMoney, wave, card }

extension ClientPaymentMethodExt on ClientPaymentMethod {
  String get label {
    switch (this) {
      case ClientPaymentMethod.cashOnDelivery: return 'Paiement à la livraison';
      case ClientPaymentMethod.orangeMoney:    return 'Orange Money';
      case ClientPaymentMethod.mtnMoney:       return 'MTN Money';
      case ClientPaymentMethod.moovMoney:      return 'Moov Money';
      case ClientPaymentMethod.wave:           return 'Wave';
      case ClientPaymentMethod.card:           return 'Carte bancaire';
    }
  }

  String get icon {
    switch (this) {
      case ClientPaymentMethod.cashOnDelivery: return '💵';
      case ClientPaymentMethod.orangeMoney:    return '🟠';
      case ClientPaymentMethod.mtnMoney:       return '🟡';
      case ClientPaymentMethod.moovMoney:      return '🔵';
      case ClientPaymentMethod.wave:           return '🌊';
      case ClientPaymentMethod.card:           return '💳';
    }
  }

  Color get color {
    switch (this) {
      case ClientPaymentMethod.cashOnDelivery: return const Color(0xFF4CAF50);
      case ClientPaymentMethod.orangeMoney:    return const Color(0xFFFF5722);
      case ClientPaymentMethod.mtnMoney:       return const Color(0xFFFFB300);
      case ClientPaymentMethod.moovMoney:      return const Color(0xFF2196F3);
      case ClientPaymentMethod.wave:           return const Color(0xFF00BCD4);
      case ClientPaymentMethod.card:           return const Color(0xFF9C27B0);
    }
  }
}

enum ClientPaymentStatus { pending, depositPaid, fullyPaid }

// Type d'acompte configuré par l'admin
enum DepositType { percentage, fixedAmount }

extension DepositTypeExt on DepositType {
  String get label => this == DepositType.percentage ? 'Pourcentage' : 'Montant fixe';
}

// Statut de livraison Yango
enum YangoDeliveryStatus { waiting, called, delivering, delivered }

extension YangoDeliveryStatusExt on YangoDeliveryStatus {
  String get label {
    switch (this) {
      case YangoDeliveryStatus.waiting:    return 'En attente';
      case YangoDeliveryStatus.called:     return 'Yango appelé';
      case YangoDeliveryStatus.delivering: return 'En livraison';
      case YangoDeliveryStatus.delivered:  return 'Livré';
    }
  }
  Color get color {
    switch (this) {
      case YangoDeliveryStatus.waiting:    return const Color(0xFFFFC107);
      case YangoDeliveryStatus.called:     return const Color(0xFFFF9800);
      case YangoDeliveryStatus.delivering: return const Color(0xFF9C27B0);
      case YangoDeliveryStatus.delivered:  return const Color(0xFF4CAF50);
    }
  }
  IconData get icon {
    switch (this) {
      case YangoDeliveryStatus.waiting:    return Icons.hourglass_empty;
      case YangoDeliveryStatus.called:     return Icons.phone_in_talk_outlined;
      case YangoDeliveryStatus.delivering: return Icons.delivery_dining;
      case YangoDeliveryStatus.delivered:  return Icons.home;
    }
  }
}

extension ClientPaymentStatusExt on ClientPaymentStatus {
  String get label {
    switch (this) {
      case ClientPaymentStatus.pending:     return 'En attente';
      case ClientPaymentStatus.depositPaid: return 'Acompte payé';
      case ClientPaymentStatus.fullyPaid:   return 'Payé';
    }
  }
  Color get color {
    switch (this) {
      case ClientPaymentStatus.pending:     return const Color(0xFFFFC107);
      case ClientPaymentStatus.depositPaid: return const Color(0xFFFF9800);
      case ClientPaymentStatus.fullyPaid:   return const Color(0xFF4CAF50);
    }
  }
}

// ── ClientUser ─────────────────────────────────────────────────────────────

class ClientUser {
  final String id;         // Firebase Auth UID
  String name;
  String email;
  String phone;
  String? avatarUrl;
  bool isActive;
  DateTime createdAt;
  DateTime? lastLoginAt;
  int loyaltyPoints;
  int totalOrders;
  double totalSpent;
  List<String> favoriteProductIds;
  String? fcmToken;        // pour notifications push
  // ── Parrainage ──────────────────────────────────────────────────────────
  String? referralCode;          // code unique parrainage (ex: SKR-A1B2C3)
  String? referredBy;            // clientId du parrain (si filleul)
  bool referralBonusAwarded;     // true = bonus filleul déjà attribué

  ClientUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.isActive = true,
    DateTime? createdAt,
    this.lastLoginAt,
    this.loyaltyPoints = 0,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.favoriteProductIds = const [],
    this.fcmToken,
    this.referralCode,
    this.referredBy,
    this.referralBonusAwarded = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'isActive': isActive,
    'active': isActive,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
    'loyaltyPoints': loyaltyPoints,
    'totalOrders': totalOrders,
    'totalSpent': totalSpent,
    'favoriteProductIds': favoriteProductIds,
    'fcmToken': fcmToken,
    'role': 'client',
    'accountType': 'customer',
    'canLogin': true,
    'referralCode': referralCode,
    'referredBy': referredBy,
    'referralBonusAwarded': referralBonusAwarded,
  };

  factory ClientUser.fromMap(Map<String, dynamic> m) => ClientUser(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? 'Client',
    email: m['email'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    avatarUrl: m['avatarUrl'] as String?,
    isActive: m['isActive'] as bool? ?? true,
    createdAt: m['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
        : DateTime.now(),
    lastLoginAt: m['lastLoginAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['lastLoginAt'] as int)
        : null,
    loyaltyPoints: (m['loyaltyPoints'] as num?)?.toInt() ?? 0,
    totalOrders: (m['totalOrders'] as num?)?.toInt() ?? 0,
    totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0,
    favoriteProductIds: (m['favoriteProductIds'] as List?)?.cast<String>() ?? [],
    fcmToken: m['fcmToken'] as String?,
    referralCode: m['referralCode'] as String?,
    referredBy: m['referredBy'] as String?,
    referralBonusAwarded: m['referralBonusAwarded'] as bool? ?? false,
  );
}

// ── DeliveryAddress ────────────────────────────────────────────────────────

class DeliveryAddress {
  final String id;
  String label;       // 'Maison', 'Bureau', 'Autre'
  String address;     // adresse textuelle complète
  String? details;    // informations complémentaires
  double? latitude;
  double? longitude;
  bool isDefault;
  DateTime createdAt;

  DeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    this.details,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon {
    switch (label.toLowerCase()) {
      case 'maison': return Icons.home_outlined;
      case 'bureau': return Icons.business_outlined;
      default: return Icons.location_on_outlined;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'address': address,
    'details': details,
    'latitude': latitude,
    'longitude': longitude,
    'isDefault': isDefault,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory DeliveryAddress.fromMap(Map<String, dynamic> m) => DeliveryAddress(
    id: m['id'] as String? ?? '',
    label: m['label'] as String? ?? 'Adresse',
    address: m['address'] as String? ?? '',
    details: m['details'] as String?,
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    isDefault: m['isDefault'] as bool? ?? false,
    createdAt: m['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
        : DateTime.now(),
  );
}

// ── CartItem ───────────────────────────────────────────────────────────────

class CartItem {
  final String productId;
  final String productName;
  final String? categoryName;
  final double unitPrice;
  int quantity;
  String? comment;
  String? imageUrl;
  // itemType : 'menu' (plat cuisine) | 'cambuse' (boisson stock)
  // Par défaut 'menu' pour toutes les commandes client en ligne
  final String itemType;

  CartItem({
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.unitPrice,
    this.quantity = 1,
    this.comment,
    this.imageUrl,
    this.itemType = 'menu', // défaut : plat de cuisine
  });

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'name': productName,          // alias cuisine
    'categoryName': categoryName,
    'unitPrice': unitPrice,
    'price': unitPrice,           // alias cuisine
    'quantity': quantity,
    'comment': comment ?? '',
    'imageUrl': imageUrl,
    'itemType': itemType,         // 'menu' | 'cambuse' — OBLIGATOIRE
  };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    productId: m['productId'] as String? ?? '',
    // Lire 'productName' en priorité, fallback sur alias 'name'
    productName: (m['productName'] as String?)?.isNotEmpty == true
        ? m['productName'] as String
        : (m['name'] as String? ?? ''),
    categoryName: m['categoryName'] as String?,
    // Lire 'unitPrice' en priorité, fallback sur alias 'price'
    unitPrice: (m['unitPrice'] as num?)?.toDouble()
        ?? (m['price'] as num?)?.toDouble()
        ?? 0,
    quantity: (m['quantity'] as num?)?.toInt() ?? 1,
    comment: m['comment'] as String?,
    imageUrl: m['imageUrl'] as String?,
    itemType: m['itemType'] as String? ?? 'menu', // défaut rétrocompat
  );

  CartItem copyWith({int? quantity, String? comment}) => CartItem(
    productId: productId,
    productName: productName,
    categoryName: categoryName,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
    comment: comment ?? this.comment,
    imageUrl: imageUrl,
    itemType: itemType,
  );
}

// ── ClientOrder ────────────────────────────────────────────────────────────

class ClientOrder {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final List<CartItem> items;
  ClientOrderStatus status;
  OrderType orderType;
  DeliveryAddress? deliveryAddress;
  ClientPaymentMethod paymentMethod;
  ClientPaymentStatus paymentStatus;
  double totalAmount;
  double deliveryFee;
  double depositAmount;    // acompte payé
  double remainingAmount;  // reste à payer
  String? notes;           // commentaire global
  DateTime createdAt;
  DateTime? updatedAt;
  DateTime? estimatedDeliveryTime;
  String? deliveryPersonName;
  String? deliveryPersonPhone;
  double? deliveryLat;
  double? deliveryLng;
  int loyaltyPointsEarned;
  // Champs commandes en ligne
  String orderSource;          // 'online' | 'pos'
  bool depositRequired;
  bool depositPaid;
  int loyaltyPointsUsed;       // points fidélité utilisés
  double loyaltyDiscountAmount; // réduction calculée
  // Yango delivery
  String deliveryPartner;      // 'Yango' | 'self' | ''
  String deliveryFeePaidTo;    // 'driver' | 'restaurant' | ''
  bool deliveryFeeIncluded;    // false = frais non inclus dans total
  String? deliveryNote;        // note livraison Yango
  String? geoLocation;         // 'lat,lng' formaté
  YangoDeliveryStatus yangoStatus;
  // Réf interne (lien avec commande cuisine dans collection orders)
  String? internalOrderId;
  String? orderNumber;     // numéro lisible ex: #1042
  // Points fidélité — attribués uniquement après paiement confirmé
  bool loyaltyPointsAwarded;        // true = points déjà crédités (idempotence)
  DateTime? loyaltyPointsAwardedAt; // timestamp de l'attribution

  // ── Timestamps workflow ─────────────────────────────────────────────────
  DateTime? confirmedAt;     // admin confirme la commande
  DateTime? sentToKitchenAt; // envoyée en cuisine
  DateTime? readyAt;         // prête à livrer
  DateTime? deliveredAt;     // livrée au client
  DateTime? settledAt;       // solde encaissé (clôturée)

  ClientOrder({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.items,
    this.status = ClientOrderStatus.pending,
    this.orderType = OrderType.delivery,
    this.deliveryAddress,
    this.paymentMethod = ClientPaymentMethod.cashOnDelivery,
    this.paymentStatus = ClientPaymentStatus.pending,
    required this.totalAmount,
    this.deliveryFee = 0,
    this.depositAmount = 0,
    this.remainingAmount = 0,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
    this.estimatedDeliveryTime,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.deliveryLat,
    this.deliveryLng,
    this.loyaltyPointsEarned = 0,
    this.orderSource = 'online',
    this.depositRequired = false,
    this.depositPaid = false,
    this.loyaltyPointsUsed = 0,
    this.loyaltyDiscountAmount = 0,
    this.deliveryPartner = 'Yango',
    this.deliveryFeePaidTo = 'driver',
    this.deliveryFeeIncluded = false,
    this.deliveryNote,
    this.geoLocation,
    this.yangoStatus = YangoDeliveryStatus.waiting,
    this.internalOrderId,
    this.orderNumber,
    this.loyaltyPointsAwarded = false,
    this.loyaltyPointsAwardedAt,
    this.confirmedAt,
    this.sentToKitchenAt,
    this.readyAt,
    this.deliveredAt,
    this.settledAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get grandTotal => totalAmount + deliveryFee;

  ClientOrder copyWith({
    String? id,
    ClientOrderStatus? status,
    YangoDeliveryStatus? yangoStatus,
    bool? depositPaid,
    String? internalOrderId,
    String? orderNumber,
    DateTime? updatedAt,
    ClientPaymentStatus? paymentStatus,
    bool? loyaltyPointsAwarded,
    DateTime? loyaltyPointsAwardedAt,
  }) => ClientOrder(
    id: id ?? this.id,
    clientId: clientId,
    clientName: clientName,
    clientPhone: clientPhone,
    items: items,
    status: status ?? this.status,
    orderType: orderType,
    deliveryAddress: deliveryAddress,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    totalAmount: totalAmount,
    deliveryFee: deliveryFee,
    depositAmount: depositAmount,
    remainingAmount: remainingAmount,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    estimatedDeliveryTime: estimatedDeliveryTime,
    deliveryPersonName: deliveryPersonName,
    deliveryPersonPhone: deliveryPersonPhone,
    deliveryLat: deliveryLat,
    deliveryLng: deliveryLng,
    loyaltyPointsEarned: loyaltyPointsEarned,
    orderSource: orderSource,
    depositRequired: depositRequired,
    depositPaid: depositPaid ?? this.depositPaid,
    loyaltyPointsUsed: loyaltyPointsUsed,
    loyaltyDiscountAmount: loyaltyDiscountAmount,
    deliveryPartner: deliveryPartner,
    deliveryFeePaidTo: deliveryFeePaidTo,
    deliveryFeeIncluded: deliveryFeeIncluded,
    deliveryNote: deliveryNote,
    geoLocation: geoLocation,
    yangoStatus: yangoStatus ?? this.yangoStatus,
    internalOrderId: internalOrderId ?? this.internalOrderId,
    orderNumber: orderNumber ?? this.orderNumber,
    loyaltyPointsAwarded: loyaltyPointsAwarded ?? this.loyaltyPointsAwarded,
    loyaltyPointsAwardedAt: loyaltyPointsAwardedAt ?? this.loyaltyPointsAwardedAt,
    confirmedAt: this.confirmedAt,
    sentToKitchenAt: this.sentToKitchenAt,
    readyAt: this.readyAt,
    deliveredAt: this.deliveredAt,
    settledAt: this.settledAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'items': items.map((i) => i.toMap()).toList(),
    'status': status.index,
    'orderType': orderType.index,
    'deliveryAddress': deliveryAddress?.toMap(),
    'paymentMethod': paymentMethod.index,
    'paymentStatus': paymentStatus.index,
    'totalAmount': totalAmount,
    'deliveryFee': deliveryFee,
    'depositAmount': depositAmount,
    'remainingAmount': remainingAmount,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'estimatedDeliveryTime': estimatedDeliveryTime?.millisecondsSinceEpoch,
    'deliveryPersonName': deliveryPersonName,
    'deliveryPersonPhone': deliveryPersonPhone,
    'deliveryLat': deliveryLat,
    'deliveryLng': deliveryLng,
    'loyaltyPointsEarned': loyaltyPointsEarned,
    'orderSource': orderSource,
    'depositRequired': depositRequired,
    'depositPaid': depositPaid,
    'loyaltyPointsUsed': loyaltyPointsUsed,
    'loyaltyDiscountAmount': loyaltyDiscountAmount,
    'deliveryPartner': deliveryPartner,
    'deliveryFeePaidTo': deliveryFeePaidTo,
    'deliveryFeeIncluded': deliveryFeeIncluded,
    'deliveryNote': deliveryNote,
    'geoLocation': geoLocation,
    'yangoStatus': yangoStatus.index,
    'internalOrderId': internalOrderId,
    'orderNumber': orderNumber,
    'loyaltyPointsAwarded': loyaltyPointsAwarded,
    'loyaltyPointsAwardedAt': loyaltyPointsAwardedAt?.millisecondsSinceEpoch,
    'confirmedAt': confirmedAt?.millisecondsSinceEpoch,
    'sentToKitchenAt': sentToKitchenAt?.millisecondsSinceEpoch,
    'readyAt': readyAt?.millisecondsSinceEpoch,
    'deliveredAt': deliveredAt?.millisecondsSinceEpoch,
    'settledAt': settledAt?.millisecondsSinceEpoch,
    'source': 'online',
  };

  factory ClientOrder.fromMap(Map<String, dynamic> m) => ClientOrder(
    id: m['id'] as String? ?? '',
    clientId: m['clientId'] as String? ?? '',
    clientName: m['clientName'] as String? ?? '',
    clientPhone: m['clientPhone'] as String? ?? '',
    items: (m['items'] as List?)
        ?.map((i) => CartItem.fromMap(i as Map<String, dynamic>))
        .toList() ?? [],
    status: ClientOrderStatus.values[((m['status'] as num?)?.toInt() ?? 0)
        .clamp(0, ClientOrderStatus.values.length - 1)],
    orderType: OrderType.values[(m['orderType'] as num?)?.toInt() ?? 0],
    deliveryAddress: m['deliveryAddress'] != null
        ? DeliveryAddress.fromMap(m['deliveryAddress'] as Map<String, dynamic>)
        : null,
    paymentMethod: ClientPaymentMethod.values[(m['paymentMethod'] as num?)?.toInt() ?? 0],
    paymentStatus: ClientPaymentStatus.values[(m['paymentStatus'] as num?)?.toInt() ?? 0],
    totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
    deliveryFee: (m['deliveryFee'] as num?)?.toDouble() ?? 0,
    depositAmount: (m['depositAmount'] as num?)?.toDouble() ?? 0,
    remainingAmount: (m['remainingAmount'] as num?)?.toDouble() ?? 0,
    notes: m['notes'] as String?,
    createdAt: m['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
        : (m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now()),
    updatedAt: m['updatedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int)
        : null,
    estimatedDeliveryTime: m['estimatedDeliveryTime'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['estimatedDeliveryTime'] as int)
        : null,
    deliveryPersonName: m['deliveryPersonName'] as String?,
    deliveryPersonPhone: m['deliveryPersonPhone'] as String?,
    deliveryLat: (m['deliveryLat'] as num?)?.toDouble(),
    deliveryLng: (m['deliveryLng'] as num?)?.toDouble(),
    loyaltyPointsEarned: (m['loyaltyPointsEarned'] as num?)?.toInt() ?? 0,
    orderSource: m['orderSource'] as String? ?? 'online',
    depositRequired: m['depositRequired'] as bool? ?? false,
    depositPaid: m['depositPaid'] as bool? ?? false,
    loyaltyPointsUsed: (m['loyaltyPointsUsed'] as num?)?.toInt() ?? 0,
    loyaltyDiscountAmount: (m['loyaltyDiscountAmount'] as num?)?.toDouble() ?? 0,
    deliveryPartner: m['deliveryPartner'] as String? ?? 'Yango',
    deliveryFeePaidTo: m['deliveryFeePaidTo'] as String? ?? 'driver',
    deliveryFeeIncluded: m['deliveryFeeIncluded'] as bool? ?? false,
    deliveryNote: m['deliveryNote'] as String?,
    geoLocation: m['geoLocation'] as String?,
    yangoStatus: YangoDeliveryStatus.values[(m['yangoStatus'] as num?)?.toInt() ?? 0],
    internalOrderId: m['internalOrderId'] as String?,
    orderNumber: m['orderNumber'] as String?,
    loyaltyPointsAwarded: m['loyaltyPointsAwarded'] as bool? ?? false,
    loyaltyPointsAwardedAt: m['loyaltyPointsAwardedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['loyaltyPointsAwardedAt'] as int)
        : null,
    confirmedAt: m['confirmedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['confirmedAt'] as int)
        : (m['confirmedAt'] is Timestamp ? (m['confirmedAt'] as Timestamp).toDate() : null),
    sentToKitchenAt: m['sentToKitchenAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['sentToKitchenAt'] as int)
        : (m['sentToKitchenAt'] is Timestamp ? (m['sentToKitchenAt'] as Timestamp).toDate() : null),
    readyAt: m['readyAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['readyAt'] as int)
        : (m['readyAt'] is Timestamp ? (m['readyAt'] as Timestamp).toDate() : null),
    deliveredAt: m['deliveredAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['deliveredAt'] as int)
        : (m['deliveredAt'] is Timestamp ? (m['deliveredAt'] as Timestamp).toDate() : null),
    settledAt: m['settledAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['settledAt'] as int)
        : (m['settledAt'] is Timestamp ? (m['settledAt'] as Timestamp).toDate() : null),
  );
}

// ── LoyaltyTransaction ─────────────────────────────────────────────────────

enum LoyaltyType { earn, redeem, bonus, expiry }

class LoyaltyTransaction {
  final String id;
  final String clientId;
  final LoyaltyType type;
  final int points;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  LoyaltyTransaction({
    required this.id,
    required this.clientId,
    required this.type,
    required this.points,
    required this.description,
    DateTime? createdAt,
    this.orderId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'type': type.index,
    'points': points,
    'description': description,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'orderId': orderId,
  };

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> m) => LoyaltyTransaction(
    id: m['id'] as String? ?? '',
    clientId: m['clientId'] as String? ?? '',
    type: LoyaltyType.values[(m['type'] as num?)?.toInt() ?? 0],
    points: (m['points'] as num?)?.toInt() ?? 0,
    description: m['description'] as String? ?? '',
    createdAt: m['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
        : DateTime.now(),
    orderId: m['orderId'] as String?,
  );
}

// ── Promotion ──────────────────────────────────────────────────────────────

enum PromotionType { percentage, fixedAmount, freeDelivery }

class Promotion {
  final String id;
  String title;
  String description;
  String? imageUrl;
  PromotionType type;
  double value;        // % ou montant fixe
  double? minOrder;    // commande minimum
  DateTime? validUntil;
  bool isActive;
  String? code;        // code promo optionnel
  List<String> applicableProductIds; // vide = applicable à tout

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    required this.value,
    this.minOrder,
    this.validUntil,
    this.isActive = true,
    this.code,
    this.applicableProductIds = const [],
  });

  bool get isExpired => validUntil != null && DateTime.now().isAfter(validUntil!);
  bool get isValid => isActive && !isExpired;

  String get valueLabel {
    switch (type) {
      case PromotionType.percentage:  return '-${value.toStringAsFixed(0)}%';
      case PromotionType.fixedAmount: return '-${value.toStringAsFixed(0)} F';
      case PromotionType.freeDelivery: return 'Livraison offerte';
    }
  }

  double computeDiscount(double orderTotal) {
    switch (type) {
      case PromotionType.percentage:   return orderTotal * value / 100;
      case PromotionType.fixedAmount:  return value;
      case PromotionType.freeDelivery: return 0; // géré séparément
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'type': type.index,
    'value': value,
    'minOrder': minOrder,
    'validUntil': validUntil?.millisecondsSinceEpoch,
    'isActive': isActive,
    'code': code,
    'applicableProductIds': applicableProductIds,
  };

  factory Promotion.fromMap(Map<String, dynamic> m) => Promotion(
    id: m['id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    imageUrl: m['imageUrl'] as String?,
    type: PromotionType.values[(m['type'] as num?)?.toInt() ?? 0],
    value: (m['value'] as num?)?.toDouble() ?? 0,
    minOrder: (m['minOrder'] as num?)?.toDouble(),
    validUntil: m['validUntil'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['validUntil'] as int)
        : null,
    isActive: m['isActive'] as bool? ?? true,
    code: m['code'] as String?,
    applicableProductIds: (m['applicableProductIds'] as List?)?.cast<String>() ?? [],
  );
}

// ── OnlineOrderSettings ────────────────────────────────────────────────────

class OnlineOrderSettings {
  bool isOnlineOrderEnabled;
  bool depositRequired;         // acompte obligatoire oui/non
  DepositType depositType;      // percentage | fixedAmount
  double depositPercentage;     // 0-100 si type=percentage
  double? depositFixedAmount;   // montant fixe si type=fixedAmount
  double deliveryFeeBase;       // non utilisé (Yango gère les frais)
  double? deliveryFeePerKm;
  double maxDeliveryRadiusKm;
  double? restaurantLat;
  double? restaurantLng;
  double minimumOrderAmount;
  int estimatedDeliveryMinutes;
  int estimatedTakeawayMinutes;
  int loyaltyPointsPerFCFA;     // 1 point pour X FCFA dépensé
  int loyaltyPointValue;        // 1 point = X FCFA de réduction
  int minLoyaltyPointsToUse;    // minimum de points utilisables
  String restaurantPhone;
  String restaurantAddress;
  List<String> deliveryZones;

  OnlineOrderSettings({
    this.isOnlineOrderEnabled = true,
    this.depositRequired = true,
    this.depositType = DepositType.percentage,
    this.depositPercentage = 30,
    this.depositFixedAmount,
    this.deliveryFeeBase = 0,        // Yango gère les frais
    this.deliveryFeePerKm,
    this.maxDeliveryRadiusKm = 10,
    this.restaurantLat,
    this.restaurantLng,
    this.minimumOrderAmount = 2000,
    this.estimatedDeliveryMinutes = 45,
    this.estimatedTakeawayMinutes = 20,
    this.loyaltyPointsPerFCFA = 100,
    this.loyaltyPointValue = 5,
    this.minLoyaltyPointsToUse = 10,
    this.restaurantPhone = '',
    this.restaurantAddress = 'Yopougon Millionnaire',
    this.deliveryZones = const [],
  });

  double computeDeposit(double total) {
    if (!depositRequired) return 0;
    if (depositType == DepositType.fixedAmount && depositFixedAmount != null) {
      return depositFixedAmount!;
    }
    return total * depositPercentage / 100;
  }

  Map<String, dynamic> toMap() => {
    'isOnlineOrderEnabled': isOnlineOrderEnabled,
    'depositRequired': depositRequired,
    'depositType': depositType.index,
    'depositPercentage': depositPercentage,
    'depositFixedAmount': depositFixedAmount,
    'deliveryFeeBase': deliveryFeeBase,
    'deliveryFeePerKm': deliveryFeePerKm,
    'maxDeliveryRadiusKm': maxDeliveryRadiusKm,
    'restaurantLat': restaurantLat,
    'restaurantLng': restaurantLng,
    'minimumOrderAmount': minimumOrderAmount,
    'estimatedDeliveryMinutes': estimatedDeliveryMinutes,
    'estimatedTakeawayMinutes': estimatedTakeawayMinutes,
    'loyaltyPointsPerFCFA': loyaltyPointsPerFCFA,
    'loyaltyPointValue': loyaltyPointValue,
    'minLoyaltyPointsToUse': minLoyaltyPointsToUse,
    'restaurantPhone': restaurantPhone,
    'restaurantAddress': restaurantAddress,
    'deliveryZones': deliveryZones,
  };

  factory OnlineOrderSettings.fromMap(Map<String, dynamic> m) => OnlineOrderSettings(
    isOnlineOrderEnabled: m['isOnlineOrderEnabled'] as bool? ?? true,
    depositRequired: m['depositRequired'] as bool? ?? true,
    depositType: DepositType.values[(m['depositType'] as num?)?.toInt() ?? 0],
    depositPercentage: (m['depositPercentage'] as num?)?.toDouble() ?? 30,
    depositFixedAmount: (m['depositFixedAmount'] as num?)?.toDouble(),
    deliveryFeeBase: (m['deliveryFeeBase'] as num?)?.toDouble() ?? 0,
    deliveryFeePerKm: (m['deliveryFeePerKm'] as num?)?.toDouble(),
    maxDeliveryRadiusKm: (m['maxDeliveryRadiusKm'] as num?)?.toDouble() ?? 10,
    restaurantLat: (m['restaurantLat'] as num?)?.toDouble(),
    restaurantLng: (m['restaurantLng'] as num?)?.toDouble(),
    minimumOrderAmount: (m['minimumOrderAmount'] as num?)?.toDouble() ?? 2000,
    estimatedDeliveryMinutes: (m['estimatedDeliveryMinutes'] as num?)?.toInt() ?? 45,
    estimatedTakeawayMinutes: (m['estimatedTakeawayMinutes'] as num?)?.toInt() ?? 20,
    loyaltyPointsPerFCFA: (m['loyaltyPointsPerFCFA'] as num?)?.toInt() ?? 100,
    loyaltyPointValue: (m['loyaltyPointValue'] as num?)?.toInt() ?? 5,
    minLoyaltyPointsToUse: (m['minLoyaltyPointsToUse'] as num?)?.toInt() ?? 10,
    restaurantPhone: m['restaurantPhone'] as String? ?? '',
    restaurantAddress: m['restaurantAddress'] as String? ?? 'Yopougon Millionnaire',
    deliveryZones: (m['deliveryZones'] as List?)?.cast<String>() ?? [],
  );

  static OnlineOrderSettings get defaults => OnlineOrderSettings();
}

// ── ClientNotificationSettings ─────────────────────────────────────────────

class ClientNotificationSettings {
  final String clientId;
  bool orderNotifications;
  bool paymentNotifications;
  bool deliveryNotifications;
  bool promoNotifications;
  bool soundEnabled;
  bool vibrationEnabled;
  DateTime updatedAt;

  ClientNotificationSettings({
    required this.clientId,
    this.orderNotifications = true,
    this.paymentNotifications = true,
    this.deliveryNotifications = true,
    this.promoNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'orderNotifications': orderNotifications,
    'paymentNotifications': paymentNotifications,
    'deliveryNotifications': deliveryNotifications,
    'promoNotifications': promoNotifications,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory ClientNotificationSettings.fromMap(Map<String, dynamic> m) =>
      ClientNotificationSettings(
        clientId: m['clientId'] as String? ?? '',
        orderNotifications: m['orderNotifications'] as bool? ?? true,
        paymentNotifications: m['paymentNotifications'] as bool? ?? true,
        deliveryNotifications: m['deliveryNotifications'] as bool? ?? true,
        promoNotifications: m['promoNotifications'] as bool? ?? true,
        soundEnabled: m['soundEnabled'] as bool? ?? true,
        vibrationEnabled: m['vibrationEnabled'] as bool? ?? true,
        updatedAt: m['updatedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int)
            : DateTime.now(),
      );

  factory ClientNotificationSettings.defaults(String clientId) =>
      ClientNotificationSettings(clientId: clientId);
}

// ── ClientSupportTicket ────────────────────────────────────────────────────

enum SupportTicketStatus { open, inProgress, resolved, closed }

extension SupportTicketStatusExt on SupportTicketStatus {
  String get label {
    switch (this) {
      case SupportTicketStatus.open:       return 'Ouvert';
      case SupportTicketStatus.inProgress: return 'En cours';
      case SupportTicketStatus.resolved:   return 'Résolu';
      case SupportTicketStatus.closed:     return 'Fermé';
    }
  }
  Color get color {
    switch (this) {
      case SupportTicketStatus.open:       return const Color(0xFFFFC107);
      case SupportTicketStatus.inProgress: return const Color(0xFF2196F3);
      case SupportTicketStatus.resolved:   return const Color(0xFF4CAF50);
      case SupportTicketStatus.closed:     return const Color(0xFF9E9E9E);
    }
  }
}

class ClientSupportTicket {
  final String id;
  final String clientId;
  final String clientName;
  final String subject;
  final String message;
  SupportTicketStatus status;
  final String? orderId;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? adminResponse;

  ClientSupportTicket({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.subject,
    required this.message,
    this.status = SupportTicketStatus.open,
    this.orderId,
    DateTime? createdAt,
    this.updatedAt,
    this.adminResponse,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'subject': subject,
    'message': message,
    'status': status.index,
    'orderId': orderId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'adminResponse': adminResponse,
  };

  factory ClientSupportTicket.fromMap(Map<String, dynamic> m) =>
      ClientSupportTicket(
        id: m['id'] as String? ?? '',
        clientId: m['clientId'] as String? ?? '',
        clientName: m['clientName'] as String? ?? '',
        subject: m['subject'] as String? ?? '',
        message: m['message'] as String? ?? '',
        status: SupportTicketStatus
            .values[(m['status'] as num?)?.toInt() ?? 0],
        orderId: m['orderId'] as String?,
        createdAt: m['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
            : DateTime.now(),
        updatedAt: m['updatedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int)
            : null,
        adminResponse: m['adminResponse'] as String?,
      );
}

// ── ReferralTransaction ────────────────────────────────────────────────────
// Enregistre les bonus de parrainage (parrain + filleul)

class ReferralTransaction {
  final String id;
  final String referrerId;    // clientId du parrain
  final String referreeId;    // clientId du filleul
  final int referrerPoints;   // points crédités au parrain
  final int referreePoints;   // points crédités au filleul
  final String orderId;       // commande déclenchante
  final DateTime createdAt;

  ReferralTransaction({
    required this.id,
    required this.referrerId,
    required this.referreeId,
    required this.referrerPoints,
    required this.referreePoints,
    required this.orderId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id':             id,
    'referrerId':     referrerId,
    'referreeId':     referreeId,
    'referrerPoints': referrerPoints,
    'referreePoints': referreePoints,
    'orderId':        orderId,
    'createdAt':      createdAt.millisecondsSinceEpoch,
  };

  factory ReferralTransaction.fromMap(Map<String, dynamic> m) => ReferralTransaction(
    id:             m['id'] as String? ?? '',
    referrerId:     m['referrerId'] as String? ?? '',
    referreeId:     m['referreeId'] as String? ?? '',
    referrerPoints: (m['referrerPoints'] as num?)?.toInt() ?? 0,
    referreePoints: (m['referreePoints'] as num?)?.toInt() ?? 0,
    orderId:        m['orderId'] as String? ?? '',
    createdAt: m['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
        : DateTime.now(),
  );
}
