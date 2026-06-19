import 'package:flutter/material.dart';

// =================== ENUMS ===================
enum OrderStatus { pending, preparing, ready, served, cancelled }
// Statut de caisse : distinct de OrderStatus (cycle de vie paiement)
// pending_cashout  → prêt à encaisser (commande ready/served non payée)
// awaiting_payment → facture d'encaissement générée, en attente de règlement
// paid             → règlement définitif effectué
enum CashStatus { pending_cashout, awaiting_payment, paid }
enum UserRole { admin, manager, cashier, kitchen, server, stockManager }
enum StockAlertType { lowStock, outOfStock, expired }
enum MessageType { text, image, file, call }
enum AttendanceType { morning, evening }
// unpaid = non payé (ancien 'pending' — rétrocompat index 0)
enum SupplierPaymentStatus { unpaid, partial, paid }

// =================== USER MODEL ===================
class AppUser {
  final String id;
  String name;
  String email;
  String phone;
  UserRole role;
  String? avatarUrl;
  bool isActive;   // alias Firestore : "active"   — l'employé est actif dans l'établissement
  bool isOnline;
  bool canLogin;   // alias Firestore : "canLogin" — autorisé à se connecter à l'app
  String createdBy;
  DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
    this.isOnline = false,
    this.canLogin = false,
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Rétrocompatibilité — anciens documents Firestore utilisaient hasAppAccess
  bool get hasAppAccess => canLogin;

