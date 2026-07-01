import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ── Helper : convertit Timestamp Firestore, int (ms) ou null → DateTime? ──
DateTime? _parseDTNullable(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// =================== ENUMS ===================
enum OrderStatus { pending, preparing, ready, served, cancelled }
// Statut de caisse : distinct de OrderStatus (cycle de vie paiement)
// pending_cashout  → prêt à encaisser (commande ready/served non payée)
// awaiting_payment → facture d'encaissement générée, en attente de règlement
// paid             → règlement définitif effectué
enum CashStatus { pending_cashout, awaiting_payment, paid }
enum UserRole { admin, manager, cashier, kitchen, server, stockManager, client }
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
      case UserRole.client: return 'Client';
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
      case UserRole.client: return const Color(0xFFE91E63);
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

  /// Calcule le stock effectif depuis les liaisons StockItem.
  ///
  /// Règle : pour chaque lien obligatoire (mandatory=true), le stock disponible
  /// est floor(stockItem.currentQuantity / link.quantityUsed).
  /// On retourne le minimum parmi tous les liens obligatoires.
  /// Si aucun lien obligatoire n'est défini, on retourne [stockQuantity].
  ///
  /// [stockItems] : liste courante des StockItem (depuis le provider).
  int computedStock(List<StockItem> stockItems) {
    final mandatoryLinks = stockLinks.where((l) => l.mandatory).toList();
    if (mandatoryLinks.isEmpty) return stockQuantity;

    int min = 999999;
    for (final link in mandatoryLinks) {
      if (link.quantityUsed <= 0) continue;
      final si = stockItems.firstWhere(
        (s) => s.id == link.stockItemId,
        orElse: () => StockItem(
          id: '', name: '', unit: '',
          currentQuantity: 0, minQuantity: 0, maxQuantity: 0,
          unitCost: 0, category: '',
        ),
      );
      final portions = (si.currentQuantity / link.quantityUsed).floor();
      if (portions < min) min = portions;
    }
    return min == 999999 ? stockQuantity : min;
  }

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
  /// true si cet article provient de la Cambuse (boisson)
  final bool isCambuse;
  /// id Cambuse pour déduction directe (sans liaison productId)
  final String? cambuseItemId;
  /// catégorie d'affichage (plat ou catégorie cambuse)
  final String? category;
  /// Type d'article : "menu" (plat cuisine) ou "cambuse" (boisson)
  /// Utilisé pour séparer le flux cuisine du flux caisse
  final String itemType;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.specialComment,
    this.isCambuse = false,
    this.cambuseItemId,
    this.category,
    String? itemType,
  }) : itemType = itemType ?? (isCambuse ? 'cambuse' : 'menu');

  /// true si cet article doit passer en cuisine
  /// FIX : basé UNIQUEMENT sur itemType (source de vérité).
  /// isCambuse est un champ legacy POS — pour les commandes online,
  /// seul itemType=='menu' fait foi. Ne pas combiner les deux.
  bool get isKitchenItem => itemType == 'menu';

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId':    productId,
    'productName':  productName,
    'quantity':     quantity,
    'unitPrice':    unitPrice,
    'specialComment': specialComment,
    'isCambuse':    isCambuse,
    'cambuseItemId': cambuseItemId,
    'category':     category,
    'itemType':     itemType,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    // Rétrocompatibilité : si itemType absent, dériver de isCambuse
    final isCamb = map['isCambuse'] as bool? ?? false;
    final type   = map['itemType'] as String? ?? (isCamb ? 'cambuse' : 'menu');
    return OrderItem(
      productId:     map['productId']    as String? ?? '',
      productName:   map['productName']  as String? ?? '',
      quantity:      (map['quantity']    as num?)?.toInt() ?? 0,
      unitPrice:     (map['unitPrice']   as num?)?.toDouble() ?? 0,
      specialComment: map['specialComment'] as String?,
      isCambuse:     isCamb,
      cambuseItemId: map['cambuseItemId'] as String?,
      category:      map['category']     as String?,
      itemType:      type,
    );
  }
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

  // ── Type de commande (sur place / à emporter / livraison) ─────────────
  String orderType;          // 'dine_in' | 'takeaway' | 'delivery'
  bool get isTakeaway => orderType == 'takeaway';
  bool get isDelivery => orderType == 'delivery' || (!isTakeaway && isOnlineOrder);

  // ── Source commande (pos / online) ──────────────────────────────────
  String source;             // 'pos' | 'online'
  bool get isOnlineOrder => source == 'online';
  String? clientId;          // UID client (si commande en ligne)
  String? clientPhone;       // Téléphone client (si commande en ligne)

  // ── Workflow cuisine pour commandes en ligne ─────────────────────────
  bool sentToKitchen;        // true = commande confirmée et envoyée en cuisine
  String? kitchenStatus;     // 'waiting' | 'preparing' | 'ready' | 'served' | 'cancelled'
  String? adminStatus;       // 'received' | 'confirmed' | 'cancelled'
  String? clientName;        // Nom client (commandes en ligne)
  DateTime? sentToKitchenAt; // Horodatage envoi en cuisine
  String? clientOrderId;     // ID du doc client_orders lié (pour sync retour)

  // ── Cycle de vie modification / annulation ──────────────────────────
  DateTime? updatedAt;
  DateTime? cancelledAt;
  String? cancelledBy;         // Nom affiché (rétrocompatibilité)
  String? cancelReason;
  String? cancelledByName;     // Nom complet de l'annuleur
  String? cancelledByRole;     // Rôle (admin, manager, server…)
  String? cancelledByUserId;   // UID Firestore de l'annuleur

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
    this.cancelledByName,
    this.cancelledByRole,
    this.cancelledByUserId,
    this.paymentStatus,
    this.settlementStatus,
    this.orderType = 'dine_in',
    this.source = 'pos',
    this.clientId,
    this.clientPhone,
    this.sentToKitchen = false,
    this.kitchenStatus,
    this.adminStatus,
    this.clientName,
    this.sentToKitchenAt,
    this.clientOrderId,
  }) : createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalAmount => subtotal - discount;

  /// true si la commande contient au moins un plat à envoyer en cuisine
  bool get hasKitchenItems => items.any((i) => i.isKitchenItem);

  /// true si la commande contient uniquement des boissons Cambuse (aucun plat)
  bool get isCambuseOnly => items.isNotEmpty && !hasKitchenItems;

  /// Libellé de table affiché partout (cuisine, caisse, facture)
  String get tableLabel => isTakeaway ? 'À emporter' : 'Table $tableNumber';

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
    'cancelledByName': cancelledByName,
    'cancelledByRole': cancelledByRole,
    'cancelledByUserId': cancelledByUserId,
    'paymentStatus': paymentStatus,
    'settlementStatus': settlementStatus,
    'orderType': orderType,
    'source': source,
    'clientId': clientId,
    'clientPhone': clientPhone,
    'sentToKitchen': sentToKitchen,
    if (kitchenStatus != null) 'kitchenStatus': kitchenStatus,
    if (adminStatus != null) 'adminStatus': adminStatus,
    if (clientName != null) 'clientName': clientName,
    if (sentToKitchenAt != null) 'sentToKitchenAt': sentToKitchenAt!.millisecondsSinceEpoch,
    if (clientOrderId != null) 'clientOrderId': clientOrderId,
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
    cancelledByName: map['cancelledByName'] as String?,
    cancelledByRole: map['cancelledByRole'] as String?,
    cancelledByUserId: map['cancelledByUserId'] as String?,
    paymentStatus: map['paymentStatus'] as String?,
    settlementStatus: map['settlementStatus'] as String?,
    orderType: map['orderType'] as String? ?? 'dine_in',
    source: map['source'] as String? ?? 'pos',
    clientId: map['clientId'] as String?,
    clientPhone: map['clientPhone'] as String?,
    sentToKitchen: map['sentToKitchen'] as bool? ?? false,
    kitchenStatus: map['kitchenStatus'] as String?,
    adminStatus: map['adminStatus'] as String?,
    clientName: map['clientName'] as String?,
    sentToKitchenAt: _parseDTNullable(map['sentToKitchenAt']),
    clientOrderId: map['clientOrderId'] as String?,
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
  bool active;               // false = soft-deleted
  DateTime? deletedAt;
  String? deletedBy;

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
    this.active = true,
    this.deletedAt,
    this.deletedBy,
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
    'active': active,
    'deletedAt': deletedAt?.millisecondsSinceEpoch,
    'deletedBy': deletedBy,
  };

  factory StockItem.fromMap(Map<String, dynamic> map) => StockItem(
    id: map['id'], name: map['name'], unit: map['unit'],
    currentQuantity: (map['currentQuantity'] as num).toDouble(),
    minQuantity: (map['minQuantity'] as num).toDouble(),
    maxQuantity: (map['maxQuantity'] as num).toDouble(),
    unitCost: (map['unitCost'] as num).toDouble(),
    expiryDate: map['expiryDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate']) : null,
    category: map['category'],
    active: map['active'] as bool? ?? true,
    deletedAt: map['deletedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
        : null,
    deletedBy: map['deletedBy'] as String?,
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

// =================== INVENTORY MODELS ===================

enum InventoryStatus { inProgress, completed, cancelled }

extension InventoryStatusX on InventoryStatus {
  String get label {
    switch (this) {
      case InventoryStatus.inProgress:  return 'En cours';
      case InventoryStatus.completed:   return 'Terminé';
      case InventoryStatus.cancelled:   return 'Annulé';
    }
  }
  String get key {
    switch (this) {
      case InventoryStatus.inProgress:  return 'in_progress';
      case InventoryStatus.completed:   return 'completed';
      case InventoryStatus.cancelled:   return 'cancelled';
    }
  }
  static InventoryStatus fromKey(String k) {
    switch (k) {
      case 'completed':   return InventoryStatus.completed;
      case 'cancelled':   return InventoryStatus.cancelled;
      default:            return InventoryStatus.inProgress;
    }
  }
}

/// Statut d'un article d'inventaire
enum InventoryItemStatus { notCounted, compliant, missing, surplus }

extension InventoryItemStatusX on InventoryItemStatus {
  String get label {
    switch (this) {
      case InventoryItemStatus.notCounted: return 'Non compté';
      case InventoryItemStatus.compliant:  return 'Conforme';
      case InventoryItemStatus.missing:    return 'Manquant';
      case InventoryItemStatus.surplus:    return 'Surplus';
    }
  }
  static InventoryItemStatus compute(double? counted, double theoretical) {
    if (counted == null) return InventoryItemStatus.notCounted;
    final diff = counted - theoretical;
    if (diff.abs() < 0.001) return InventoryItemStatus.compliant;
    return diff < 0 ? InventoryItemStatus.missing : InventoryItemStatus.surplus;
  }
}

/// Session d'inventaire (collection Firestore : inventory_sessions)
class InventorySession {
  final String id;
  final DateTime date;
  final String responsibleId;
  final String responsibleName;
  final String site;
  InventoryStatus status;
  final int totalProducts;
  final int totalCounted;
  final int totalMissing;
  final int totalSurplus;
  final DateTime? completedAt;

  InventorySession({
    required this.id,
    required this.date,
    required this.responsibleId,
    required this.responsibleName,
    required this.site,
    this.status = InventoryStatus.inProgress,
    this.totalProducts = 0,
    this.totalCounted = 0,
    this.totalMissing = 0,
    this.totalSurplus = 0,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'responsibleId': responsibleId,
    'responsibleName': responsibleName,
    'site': site,
    'status': status.key,
    'totalProducts': totalProducts,
    'totalCounted': totalCounted,
    'totalMissing': totalMissing,
    'totalSurplus': totalSurplus,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  factory InventorySession.fromMap(Map<String, dynamic> m, String docId) =>
      InventorySession(
        id: docId,
        date: m['date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['date'] as int)
            : DateTime.now(),
        responsibleId:   m['responsibleId']   as String? ?? '',
        responsibleName: m['responsibleName'] as String? ?? '',
        site:            m['site']            as String? ?? '',
        status: InventoryStatusX.fromKey(m['status'] as String? ?? ''),
        totalProducts: (m['totalProducts'] as num?)?.toInt() ?? 0,
        totalCounted:  (m['totalCounted']  as num?)?.toInt() ?? 0,
        totalMissing:  (m['totalMissing']  as num?)?.toInt() ?? 0,
        totalSurplus:  (m['totalSurplus']  as num?)?.toInt() ?? 0,
        completedAt: m['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['completedAt'] as int)
            : null,
      );
}

/// Article d'inventaire (collection Firestore : inventory_items)
class InventoryItem {
  final String id;
  final String sessionId;
  final String stockItemId;
  final String stockItemName;
  final String category;
  final String unit;
  final double theoreticalQty;
  double? countedQty;         // null = pas encore compté
  String comment;
  final double unitCost;

  InventoryItem({
    required this.id,
    required this.sessionId,
    required this.stockItemId,
    required this.stockItemName,
    required this.category,
    required this.unit,
    required this.theoreticalQty,
    this.countedQty,
    this.comment = '',
    this.unitCost = 0,
  });

  double get gap => countedQty != null ? countedQty! - theoreticalQty : 0;
  double get gapValue => gap * unitCost;

  InventoryItemStatus get status =>
      InventoryItemStatusX.compute(countedQty, theoreticalQty);

  Map<String, dynamic> toMap() => {
    'id': id,
    'sessionId': sessionId,
    'stockItemId': stockItemId,
    'stockItemName': stockItemName,
    'category': category,
    'unit': unit,
    'theoreticalQty': theoreticalQty,
    'countedQty': countedQty,
    'comment': comment,
    'unitCost': unitCost,
  };

  factory InventoryItem.fromMap(Map<String, dynamic> m, String docId) =>
      InventoryItem(
        id:             docId,
        sessionId:      m['sessionId']      as String? ?? '',
        stockItemId:    m['stockItemId']    as String? ?? '',
        stockItemName:  m['stockItemName']  as String? ?? '',
        category:       m['category']       as String? ?? '',
        unit:           m['unit']           as String? ?? '',
        theoreticalQty: (m['theoreticalQty'] as num?)?.toDouble() ?? 0,
        countedQty:     (m['countedQty']     as num?)?.toDouble(),
        comment:        m['comment']        as String? ?? '',
        unitCost:       (m['unitCost']       as num?)?.toDouble() ?? 0,
      );
}

// =================== CONTRACT MODELS ===================

enum ContractType { stage, cdd, cdi, essai, journalier }

extension ContractTypeX on ContractType {
  String get label {
    switch (this) {
      case ContractType.stage:      return 'Stage';
      case ContractType.cdd:        return 'CDD';
      case ContractType.cdi:        return 'CDI';
      case ContractType.essai:      return 'Période d\'essai';
      case ContractType.journalier: return 'Journalier';
    }
  }
  static ContractType fromString(String s) {
    switch (s) {
      case 'stage':      return ContractType.stage;
      case 'cdd':        return ContractType.cdd;
      case 'cdi':        return ContractType.cdi;
      case 'essai':      return ContractType.essai;
      case 'journalier': return ContractType.journalier;
      default:           return ContractType.cdd;
    }
  }
}

enum ContractStatus { actif, bientotExpire, expire, renouvele, nonRenouvele }

extension ContractStatusX on ContractStatus {
  String get label {
    switch (this) {
      case ContractStatus.actif:          return 'Actif';
      case ContractStatus.bientotExpire:  return 'Bientôt expiré';
      case ContractStatus.expire:         return 'Expiré';
      case ContractStatus.renouvele:      return 'Renouvelé';
      case ContractStatus.nonRenouvele:   return 'Non renouvelé';
    }
  }
  Color get color {
    switch (this) {
      case ContractStatus.actif:          return const Color(0xFF4CAF50);
      case ContractStatus.bientotExpire:  return const Color(0xFFFF9800);
      case ContractStatus.expire:         return const Color(0xFFF44336);
      case ContractStatus.renouvele:      return const Color(0xFF2196F3);
      case ContractStatus.nonRenouvele:   return const Color(0xFF9E9E9E);
    }
  }
  static ContractStatus fromString(String s) {
    switch (s) {
      case 'actif':          return ContractStatus.actif;
      case 'bientotExpire':  return ContractStatus.bientotExpire;
      case 'expire':         return ContractStatus.expire;
      case 'renouvele':      return ContractStatus.renouvele;
      case 'nonRenouvele':   return ContractStatus.nonRenouvele;
      default:               return ContractStatus.actif;
    }
  }
}

class EmployeeContract {
  final String id;
  final String employeeId;
  final String employeeName;
  ContractType type;
  DateTime startDate;
  DateTime? endDate;
  double salary;
  String poste;
  String site;
  ContractStatus status;
  String comment;
  DateTime createdAt;
  String createdBy;

  EmployeeContract({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.startDate,
    this.endDate,
    required this.salary,
    required this.poste,
    required this.site,
    this.status = ContractStatus.actif,
    this.comment = '',
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calcule automatiquement le statut selon la date de fin
  ContractStatus get computedStatus {
    if (status == ContractStatus.renouvele || status == ContractStatus.nonRenouvele) {
      return status;
    }
    if (endDate == null) return ContractStatus.actif; // CDI sans fin
    final now = DateTime.now();
    final diff = endDate!.difference(now).inDays;
    if (diff < 0)  return ContractStatus.expire;
    if (diff <= 30) return ContractStatus.bientotExpire;
    return ContractStatus.actif;
  }

  /// Jours restants avant expiration (null si pas de date de fin)
  int? get daysLeft => endDate == null ? null : endDate!.difference(DateTime.now()).inDays;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'type': type.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'salary': salary,
    'poste': poste,
    'site': site,
    'status': status.name,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory EmployeeContract.fromMap(Map<String, dynamic> m, String docId) =>
      EmployeeContract(
        id:           docId,
        employeeId:   m['employeeId']   as String? ?? '',
        employeeName: m['employeeName'] as String? ?? '',
        type:         ContractTypeX.fromString(m['type'] as String? ?? 'cdd'),
        startDate:    DateTime.tryParse(m['startDate'] as String? ?? '') ?? DateTime.now(),
        endDate:      m['endDate'] != null ? DateTime.tryParse(m['endDate'] as String) : null,
        salary:       (m['salary'] as num?)?.toDouble() ?? 0,
        poste:        m['poste']   as String? ?? '',
        site:         m['site']    as String? ?? '',
        status:       ContractStatusX.fromString(m['status'] as String? ?? 'actif'),
        comment:      m['comment'] as String? ?? '',
        createdAt:    DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        createdBy:    m['createdBy'] as String? ?? '',
      );
}

class ContractHistory {
  final String id;
  final String contractId;
  final String employeeId;
  final String employeeName;
  final String action;       // 'renewed', 'not_renewed', 'modified', 'created'
  final String oldData;      // JSON snapshot
  final String newData;      // JSON snapshot
  final String decision;
  final String responsable;
  final DateTime date;

  ContractHistory({
    required this.id,
    required this.contractId,
    required this.employeeId,
    required this.employeeName,
    required this.action,
    this.oldData = '',
    this.newData = '',
    this.decision = '',
    required this.responsable,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'contractId': contractId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'action': action,
    'oldData': oldData,
    'newData': newData,
    'decision': decision,
    'responsable': responsable,
    'date': date.toIso8601String(),
  };

  factory ContractHistory.fromMap(Map<String, dynamic> m, String docId) =>
      ContractHistory(
        id:           docId,
        contractId:   m['contractId']   as String? ?? '',
        employeeId:   m['employeeId']   as String? ?? '',
        employeeName: m['employeeName'] as String? ?? '',
        action:       m['action']       as String? ?? '',
        oldData:      m['oldData']      as String? ?? '',
        newData:      m['newData']      as String? ?? '',
        decision:     m['decision']     as String? ?? '',
        responsable:  m['responsable']  as String? ?? '',
        date:         DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      );
}

class ContractAlert {
  final String id;
  final String contractId;
  final String employeeId;
  final String employeeName;
  final int daysLeft;
  final bool isRead;
  final DateTime createdAt;

  ContractAlert({
    required this.id,
    required this.contractId,
    required this.employeeId,
    required this.employeeName,
    required this.daysLeft,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get message {
    if (daysLeft < 0) return 'Le contrat de $employeeName a expiré.';
    if (daysLeft == 0) return 'Le contrat de $employeeName expire aujourd\'hui !';
    return 'Le contrat de $employeeName expire dans $daysLeft jour${daysLeft > 1 ? 's' : ''}.';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'contractId': contractId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'daysLeft': daysLeft,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ContractAlert.fromMap(Map<String, dynamic> m, String docId) =>
      ContractAlert(
        id:           docId,
        contractId:   m['contractId']   as String? ?? '',
        employeeId:   m['employeeId']   as String? ?? '',
        employeeName: m['employeeName'] as String? ?? '',
        daysLeft:     (m['daysLeft']    as num?)?.toInt() ?? 0,
        isRead:       m['isRead']       as bool? ?? false,
        createdAt:    DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  GESTION SALAIRES
// ══════════════════════════════════════════════════════════════════════════════

// ── Statut de paiement ────────────────────────────────────────────────────────
enum PaymentStatus { nonPaye, partiel, paye }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.nonPaye:  return 'Non payé';
      case PaymentStatus.partiel:  return 'Partiel';
      case PaymentStatus.paye:     return 'Payé';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.nonPaye:  return const Color(0xFFB71C1C);
      case PaymentStatus.partiel:  return const Color(0xFFE65100);
      case PaymentStatus.paye:     return const Color(0xFF2E7D32);
    }
  }

  static PaymentStatus fromString(String s) {
    switch (s) {
      case 'partiel': return PaymentStatus.partiel;
      case 'paye':    return PaymentStatus.paye;
      default:        return PaymentStatus.nonPaye;
    }
  }
}

// ── Mode de paiement ─────────────────────────────────────────────────────────
enum PaymentMode { especes, mobile, virement, cheque }

extension PaymentModeX on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.especes:  return 'Espèces';
      case PaymentMode.mobile:   return 'Mobile Money';
      case PaymentMode.virement: return 'Virement';
      case PaymentMode.cheque:   return 'Chèque';
    }
  }

  static PaymentMode fromString(String s) {
    switch (s) {
      case 'mobile':   return PaymentMode.mobile;
      case 'virement': return PaymentMode.virement;
      case 'cheque':   return PaymentMode.cheque;
      default:         return PaymentMode.especes;
    }
  }
}

// ── Fiche de salaire mensuelle ────────────────────────────────────────────────
class EmployeeSalary {
  final String id;
  final String employeeId;
  final String employeeName;
  final String poste;
  final String matricule;
  // Période (ex: "Juin 2025")
  final String periode;
  final int annee;
  final int mois;
  // Éléments de salaire
  double salaryBase;
  double heuresSup;       // Montant heures supplémentaires
  double primes;
  double indemnites;
  // Retenues
  double cnps;
  double its;
  double autresRetenues;
  double avances;
  // Paiement
  PaymentStatus paymentStatus;
  double montantPaye;
  DateTime? datePaiement;
  PaymentMode modePaiement;
  String commentaire;
  DateTime createdAt;
  String createdBy;

  EmployeeSalary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.poste,
    this.matricule = '',
    required this.periode,
    required this.annee,
    required this.mois,
    required this.salaryBase,
    this.heuresSup = 0,
    this.primes = 0,
    this.indemnites = 0,
    this.cnps = 0,
    this.its = 0,
    this.autresRetenues = 0,
    this.avances = 0,
    this.paymentStatus = PaymentStatus.nonPaye,
    this.montantPaye = 0,
    this.datePaiement,
    this.modePaiement = PaymentMode.especes,
    this.commentaire = '',
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Calculs ─────────────────────────────────────────────────────────────────
  double get brut => salaryBase + heuresSup + primes + indemnites;
  double get totalRetenues => cnps + its + autresRetenues + avances;
  double get netAPayer => brut - totalRetenues;
  double get resteAPayer => netAPayer - montantPaye;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'poste': poste,
    'matricule': matricule,
    'periode': periode,
    'annee': annee,
    'mois': mois,
    'salaryBase': salaryBase,
    'heuresSup': heuresSup,
    'primes': primes,
    'indemnites': indemnites,
    'cnps': cnps,
    'its': its,
    'autresRetenues': autresRetenues,
    'avances': avances,
    'paymentStatus': paymentStatus.name,
    'montantPaye': montantPaye,
    'datePaiement': datePaiement?.toIso8601String(),
    'modePaiement': modePaiement.name,
    'commentaire': commentaire,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory EmployeeSalary.fromMap(Map<String, dynamic> m, String docId) =>
      EmployeeSalary(
        id:            docId,
        employeeId:    m['employeeId']    as String? ?? '',
        employeeName:  m['employeeName']  as String? ?? '',
        poste:         m['poste']         as String? ?? '',
        matricule:     m['matricule']     as String? ?? '',
        periode:       m['periode']       as String? ?? '',
        annee:         (m['annee']        as num?)?.toInt() ?? DateTime.now().year,
        mois:          (m['mois']         as num?)?.toInt() ?? DateTime.now().month,
        salaryBase:    (m['salaryBase']   as num?)?.toDouble() ?? 0,
        heuresSup:     (m['heuresSup']    as num?)?.toDouble() ?? 0,
        primes:        (m['primes']       as num?)?.toDouble() ?? 0,
        indemnites:    (m['indemnites']   as num?)?.toDouble() ?? 0,
        cnps:          (m['cnps']         as num?)?.toDouble() ?? 0,
        its:           (m['its']          as num?)?.toDouble() ?? 0,
        autresRetenues:(m['autresRetenues'] as num?)?.toDouble() ?? 0,
        avances:       (m['avances']      as num?)?.toDouble() ?? 0,
        paymentStatus: PaymentStatusX.fromString(m['paymentStatus'] as String? ?? 'nonPaye'),
        montantPaye:   (m['montantPaye']  as num?)?.toDouble() ?? 0,
        datePaiement:  m['datePaiement'] != null
            ? DateTime.tryParse(m['datePaiement'] as String)
            : null,
        modePaiement:  PaymentModeX.fromString(m['modePaiement'] as String? ?? 'especes'),
        commentaire:   m['commentaire']   as String? ?? '',
        createdAt:     DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        createdBy:     m['createdBy']     as String? ?? '',
      );
}

// ── Paiement salaire (historique) ─────────────────────────────────────────────
class SalaryPayment {
  final String id;
  final String salaryId;
  final String employeeId;
  final String employeeName;
  final String periode;
  final double montant;
  final PaymentMode mode;
  final DateTime date;
  final String responsable;
  final String note;

  SalaryPayment({
    required this.id,
    required this.salaryId,
    required this.employeeId,
    required this.employeeName,
    required this.periode,
    required this.montant,
    required this.mode,
    required this.date,
    this.responsable = '',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'salaryId': salaryId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'periode': periode,
    'montant': montant,
    'mode': mode.name,
    'date': date.toIso8601String(),
    'responsable': responsable,
    'note': note,
  };

  factory SalaryPayment.fromMap(Map<String, dynamic> m, String docId) =>
      SalaryPayment(
        id:           docId,
        salaryId:     m['salaryId']     as String? ?? '',
        employeeId:   m['employeeId']   as String? ?? '',
        employeeName: m['employeeName'] as String? ?? '',
        periode:      m['periode']      as String? ?? '',
        montant:      (m['montant']     as num?)?.toDouble() ?? 0,
        mode:         PaymentModeX.fromString(m['mode'] as String? ?? 'especes'),
        date:         DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        responsable:  m['responsable']  as String? ?? '',
        note:         m['note']         as String? ?? '',
      );
}

// ── Rapport de paie mensuel ───────────────────────────────────────────────────
class PayrollReport {
  final String id;
  final String periode;
  final int annee;
  final int mois;
  final int totalEmployes;
  final double totalBrut;
  final double totalPrimes;
  final double totalRetenues;
  final double totalNet;
  final double totalPaye;
  final DateTime generatedAt;

  PayrollReport({
    required this.id,
    required this.periode,
    required this.annee,
    required this.mois,
    required this.totalEmployes,
    required this.totalBrut,
    required this.totalPrimes,
    required this.totalRetenues,
    required this.totalNet,
    required this.totalPaye,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  double get resteAPayer => totalNet - totalPaye;

  Map<String, dynamic> toMap() => {
    'id': id,
    'periode': periode,
    'annee': annee,
    'mois': mois,
    'totalEmployes': totalEmployes,
    'totalBrut': totalBrut,
    'totalPrimes': totalPrimes,
    'totalRetenues': totalRetenues,
    'totalNet': totalNet,
    'totalPaye': totalPaye,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory PayrollReport.fromMap(Map<String, dynamic> m, String docId) =>
      PayrollReport(
        id:            docId,
        periode:       m['periode']       as String? ?? '',
        annee:         (m['annee']        as num?)?.toInt() ?? DateTime.now().year,
        mois:          (m['mois']         as num?)?.toInt() ?? DateTime.now().month,
        totalEmployes: (m['totalEmployes'] as num?)?.toInt() ?? 0,
        totalBrut:     (m['totalBrut']    as num?)?.toDouble() ?? 0,
        totalPrimes:   (m['totalPrimes']  as num?)?.toDouble() ?? 0,
        totalRetenues: (m['totalRetenues'] as num?)?.toDouble() ?? 0,
        totalNet:      (m['totalNet']     as num?)?.toDouble() ?? 0,
        totalPaye:     (m['totalPaye']    as num?)?.toDouble() ?? 0,
        generatedAt:   DateTime.tryParse(m['generatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE RÉSERVATIONS & ÉVÉNEMENTS
// ════════════════════════════════════════════════════════════════════════════

// ── Enum type d'événement ─────────────────────────────────────────────────
enum EventType {
  anniversaire, mariage, bapteme, reunion, soutenance,
  formation, dejeunerEntreprise, dinerEntreprise, reservationSimple, autre
}

extension EventTypeX on EventType {
  String get label {
    switch (this) {
      case EventType.anniversaire:       return 'Anniversaire';
      case EventType.mariage:            return 'Mariage';
      case EventType.bapteme:            return 'Baptême';
      case EventType.reunion:            return 'Réunion';
      case EventType.soutenance:         return 'Soutenance';
      case EventType.formation:          return 'Formation';
      case EventType.dejeunerEntreprise: return 'Déjeuner entreprise';
      case EventType.dinerEntreprise:    return 'Dîner entreprise';
      case EventType.reservationSimple:  return 'Réservation simple';
      case EventType.autre:              return 'Autre';
    }
  }

  String get emoji {
    switch (this) {
      case EventType.anniversaire:       return '🎂';
      case EventType.mariage:            return '💍';
      case EventType.bapteme:            return '👶';
      case EventType.reunion:            return '🤝';
      case EventType.soutenance:         return '🎓';
      case EventType.formation:          return '📚';
      case EventType.dejeunerEntreprise: return '🍽️';
      case EventType.dinerEntreprise:    return '🌙';
      case EventType.reservationSimple:  return '📅';
      case EventType.autre:              return '⭐';
    }
  }

  static EventType fromString(String s) {
    return EventType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EventType.autre,
    );
  }
}

// ── Enum statut réservation ───────────────────────────────────────────────
enum ReservationStatus { enAttente, confirme, annule, termine }

extension ReservationStatusX on ReservationStatus {
  String get label {
    switch (this) {
      case ReservationStatus.enAttente: return 'En attente';
      case ReservationStatus.confirme:  return 'Confirmée';
      case ReservationStatus.annule:    return 'Annulée';
      case ReservationStatus.termine:   return 'Terminée';
    }
  }

  Color get color {
    switch (this) {
      case ReservationStatus.enAttente: return const Color(0xFFFFC107);
      case ReservationStatus.confirme:  return const Color(0xFF2196F3);
      case ReservationStatus.annule:    return const Color(0xFFF44336);
      case ReservationStatus.termine:   return const Color(0xFF4CAF50);
    }
  }

  static ReservationStatus fromString(String s) {
    return ReservationStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ReservationStatus.enAttente,
    );
  }
}

// ── Enum statut paiement réservation ─────────────────────────────────────
enum ReservationPaymentStatus { nonPaye, partiel, paye }

extension ReservationPaymentStatusX on ReservationPaymentStatus {
  String get label {
    switch (this) {
      case ReservationPaymentStatus.nonPaye: return 'Non payé';
      case ReservationPaymentStatus.partiel: return 'Partiel';
      case ReservationPaymentStatus.paye:    return 'Payé';
    }
  }

  Color get color {
    switch (this) {
      case ReservationPaymentStatus.nonPaye: return const Color(0xFFF44336);
      case ReservationPaymentStatus.partiel: return const Color(0xFFFFC107);
      case ReservationPaymentStatus.paye:    return const Color(0xFF4CAF50);
    }
  }

  static ReservationPaymentStatus fromString(String s) {
    return ReservationPaymentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ReservationPaymentStatus.nonPaye,
    );
  }
}

// ── Modèle Réservation ────────────────────────────────────────────────────
class Reservation {
  final String id;
  // Client
  final String nomClient;
  final String telephone;
  final String telephoneSecondaire;
  final String email;
  final String adresse;
  // Événement
  final EventType typeEvenement;
  final DateTime dateReservation;
  final DateTime dateEvenement;
  final String heureDebut;
  final String heureFin;
  final int nombrePersonnes;
  final String salle;
  final String responsableCommercial;
  final String description;
  // Montants
  final double montantTotal;
  final double acompteVerse;
  final double remise;
  // Statuts
  ReservationStatus status;
  ReservationPaymentStatus paymentStatus;
  // Paiement
  final double montantPaye;
  // Méta
  final DateTime createdAt;
  final String createdBy;

  Reservation({
    required this.id,
    required this.nomClient,
    required this.telephone,
    this.telephoneSecondaire = '',
    this.email = '',
    this.adresse = '',
    required this.typeEvenement,
    required this.dateReservation,
    required this.dateEvenement,
    this.heureDebut = '',
    this.heureFin = '',
    this.nombrePersonnes = 1,
    this.salle = '',
    this.responsableCommercial = '',
    this.description = '',
    required this.montantTotal,
    this.acompteVerse = 0,
    this.remise = 0,
    this.status = ReservationStatus.enAttente,
    this.paymentStatus = ReservationPaymentStatus.nonPaye,
    this.montantPaye = 0,
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  double get soldeRestant => montantTotal - remise - montantPaye;
  double get montantNet   => montantTotal - remise;
  bool   get isToday      => _sameDay(dateEvenement, DateTime.now());
  bool   get isPast       => dateEvenement.isBefore(DateTime.now());
  int    get daysUntil    => dateEvenement.difference(DateTime.now()).inDays;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, dynamic> toMap() => {
    'nomClient':              nomClient,
    'telephone':              telephone,
    'telephoneSecondaire':    telephoneSecondaire,
    'email':                  email,
    'adresse':                adresse,
    'typeEvenement':          typeEvenement.name,
    'dateReservation':        dateReservation.toIso8601String(),
    'dateEvenement':          dateEvenement.toIso8601String(),
    'heureDebut':             heureDebut,
    'heureFin':               heureFin,
    'nombrePersonnes':        nombrePersonnes,
    'salle':                  salle,
    'responsableCommercial':  responsableCommercial,
    'description':            description,
    'montantTotal':           montantTotal,
    'acompteVerse':           acompteVerse,
    'remise':                 remise,
    'status':                 status.name,
    'paymentStatus':          paymentStatus.name,
    'montantPaye':            montantPaye,
    'createdAt':              createdAt.toIso8601String(),
    'createdBy':              createdBy,
  };

  factory Reservation.fromMap(Map<String, dynamic> m, String docId) => Reservation(
    id:                    docId,
    nomClient:             m['nomClient']            as String? ?? '',
    telephone:             m['telephone']            as String? ?? '',
    telephoneSecondaire:   m['telephoneSecondaire']  as String? ?? '',
    email:                 m['email']                as String? ?? '',
    adresse:               m['adresse']              as String? ?? '',
    typeEvenement:         EventTypeX.fromString(m['typeEvenement'] as String? ?? ''),
    dateReservation:       DateTime.tryParse(m['dateReservation'] as String? ?? '') ?? DateTime.now(),
    dateEvenement:         DateTime.tryParse(m['dateEvenement']  as String? ?? '') ?? DateTime.now(),
    heureDebut:            m['heureDebut']           as String? ?? '',
    heureFin:              m['heureFin']             as String? ?? '',
    nombrePersonnes:       (m['nombrePersonnes']     as num?)?.toInt() ?? 1,
    salle:                 m['salle']                as String? ?? '',
    responsableCommercial: m['responsableCommercial'] as String? ?? '',
    description:           m['description']          as String? ?? '',
    montantTotal:          (m['montantTotal']        as num?)?.toDouble() ?? 0,
    acompteVerse:          (m['acompteVerse']        as num?)?.toDouble() ?? 0,
    remise:                (m['remise']              as num?)?.toDouble() ?? 0,
    status:                ReservationStatusX.fromString(m['status'] as String? ?? ''),
    paymentStatus:         ReservationPaymentStatusX.fromString(m['paymentStatus'] as String? ?? ''),
    montantPaye:           (m['montantPaye']         as num?)?.toDouble() ?? 0,
    createdAt:             DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    createdBy:             m['createdBy']            as String? ?? '',
  );

  Reservation copyWith({
    String? id, String? nomClient, String? telephone, String? telephoneSecondaire,
    String? email, String? adresse, EventType? typeEvenement,
    DateTime? dateReservation, DateTime? dateEvenement,
    String? heureDebut, String? heureFin, int? nombrePersonnes,
    String? salle, String? responsableCommercial, String? description,
    double? montantTotal, double? acompteVerse, double? remise,
    ReservationStatus? status, ReservationPaymentStatus? paymentStatus,
    double? montantPaye, DateTime? createdAt, String? createdBy,
  }) => Reservation(
    id:                    id                    ?? this.id,
    nomClient:             nomClient             ?? this.nomClient,
    telephone:             telephone             ?? this.telephone,
    telephoneSecondaire:   telephoneSecondaire   ?? this.telephoneSecondaire,
    email:                 email                 ?? this.email,
    adresse:               adresse               ?? this.adresse,
    typeEvenement:         typeEvenement         ?? this.typeEvenement,
    dateReservation:       dateReservation       ?? this.dateReservation,
    dateEvenement:         dateEvenement         ?? this.dateEvenement,
    heureDebut:            heureDebut            ?? this.heureDebut,
    heureFin:              heureFin              ?? this.heureFin,
    nombrePersonnes:       nombrePersonnes       ?? this.nombrePersonnes,
    salle:                 salle                 ?? this.salle,
    responsableCommercial: responsableCommercial ?? this.responsableCommercial,
    description:           description           ?? this.description,
    montantTotal:          montantTotal          ?? this.montantTotal,
    acompteVerse:          acompteVerse          ?? this.acompteVerse,
    remise:                remise                ?? this.remise,
    status:                status                ?? this.status,
    paymentStatus:         paymentStatus         ?? this.paymentStatus,
    montantPaye:           montantPaye           ?? this.montantPaye,
    createdAt:             createdAt             ?? this.createdAt,
    createdBy:             createdBy             ?? this.createdBy,
  );
}

// ── Paiement réservation ─────────────────────────────────────────────────
class ReservationPayment {
  final String id;
  final String reservationId;
  final String nomClient;
  final double montant;
  final String modePaiement;
  final DateTime date;
  final String caissier;
  final String observation;
  final String typeVersement; // 'acompte' | 'complement' | 'final' | 'autre'

  ReservationPayment({
    required this.id,
    required this.reservationId,
    required this.nomClient,
    required this.montant,
    required this.modePaiement,
    required this.date,
    this.caissier = '',
    this.observation = '',
    this.typeVersement = 'complement',
  });

  Map<String, dynamic> toMap() => {
    'reservationId':  reservationId,
    'nomClient':      nomClient,
    'montant':        montant,
    'modePaiement':   modePaiement,
    'date':           date.toIso8601String(),
    'caissier':       caissier,
    'observation':    observation,
    'typeVersement':  typeVersement,
  };

  factory ReservationPayment.fromMap(Map<String, dynamic> m, String docId) =>
      ReservationPayment(
        id:            docId,
        reservationId: m['reservationId'] as String? ?? '',
        nomClient:     m['nomClient']     as String? ?? '',
        montant:       (m['montant']      as num?)?.toDouble() ?? 0,
        modePaiement:  m['modePaiement']  as String? ?? 'Espèces',
        date:          DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        caissier:      m['caissier']      as String? ?? '',
        observation:   m['observation']   as String? ?? '',
        typeVersement: m['typeVersement'] as String? ?? 'complement',
      );
}

// ── Alerte réservation ────────────────────────────────────────────────────
class ReservationAlert {
  final String id;
  final String reservationId;
  final String nomClient;
  final String typeAlerte; // '30j' | '15j' | '7j' | '3j' | '24h' | 'impaye' | 'auj'
  final String message;
  final DateTime dateAlerte;
  bool isRead;

  ReservationAlert({
    required this.id,
    required this.reservationId,
    required this.nomClient,
    required this.typeAlerte,
    required this.message,
    required this.dateAlerte,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'reservationId': reservationId,
    'nomClient':     nomClient,
    'typeAlerte':    typeAlerte,
    'message':       message,
    'dateAlerte':    dateAlerte.toIso8601String(),
    'isRead':        isRead,
  };

  factory ReservationAlert.fromMap(Map<String, dynamic> m, String docId) =>
      ReservationAlert(
        id:            docId,
        reservationId: m['reservationId'] as String? ?? '',
        nomClient:     m['nomClient']     as String? ?? '',
        typeAlerte:    m['typeAlerte']    as String? ?? '',
        message:       m['message']       as String? ?? '',
        dateAlerte:    DateTime.tryParse(m['dateAlerte'] as String? ?? '') ?? DateTime.now(),
        isRead:        m['isRead']        as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// CAMBUSE — Gestion des boissons
// Collection Firestore : 'cambuse' (boissons) + 'cambuse_movements' (historique)
// Logique simple : 1 boisson vendue = -1 en cambuse (pas de liaison complexe)
// ═══════════════════════════════════════════════════════════════════════════

// ── CambuseCategory : catégories personnalisables de la cambuse ──────────
class CambuseCategory {
  final String id;
  String name;
  final DateTime createdAt;

  CambuseCategory({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id':        id,
    'name':      name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory CambuseCategory.fromMap(Map<String, dynamic> m, String docId) => CambuseCategory(
    id:        docId,
    name:      m['name']      as String? ?? '',
    createdAt: _parseDTNullable(m['createdAt']) ?? DateTime.now(),
  );
}

enum CambuseMovementType {
  entree,                 // approvisionnement manuel
  sortieCommande,         // vente via commande (automatique)
  sortieManuelle,         // ajustement manuel négatif
  inventaire,             // correction d'inventaire
  creation,               // création d'un nouvel article
  suppression,            // suppression (soft-delete) d'un article
}

extension CambuseMovementTypeLabel on CambuseMovementType {
  String get label {
    switch (this) {
      case CambuseMovementType.entree:          return 'Approvisionnement';
      case CambuseMovementType.sortieCommande:  return 'Vente';
      case CambuseMovementType.sortieManuelle:  return 'Sortie manuelle';
      case CambuseMovementType.inventaire:      return 'Inventaire';
      case CambuseMovementType.creation:        return 'Création';
      case CambuseMovementType.suppression:     return 'Suppression';
    }
  }
  bool get isEntry => this == CambuseMovementType.entree
      || this == CambuseMovementType.inventaire
      || this == CambuseMovementType.creation;
}

// ── CambuseItem : boisson en stock Cambuse ───────────────────────────────
class CambuseItem {
  final String id;
  String name;
  String category;       // ex: 'Sodas', 'Bières', 'Jus', 'Eaux', 'Alcools'
  int quantity;          // quantité disponible (unités)
  int alertThreshold;    // seuil d'alerte stock faible
  double sellingPrice;   // prix de vente unitaire
  String? productId;     // id du produit Firestore associé (optionnel, pour auto-déduction)
  bool isActive;
  DateTime createdAt;
  DateTime? updatedAt;

  CambuseItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.alertThreshold = 10,
    required this.sellingPrice,
    this.productId,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => quantity <= alertThreshold && quantity > 0;
  bool get isOutOfStock => quantity <= 0;

  Map<String, dynamic> toMap() => {
    'id':             id,
    'name':           name,
    'category':       category,
    'quantity':       quantity,
    'alertThreshold': alertThreshold,
    'sellingPrice':   sellingPrice,
    'productId':      productId,
    'isActive':       isActive,
    'createdAt':      createdAt.millisecondsSinceEpoch,
    'updatedAt':      updatedAt?.millisecondsSinceEpoch,
  };

  factory CambuseItem.fromMap(Map<String, dynamic> m, String docId) => CambuseItem(
    id:             docId,
    name:           m['name']           as String? ?? '',
    category:       m['category']       as String? ?? 'Boissons',
    quantity:       (m['quantity']      as num?)?.toInt() ?? 0,
    alertThreshold: (m['alertThreshold'] as num?)?.toInt() ?? 10,
    sellingPrice:   (m['sellingPrice']  as num?)?.toDouble() ?? 0,
    productId:      m['productId']      as String?,
    isActive:       m['isActive']       as bool? ?? true,
    createdAt:      _parseDTNullable(m['createdAt']) ?? DateTime.now(),
    updatedAt:      _parseDTNullable(m['updatedAt']),
  );
}

// ── CambuseMovement : historique des mouvements cambuse ──────────────────
class CambuseMovement {
  final String id;
  final String cambuseItemId;
  final String cambuseItemName;
  final String category;       // catégorie de la boisson
  final CambuseMovementType type;
  final int quantity;          // quantité bougée (toujours positive)
  final int quantityBefore;    // stock avant le mouvement
  final int quantityAfter;     // stock après le mouvement
  final double unitPrice;      // prix unitaire au moment du mouvement
  final double totalAmount;    // montant total (unitPrice × quantity, si vente)
  final String? orderId;       // commande liée (si sortieCommande)
  final String? orderNumber;   // numéro lisible de la commande
  final String? note;          // commentaire / note libre
  final String createdBy;      // nom utilisateur
  final DateTime createdAt;

  CambuseMovement({
    required this.id,
    required this.cambuseItemId,
    required this.cambuseItemName,
    this.category = '',
    required this.type,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.unitPrice = 0.0,
    this.totalAmount = 0.0,
    this.orderId,
    this.orderNumber,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id':               id,
    'cambuseItemId':    cambuseItemId,
    'cambuseItemName':  cambuseItemName,
    'category':         category,
    'type':             type.index,
    'quantity':         quantity,
    'quantityBefore':   quantityBefore,
    'quantityAfter':    quantityAfter,
    'unitPrice':        unitPrice,
    'totalAmount':      totalAmount,
    'orderId':          orderId,
    'orderNumber':      orderNumber,
    'note':             note,
    'createdBy':        createdBy,
    'createdAt':        createdAt.millisecondsSinceEpoch,
  };

  factory CambuseMovement.fromMap(Map<String, dynamic> m, String docId) {
    final typeIdx = (m['type'] as num?)?.toInt() ?? 0;
    final safeIdx = typeIdx.clamp(0, CambuseMovementType.values.length - 1);
    return CambuseMovement(
      id:              docId,
      cambuseItemId:   m['cambuseItemId']   as String? ?? '',
      cambuseItemName: m['cambuseItemName'] as String? ?? '',
      category:        m['category']        as String? ?? '',
      type:            CambuseMovementType.values[safeIdx],
      quantity:        (m['quantity']       as num?)?.toInt() ?? 0,
      quantityBefore:  (m['quantityBefore'] as num?)?.toInt() ?? 0,
      quantityAfter:   (m['quantityAfter']  as num?)?.toInt() ?? 0,
      unitPrice:       (m['unitPrice']      as num?)?.toDouble() ?? 0.0,
      totalAmount:     (m['totalAmount']    as num?)?.toDouble() ?? 0.0,
      orderId:         m['orderId']         as String?,
      orderNumber:     m['orderNumber']     as String?,
      note:            m['note']            as String?,
      createdBy:       m['createdBy']       as String? ?? '',
      createdAt:       _parseDTNullable(m['createdAt']) ?? DateTime.now(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INVENTAIRE CAMBUSE — Collections Firestore séparées du stock cuisine
//  cambuse_inventory_sessions  /  cambuse_inventory_items
// ══════════════════════════════════════════════════════════════════════════════

// ── Statut de session d'inventaire cambuse ────────────────────────────────────
enum CambuseInventoryStatus { inProgress, completed, cancelled }

extension CambuseInventoryStatusX on CambuseInventoryStatus {
  String get label {
    switch (this) {
      case CambuseInventoryStatus.inProgress: return 'En cours';
      case CambuseInventoryStatus.completed:  return 'Terminé';
      case CambuseInventoryStatus.cancelled:  return 'Annulé';
    }
  }

  String get key {
    switch (this) {
      case CambuseInventoryStatus.inProgress: return 'in_progress';
      case CambuseInventoryStatus.completed:  return 'completed';
      case CambuseInventoryStatus.cancelled:  return 'cancelled';
    }
  }

  static CambuseInventoryStatus fromKey(String k) {
    switch (k) {
      case 'completed':  return CambuseInventoryStatus.completed;
      case 'cancelled':  return CambuseInventoryStatus.cancelled;
      default:           return CambuseInventoryStatus.inProgress;
    }
  }
}

// ── Statut d'une ligne d'inventaire cambuse ───────────────────────────────────
enum CambuseInventoryItemStatus { notCounted, compliant, missing, surplus }

extension CambuseInventoryItemStatusX on CambuseInventoryItemStatus {
  String get label {
    switch (this) {
      case CambuseInventoryItemStatus.notCounted: return 'Non compté';
      case CambuseInventoryItemStatus.compliant:  return 'Conforme';
      case CambuseInventoryItemStatus.missing:    return 'Manquant';
      case CambuseInventoryItemStatus.surplus:    return 'Surplus';
    }
  }

  static CambuseInventoryItemStatus compute(int? counted, int theoretical) {
    if (counted == null) return CambuseInventoryItemStatus.notCounted;
    final diff = counted - theoretical;
    if (diff == 0) return CambuseInventoryItemStatus.compliant;
    return diff < 0
        ? CambuseInventoryItemStatus.missing
        : CambuseInventoryItemStatus.surplus;
  }
}

// ── Session d'inventaire Cambuse (document Firestore) ────────────────────────
class CambuseInventorySession {
  final String id;
  final DateTime date;
  final String responsibleId;
  final String responsibleName;
  final String site;
  CambuseInventoryStatus status;
  final int totalProducts;
  final int totalCounted;
  final int totalMissing;
  final int totalSurplus;
  final DateTime? completedAt;

  CambuseInventorySession({
    required this.id,
    required this.date,
    required this.responsibleId,
    required this.responsibleName,
    required this.site,
    this.status = CambuseInventoryStatus.inProgress,
    this.totalProducts = 0,
    this.totalCounted  = 0,
    this.totalMissing  = 0,
    this.totalSurplus  = 0,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'id':               id,
    'date':             date.millisecondsSinceEpoch,
    'responsibleId':    responsibleId,
    'responsibleName':  responsibleName,
    'site':             site,
    'status':           status.key,
    'totalProducts':    totalProducts,
    'totalCounted':     totalCounted,
    'totalMissing':     totalMissing,
    'totalSurplus':     totalSurplus,
    'completedAt':      completedAt?.millisecondsSinceEpoch,
  };

  factory CambuseInventorySession.fromMap(Map<String, dynamic> m, String docId) =>
      CambuseInventorySession(
        id:               docId,
        date:             m['date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['date'] as int)
            : DateTime.now(),
        responsibleId:    m['responsibleId']   as String? ?? '',
        responsibleName:  m['responsibleName'] as String? ?? '',
        site:             m['site']            as String? ?? '',
        status: CambuseInventoryStatusX.fromKey(m['status'] as String? ?? ''),
        totalProducts: (m['totalProducts'] as num?)?.toInt() ?? 0,
        totalCounted:  (m['totalCounted']  as num?)?.toInt() ?? 0,
        totalMissing:  (m['totalMissing']  as num?)?.toInt() ?? 0,
        totalSurplus:  (m['totalSurplus']  as num?)?.toInt() ?? 0,
        completedAt: m['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['completedAt'] as int)
            : null,
      );
}

// ── Ligne d'inventaire Cambuse (document Firestore) ──────────────────────────
class CambuseInventoryItem {
  final String id;
  final String sessionId;
  final String cambuseItemId;
  final String cambuseItemName;
  final String category;
  final String unit;
  final int theoreticalQty;   // quantité théorique (entier pour boissons)
  int? countedQty;            // null = pas encore compté
  String comment;
  final double unitCost;      // prix unitaire pour valeur écart

  CambuseInventoryItem({
    required this.id,
    required this.sessionId,
    required this.cambuseItemId,
    required this.cambuseItemName,
    required this.category,
    required this.unit,
    required this.theoreticalQty,
    this.countedQty,
    this.comment = '',
    this.unitCost = 0,
  });

  int get gap => countedQty != null ? countedQty! - theoreticalQty : 0;
  double get gapValue => gap * unitCost;

  CambuseInventoryItemStatus get status =>
      CambuseInventoryItemStatusX.compute(countedQty, theoreticalQty);

  Map<String, dynamic> toMap() => {
    'id':               id,
    'sessionId':        sessionId,
    'cambuseItemId':    cambuseItemId,
    'cambuseItemName':  cambuseItemName,
    'category':         category,
    'unit':             unit,
    'theoreticalQty':   theoreticalQty,
    'countedQty':       countedQty,
    'comment':          comment,
    'unitCost':         unitCost,
  };

  factory CambuseInventoryItem.fromMap(Map<String, dynamic> m, String docId) =>
      CambuseInventoryItem(
        id:              docId,
        sessionId:       m['sessionId']      as String? ?? '',
        cambuseItemId:   m['cambuseItemId']  as String? ?? '',
        cambuseItemName: m['cambuseItemName'] as String? ?? '',
        category:        m['category']       as String? ?? '',
        unit:            m['unit']           as String? ?? '',
        theoreticalQty: (m['theoreticalQty'] as num?)?.toInt() ?? 0,
        countedQty:     (m['countedQty']     as num?)?.toInt(),
        comment:         m['comment']        as String? ?? '',
        unitCost:        (m['unitCost']       as num?)?.toDouble() ?? 0,
      );
}