  String get roleLabel {
    switch (role) {
      case UserRole.admin: return 'Administrateur';
      case UserRole.manager: return 'Manager';
      case UserRole.cashier: return 'Caissier(ère)';
      case UserRole.kitchen: return 'Cuisine';
      case UserRole.server: return 'Serveur(se)';
      case UserRole.stockManager: return 'Gestionnaire de stock';
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.admin: return const Color(0xFF1565C0);
      case UserRole.manager: return const Color(0xFF6A1B9A);
      case UserRole.cashier: return const Color(0xFF2E7D32);
      case UserRole.kitchen: return const Color(0xFFE65100);
      case UserRole.server: return const Color(0xFF00838F);
      case UserRole.stockManager: return const Color(0xFF795548);
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'phone': phone,
    'role': role.index, 'avatarUrl': avatarUrl,
    'active': isActive,      // Firestore field : "active"
    'isActive': isActive,    // rétrocompatibilité anciens docs
    'isOnline': isOnline,
    'canLogin': canLogin,    // Firestore field : "canLogin"
    'hasAppAccess': canLogin, // rétrocompatibilité anciens docs
    'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? 'Utilisateur',
    email: map['email'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    role: UserRole.values[(map['role'] as int?) ?? 0],
    avatarUrl: map['avatarUrl'] as String?,
    // "active" prioritaire sur "isActive" pour les nouveaux docs
    isActive: (map['active'] as bool?) ?? (map['isActive'] as bool?) ?? true,
    isOnline: map['isOnline'] as bool? ?? false,
    // "canLogin" prioritaire sur "hasAppAccess" pour les nouveaux docs
    canLogin: (map['canLogin'] as bool?) ?? (map['hasAppAccess'] as bool?) ?? false,
    createdBy: map['createdBy'] as String? ?? '',
    createdAt: map['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
  );
}

// =================== STOCK LINK MODEL ===================
/// Liaison entre un plat/menu et un produit du stock.
/// stockLinks stocke cette liste dans le document Firestore du Product.
class StockLink {
  final String stockItemId;    // id du StockItem dans la collection 'stock'
  final String stockItemName;  // nom dénormalisé pour l'affichage
  final double quantityUsed;   // quantité déduite par portion vendue
  final String unit;           // unité (pièce, portion, kg…)
  final bool mandatory;        // si true : bloque la commande si stock insuffisant

  const StockLink({
    required this.stockItemId,
    required this.stockItemName,
    required this.quantityUsed,
    required this.unit,
    this.mandatory = true,
  });

  Map<String, dynamic> toMap() => {
    'stockItemId': stockItemId,
    'stockItemName': stockItemName,
    'quantityUsed': quantityUsed,
    'unit': unit,
    'mandatory': mandatory,
  };

  factory StockLink.fromMap(Map<String, dynamic> map) => StockLink(
    stockItemId: map['stockItemId'] as String? ?? '',
    stockItemName: map['stockItemName'] as String? ?? '',
    quantityUsed: (map['quantityUsed'] as num?)?.toDouble() ?? 1,
    unit: map['unit'] as String? ?? 'pièce',
    mandatory: map['mandatory'] as bool? ?? true,
  );
}

// =================== STOCK MOVEMENT MODEL ===================
/// Historique des mouvements de stock générés par les commandes.
enum StockMovementType {
  sortieAutomatiqueCommande,       // déduction à la création de commande
  retourAnnulationCommande,        // remise en stock lors d'annulation
  ajustementModificationCommande,  // différence lors d'une modification
  approvisionnement,               // entrée de stock (réapprovisionnement)
  ajustementManuel,                // correction manuelle
}

class StockMovement {
  final String id;
  final String stockItemId;
  final String stockItemName;
  final StockMovementType type;
  final double quantity;   // toujours positif ; le signe dépend du type
  final String unit;
  final String orderId;
  final String menuId;
  final String menuName;
  final DateTime createdAt;
  final String createdBy;
  // Champs supplémentaires pour approvisionnement
  final String? supplierId;
  final String? supplierName;
  final double? purchasePrice;
  final String? note;

  const StockMovement({
    required this.id,
    required this.stockItemId,
    required this.stockItemName,
    required this.type,
    required this.quantity,
    required this.unit,
    this.orderId = '',
    this.menuId = '',
    this.menuName = '',
    required this.createdAt,
    required this.createdBy,
    this.supplierId,
    this.supplierName,
    this.purchasePrice,
    this.note,
  });

  String get typeLabel {
    switch (type) {
      case StockMovementType.sortieAutomatiqueCommande:
        return 'sortie_automatique_commande';
      case StockMovementType.retourAnnulationCommande:
        return 'retour_annulation_commande';
      case StockMovementType.ajustementModificationCommande:
        return 'ajustement_modification_commande';
      case StockMovementType.approvisionnement:
        return 'approvisionnement';
      case StockMovementType.ajustementManuel:
        return 'ajustement_manuel';
    }
}

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': stockItemId,
    'productName': stockItemName,
    'type': typeLabel,
    'quantity': quantity,
    'unit': unit,
    'orderId': orderId,
    'menuId': menuId,
    'menuName': menuName,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'createdBy': createdBy,
    if (supplierId != null) 'supplierId': supplierId,
    if (supplierName != null) 'supplierName': supplierName,
    if (purchasePrice != null) 'purchasePrice': purchasePrice,
    if (note != null) 'note': note,
  };
}

// =================== PRODUCT MODEL ===================
class Product {
  final String id;
  String name;
  String category;
  double price;
  double prepTime; // in minutes
  String? description;
  String? imageUrl;
  bool isAvailable;
  int stockQuantity;
  int minStockAlert;
  Map<String, double> ingredients; // ingredient name -> quantity needed
  List<StockLink> stockLinks;       // liaisons produits stock

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.prepTime,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.stockQuantity = 100,
    this.minStockAlert = 10,
    Map<String, double>? ingredients,
    List<StockLink>? stockLinks,
  })  : ingredients = ingredients ?? {},
        stockLinks = stockLinks ?? [];

  /// true si au moins un lien stock est défini
  bool get hasStockLinks => stockLinks.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'category': category, 'price': price,
    'prepTime': prepTime, 'description': description, 'imageUrl': imageUrl,
    'isAvailable': isAvailable, 'stockQuantity': stockQuantity,
    'minStockAlert': minStockAlert, 'ingredients': ingredients,
    'stockLinks': stockLinks.map((l) => l.toMap()).toList(),
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    category: map['category'] as String? ?? 'Plats',
    price: (map['price'] as num?)?.toDouble() ?? 0,
    prepTime: (map['prepTime'] as num?)?.toDouble() ?? 0,
    description: map['description'] as String?,
    imageUrl: map['imageUrl'] as String?,
    isAvailable: map['isAvailable'] as bool? ?? true,
    stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
    minStockAlert: (map['minStockAlert'] as num?)?.toInt() ?? 10,
    ingredients: Map<String, double>.from(map['ingredients'] ?? {}),
    stockLinks: (map['stockLinks'] as List<dynamic>? ?? [])
        .map((e) => StockLink.fromMap(e as Map<String, dynamic>))
        .toList(),
  );
}

// =================== ORDER ITEM MODEL ===================
class OrderItem {
  final String productId;
  final String productName;
  int quantity;
  final double unitPrice;
  String? specialComment;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.specialComment,
  });

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId, 'productName': productName,
    'quantity': quantity, 'unitPrice': unitPrice,
    'specialComment': specialComment,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    productId: map['productId'], productName: map['productName'],
    quantity: map['quantity'], unitPrice: (map['unitPrice'] as num).toDouble(),
    specialComment: map['specialComment'],
  );
}

// =================== ORDER MODEL ===================
class Order {
  final String id;
  final int orderNumber;
  String tableNumber;
  String? serverName;
  List<OrderItem> items;
  OrderStatus status;
  String? specialInstructions;
  bool isUrgent;
  DateTime createdAt;
  DateTime? startedAt;
  DateTime? readyAt;
  DateTime? servedAt;
  double discount;
  bool isPaid;
  String? paymentMethod;
  double amountPaid; // Montant versé par le client
  double get change => (amountPaid - totalAmount).clamp(0, double.infinity);

  // ── Cycle de vie caisse (2 étapes) ──────────────────────────────────
  CashStatus cashStatus;          // Statut dans le cycle de caisse
  bool cashoutInvoiceGenerated;   // Facture d'encaissement (provisoire) générée
  bool settlementInvoiceGenerated;// Facture de règlement (définitive) générée

  // Infos encaissement (étape 1 — provisoire)
  String? cashoutInvoiceNumber;
  DateTime? cashoutAt;
  String? cashierId;
  String? cashierName;

  // Infos règlement (étape 2 — définitif)
  String? settlementInvoiceNumber;
  DateTime? settledAt;
  double changeAmount;            // Monnaie rendue

  // Statuts d'impression hérités (rétrocompatibilité)
  bool receiptPrinted;
  bool settlementPrinted;

  // ── Statuts de paiement Firestore (string) ───────────────────────────
  String? paymentStatus;     // 'paid' après règlement définitif
  String? settlementStatus;  // 'completed' après règlement définitif

  // ── Responsable de table (serveur assigné) ──────────────────────────
  String? serverId;
  String? serverEmail;

  // ── Cycle de vie modification / annulation ──────────────────────────
  DateTime? updatedAt;
  DateTime? cancelledAt;
  String? cancelledBy;
  String? cancelReason;

  Order({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    this.serverName,
    required this.items,
    this.status = OrderStatus.pending,
    this.specialInstructions,
    this.isUrgent = false,
    DateTime? createdAt,
    this.startedAt,
    this.readyAt,
    this.servedAt,
    this.discount = 0,
    this.isPaid = false,
    this.paymentMethod,
    this.amountPaid = 0,
    this.cashStatus = CashStatus.pending_cashout,
    this.cashoutInvoiceGenerated = false,
    this.settlementInvoiceGenerated = false,
    this.cashoutInvoiceNumber,
    this.cashoutAt,
    this.cashierId,
    this.cashierName,
    this.settlementInvoiceNumber,
    this.settledAt,
    this.changeAmount = 0,
    this.receiptPrinted = false,
    this.settlementPrinted = false,
    this.serverId,
    this.serverEmail,
    this.updatedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.paymentStatus,
    this.settlementStatus,
  }) : createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalAmount => subtotal - discount;

  int get elapsedMinutes => DateTime.now().difference(createdAt).inMinutes;

  double get estimatedPrepTime {
    if (items.isEmpty) return 0;
    return items.map((i) => i.quantity * 2.0).reduce((a, b) => a > b ? a : b);
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending: return 'En attente';
      case OrderStatus.preparing: return 'En préparation';
      case OrderStatus.ready: return 'Prêt';
      case OrderStatus.served: return 'Servi';
      case OrderStatus.cancelled: return 'Annulé';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending: return const Color(0xFFFFC107);
      case OrderStatus.preparing: return const Color(0xFFFF6B00);
      case OrderStatus.ready: return const Color(0xFF4CAF50);
      case OrderStatus.served: return const Color(0xFF2196F3);
      case OrderStatus.cancelled: return const Color(0xFFF44336);
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'orderNumber': orderNumber, 'tableNumber': tableNumber,
    'serverName': serverName, 'items': items.map((i) => i.toMap()).toList(),
    'status': status.index, 'specialInstructions': specialInstructions,
    'isUrgent': isUrgent, 'createdAt': createdAt.millisecondsSinceEpoch,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'readyAt': readyAt?.millisecondsSinceEpoch,
    'servedAt': servedAt?.millisecondsSinceEpoch,
    'discount': discount, 'isPaid': isPaid, 'paymentMethod': paymentMethod,
    'amountPaid': amountPaid,
    // Cycle caisse 2 étapes
    'cashStatus': cashStatus.index,
    'cashoutInvoiceGenerated': cashoutInvoiceGenerated,
    'settlementInvoiceGenerated': settlementInvoiceGenerated,
    'cashoutInvoiceNumber': cashoutInvoiceNumber,
    'cashoutAt': cashoutAt?.millisecondsSinceEpoch,
    'cashierId': cashierId,
    'cashierName': cashierName,
    'settlementInvoiceNumber': settlementInvoiceNumber,
    'settledAt': settledAt?.millisecondsSinceEpoch,
    'changeAmount': changeAmount,
    // Rétrocompatibilité
    'receiptPrinted': receiptPrinted,
    'settlementPrinted': settlementPrinted,
    // Responsable de table
    'serverId': serverId,
    'serverEmail': serverEmail,
    // Modification / annulation
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    'cancelledBy': cancelledBy,
    'cancelReason': cancelReason,
    'paymentStatus': paymentStatus,
    'settlementStatus': settlementStatus,
  };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'], orderNumber: map['orderNumber'],
    tableNumber: map['tableNumber'], serverName: map['serverName'],
    items: (map['items'] as List).map((i) => OrderItem.fromMap(i)).toList(),
    status: OrderStatus.values[map['status'] ?? 0],
    specialInstructions: map['specialInstructions'],
    isUrgent: map['isUrgent'] ?? false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    startedAt: map['startedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['startedAt']) : null,
    readyAt: map['readyAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['readyAt']) : null,
    servedAt: map['servedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['servedAt']) : null,
    discount: (map['discount'] as num?)?.toDouble() ?? 0,
    isPaid: map['isPaid'] ?? false,
    paymentMethod: map['paymentMethod'],
    amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
    // Cycle caisse 2 étapes
    cashStatus: CashStatus.values[map['cashStatus'] as int? ?? 0],
    cashoutInvoiceGenerated: map['cashoutInvoiceGenerated'] as bool? ?? false,
    settlementInvoiceGenerated: map['settlementInvoiceGenerated'] as bool? ?? false,
    cashoutInvoiceNumber: map['cashoutInvoiceNumber'] as String?,
    cashoutAt: map['cashoutAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['cashoutAt'] as int) : null,
    cashierId: map['cashierId'] as String?,
    cashierName: map['cashierName'] as String?,
    settlementInvoiceNumber: map['settlementInvoiceNumber'] as String?,
    settledAt: map['settledAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['settledAt'] as int) : null,
    changeAmount: (map['changeAmount'] as num?)?.toDouble() ?? 0,
    receiptPrinted: map['receiptPrinted'] as bool? ?? false,
    settlementPrinted: map['settlementPrinted'] as bool? ?? false,
    serverId: map['serverId'] as String?,
    serverEmail: map['serverEmail'] as String?,
    updatedAt: map['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
        : null,
    cancelledAt: map['cancelledAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['cancelledAt'] as int)
        : null,
    cancelledBy: map['cancelledBy'] as String?,
    cancelReason: map['cancelReason'] as String?,
    paymentStatus: map['paymentStatus'] as String?,
    settlementStatus: map['settlementStatus'] as String?,
  );
}

// =================== STOCK MODEL ===================
class StockItem {
  final String id;
  String name;
  String unit;
  double currentQuantity;
  double minQuantity;
  double maxQuantity;
  double unitCost;
  DateTime? expiryDate;
  String category;

  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentQuantity,
    required this.minQuantity,
    required this.maxQuantity,
    required this.unitCost,
    this.expiryDate,
    required this.category,
  });

  bool get isLow => currentQuantity <= minQuantity && currentQuantity > 0;
  bool get isOut => currentQuantity <= 0;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'unit': unit,
    'currentQuantity': currentQuantity, 'minQuantity': minQuantity,
    'maxQuantity': maxQuantity, 'unitCost': unitCost,
    'expiryDate': expiryDate?.millisecondsSinceEpoch,
    'category': category,
  };

  factory StockItem.fromMap(Map<String, dynamic> map) => StockItem(
    id: map['id'], name: map['name'], unit: map['unit'],
    currentQuantity: (map['currentQuantity'] as num).toDouble(),
    minQuantity: (map['minQuantity'] as num).toDouble(),
    maxQuantity: (map['maxQuantity'] as num).toDouble(),
    unitCost: (map['unitCost'] as num).toDouble(),
    expiryDate: map['expiryDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate']) : null,
    category: map['category'],
  );
}

// =================== ATTENDANCE MODEL ===================
class Attendance {
  final String id;
  final String userId;
  final String userName;
  final DateTime date;
  bool morningPresent;
  bool eveningPresent;
  DateTime? morningTime;
  DateTime? eveningTime;
  String? notes;

  Attendance({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    this.morningPresent = false,
    this.eveningPresent = false,
    this.morningTime,
    this.eveningTime,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'userId': userId, 'userName': userName,
    'date': date.millisecondsSinceEpoch,
    'morningPresent': morningPresent, 'eveningPresent': eveningPresent,
    'morningTime': morningTime?.millisecondsSinceEpoch,
    'eveningTime': eveningTime?.millisecondsSinceEpoch,
    'notes': notes,
  };

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
    id: map['id'], userId: map['userId'], userName: map['userName'],
    date: DateTime.fromMillisecondsSinceEpoch(map['date']),
    morningPresent: map['morningPresent'] ?? false,
    eveningPresent: map['eveningPresent'] ?? false,
    morningTime: map['morningTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['morningTime']) : null,
    eveningTime: map['eveningTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['eveningTime']) : null,
    notes: map['notes'],
  );
}

// =================== MESSAGE MODEL ===================
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? receiverId; // null = group
  final String content;
  final MessageType type;
  final String? fileUrl;
  final String? fileName;
  final DateTime sentAt;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    required this.content,
    required this.type,
    this.fileUrl,
    this.fileName,
    DateTime? sentAt,
    this.isRead = false,
  }) : sentAt = sentAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'senderId': senderId, 'senderName': senderName,
    'receiverId': receiverId, 'content': content, 'type': type.index,
    'fileUrl': fileUrl, 'fileName': fileName,
    'sentAt': sentAt.millisecondsSinceEpoch, 'isRead': isRead,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'], senderId: map['senderId'], senderName: map['senderName'],
    receiverId: map['receiverId'], content: map['content'],
    type: MessageType.values[map['type'] ?? 0],
    fileUrl: map['fileUrl'], fileName: map['fileName'],
    sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt']),
    isRead: map['isRead'] ?? false,
  );
}

// =================== SUPPLIER MODEL ===================
class Supplier {
  final String id;
  String name;
  String contact;
  String phone;
  String? email;
  String? address;
  String? productOrService;   // Produit/Service fourni (ex : Poisson, Gaz…)
  bool active;                 // false = soft-deleted
  DateTime? deletedAt;
  String? deletedBy;

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.phone,
    this.email,
    this.address,
    this.productOrService,
    this.active = true,
    this.deletedAt,
    this.deletedBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'contact': contact,
    'phone': phone, 'email': email, 'address': address,
    'productOrService': productOrService,
    'active': active,
    'deletedAt': deletedAt?.millisecondsSinceEpoch,
    'deletedBy': deletedBy,
  };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    contact: map['contact'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    email: map['email'] as String?,
    address: map['address'] as String?,
    productOrService: map['productOrService'] as String?,
    active: map['active'] as bool? ?? true,
    deletedAt: map['deletedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
        : null,
    deletedBy: map['deletedBy'] as String?,
  );
}

// =================== SUPPLIER ORDER MODEL ===================
class SupplierOrder {
  final String id;
  final String supplierId;
  final String supplierName;
  String? productOrService;   // Produit/Service associé à la commande
  List<Map<String, dynamic>> items;
  double totalAmount;
  double paidAmount;
  SupplierPaymentStatus paymentStatus;
  String paymentMethod;
  DateTime orderDate;
  DateTime? deliveryDate;
  DateTime? expectedDelivery;
  DateTime? dueDate;           // Date échéance paiement
  DateTime? createdAt;
  String? createdBy;
  String? notes;

  SupplierOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    this.productOrService,
    required this.items,
    required this.totalAmount,
    this.paidAmount = 0,
    this.paymentStatus = SupplierPaymentStatus.unpaid,
    this.paymentMethod = 'Espèces',
    DateTime? orderDate,
    this.deliveryDate,
    this.expectedDelivery,
    this.dueDate,
    this.createdAt,
    this.createdBy,
    this.notes,
  }) : orderDate = orderDate ?? DateTime.now();

  double get remainingAmount => (totalAmount - paidAmount).clamp(0, double.infinity);
  bool get isFullyPaid => paidAmount >= totalAmount;

  /// Commande en retard : non soldée ET date échéance dépassée
  bool get isOverdue {
    if (isFullyPaid) return false;
    final deadline = dueDate ?? expectedDelivery;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'supplierId': supplierId, 'supplierName': supplierName,
    'productOrService': productOrService,
    'items': items, 'totalAmount': totalAmount, 'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'paymentStatus': paymentStatus.name,  // Stocke le nom string (unpaid/partial/paid)
    'paymentMethod': paymentMethod,
    'orderDate': orderDate.millisecondsSinceEpoch,
    'deliveryDate': deliveryDate?.millisecondsSinceEpoch,
    'expectedDelivery': expectedDelivery?.millisecondsSinceEpoch,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'createdAt': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    'createdBy': createdBy,
    'notes': notes,
  };

  factory SupplierOrder.fromMap(Map<String, dynamic> map) {
    // Compatibilité : paymentStatus peut être un int (ancien) ou un string (nouveau)
    SupplierPaymentStatus parseStatus(dynamic raw) {
      if (raw == null) return SupplierPaymentStatus.unpaid;
      if (raw is String) {
        // Ancien 'pending' → unpaid
        if (raw == 'pending') return SupplierPaymentStatus.unpaid;
        return SupplierPaymentStatus.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => SupplierPaymentStatus.unpaid,
        );
      }
      if (raw is int) {
        // 0=unpaid(ancien pending), 1=partial, 2=paid
        if (raw < SupplierPaymentStatus.values.length) return SupplierPaymentStatus.values[raw];
      }
      return SupplierPaymentStatus.unpaid;
    }

    return SupplierOrder(
      id: map['id'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      productOrService: map['productOrService'] as String?,
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      paymentStatus: parseStatus(map['paymentStatus']),
      paymentMethod: map['paymentMethod'] as String? ?? 'Espèces',
      orderDate: map['orderDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['orderDate'] as int)
          : DateTime.now(),
      deliveryDate: map['deliveryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deliveryDate'] as int)
          : null,
      expectedDelivery: map['expectedDelivery'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expectedDelivery'] as int)
          : null,
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      createdBy: map['createdBy'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

// =================== SUPPLIER PAYMENT MODEL ===================
class SupplierPayment {
  final String id;
  final String supplierOrderId;
  final String supplierId;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;
  final String createdBy;

  SupplierPayment({
    required this.id,
    required this.supplierOrderId,
    required this.supplierId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.note,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplierOrderId': supplierOrderId,
    'supplierId': supplierId,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'paymentDate': paymentDate.millisecondsSinceEpoch,
    'note': note,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'createdBy': createdBy,
  };

  factory SupplierPayment.fromMap(Map<String, dynamic> map) => SupplierPayment(
    id: map['id'] as String? ?? '',
    supplierOrderId: map['supplierOrderId'] as String? ?? '',
    supplierId: map['supplierId'] as String? ?? '',
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    paymentMethod: map['paymentMethod'] as String? ?? 'Espèces',
    paymentDate: map['paymentDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['paymentDate'] as int)
        : DateTime.now(),
    note: map['note'] as String?,
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
    createdBy: map['createdBy'] as String? ?? '',
  );
}

// =================== CALL MODELS ===================
/// Statuts possibles d'un appel
enum CallStatus { calling, ringing, accepted, rejected, ended, missed }

/// Session d'appel (1-to-1 ou conférence)
class CallSession {
  final String id;
  final String callerId;
  final String callerName;
  final String? calleeId;       // null si conférence
  final String? calleeName;
  final bool isConference;
  CallStatus status;
  final DateTime createdAt;
  DateTime? answeredAt;
  DateTime? endedAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.calleeId,
    this.calleeName,
    this.isConference = false,
    this.status = CallStatus.calling,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'callerId': callerId,
    'callerName': callerName,
    'calleeId': calleeId,
    'calleeName': calleeName,
    'isConference': isConference,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'answeredAt': answeredAt?.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
  };

  factory CallSession.fromMap(Map<String, dynamic> map) => CallSession(
    id: map['id'] as String? ?? '',
    callerId: map['callerId'] as String? ?? '',
    callerName: map['callerName'] as String? ?? '',
    calleeId: map['calleeId'] as String?,
    calleeName: map['calleeName'] as String?,
    isConference: map['isConference'] as bool? ?? false,
    status: CallStatus.values.firstWhere(
      (s) => s.name == (map['status'] as String? ?? 'calling'),
      orElse: () => CallStatus.calling,
    ),
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
    answeredAt: map['answeredAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['answeredAt'] as int)
        : null,
    endedAt: map['endedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int)
        : null,
  );
}

/// Participant à un appel (conférence ou 1-to-1)
class CallParticipant {
  final String id;
  final String callId;
  final String userId;
  final String userName;
  bool isMuted;
  bool isConnected;
  final DateTime joinedAt;

  CallParticipant({
    required this.id,
    required this.callId,
    required this.userId,
    required this.userName,
    this.isMuted = false,
    this.isConnected = true,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'callId': callId,
    'userId': userId,
    'userName': userName,
    'isMuted': isMuted,
    'isConnected': isConnected,
    'joinedAt': joinedAt.millisecondsSinceEpoch,
  };

  factory CallParticipant.fromMap(Map<String, dynamic> map) => CallParticipant(
    id: map['id'] as String? ?? '',
    callId: map['callId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    userName: map['userName'] as String? ?? '',
    isMuted: map['isMuted'] as bool? ?? false,
    isConnected: map['isConnected'] as bool? ?? true,
    joinedAt: map['joinedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
        : DateTime.now(),
  );
}
