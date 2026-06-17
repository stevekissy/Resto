import 'package:flutter/material.dart';

// =================== ENUMS ===================
enum OrderStatus { pending, preparing, ready, served, cancelled }
enum UserRole { admin, manager, cashier, kitchen, server }
enum StockAlertType { lowStock, outOfStock, expired }
enum MessageType { text, image, file, call }
enum AttendanceType { morning, evening }
enum SupplierPaymentStatus { pending, partial, paid }

// =================== USER MODEL ===================
class AppUser {
  final String id;
  String name;
  String email;
  String phone;
  UserRole role;
  String? avatarUrl;
  bool isActive;
  bool isOnline;
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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get roleLabel {
    switch (role) {
      case UserRole.admin: return 'Administrateur';
      case UserRole.manager: return 'Manager';
      case UserRole.cashier: return 'Caissier(ère)';
      case UserRole.kitchen: return 'Cuisine';
      case UserRole.server: return 'Serveur(se)';
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.admin: return const Color(0xFF1565C0);
      case UserRole.manager: return const Color(0xFF6A1B9A);
      case UserRole.cashier: return const Color(0xFF2E7D32);
      case UserRole.kitchen: return const Color(0xFFE65100);
      case UserRole.server: return const Color(0xFF00838F);
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'phone': phone,
    'role': role.index, 'avatarUrl': avatarUrl,
    'isActive': isActive, 'isOnline': isOnline,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'], name: map['name'], email: map['email'],
    phone: map['phone'] ?? '', role: UserRole.values[map['role'] ?? 0],
    avatarUrl: map['avatarUrl'], isActive: map['isActive'] ?? true,
    isOnline: map['isOnline'] ?? false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
  );
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
  }) : ingredients = ingredients ?? {};

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'category': category, 'price': price,
    'prepTime': prepTime, 'description': description, 'imageUrl': imageUrl,
    'isAvailable': isAvailable, 'stockQuantity': stockQuantity,
    'minStockAlert': minStockAlert, 'ingredients': ingredients,
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'], name: map['name'], category: map['category'],
    price: (map['price'] as num).toDouble(),
    prepTime: (map['prepTime'] as num).toDouble(),
    description: map['description'], imageUrl: map['imageUrl'],
    isAvailable: map['isAvailable'] ?? true,
    stockQuantity: map['stockQuantity'] ?? 100,
    minStockAlert: map['minStockAlert'] ?? 10,
    ingredients: Map<String, double>.from(map['ingredients'] ?? {}),
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

  // Statuts d'impression — mis à jour dans Firestore après chaque impression
  bool receiptPrinted;    // Reçu d'encaissement imprimé
  bool settlementPrinted; // Reçu de règlement imprimé

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
    this.receiptPrinted = false,
    this.settlementPrinted = false,
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
    'receiptPrinted': receiptPrinted,
    'settlementPrinted': settlementPrinted,
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
    receiptPrinted: map['receiptPrinted'] as bool? ?? false,
    settlementPrinted: map['settlementPrinted'] as bool? ?? false,
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

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.phone,
    this.email,
    this.address,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'contact': contact,
    'phone': phone, 'email': email, 'address': address,
  };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'], name: map['name'], contact: map['contact'],
    phone: map['phone'], email: map['email'], address: map['address'],
  );
}

// =================== SUPPLIER ORDER MODEL ===================
class SupplierOrder {
  final String id;
  final String supplierId;
  final String supplierName;
  List<Map<String, dynamic>> items;
  double totalAmount;
  double paidAmount;
  SupplierPaymentStatus paymentStatus;
  String paymentMethod;
  DateTime orderDate;
  DateTime? deliveryDate;
  DateTime? expectedDelivery;
  String? notes;

  SupplierOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    this.paidAmount = 0,
    this.paymentStatus = SupplierPaymentStatus.pending,
    this.paymentMethod = 'Espèces',
    DateTime? orderDate,
    this.deliveryDate,
    this.expectedDelivery,
    this.notes,
  }) : orderDate = orderDate ?? DateTime.now();

  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => paidAmount >= totalAmount;

  Map<String, dynamic> toMap() => {
    'id': id, 'supplierId': supplierId, 'supplierName': supplierName,
    'items': items, 'totalAmount': totalAmount, 'paidAmount': paidAmount,
    'paymentStatus': paymentStatus.index, 'paymentMethod': paymentMethod,
    'orderDate': orderDate.millisecondsSinceEpoch,
    'deliveryDate': deliveryDate?.millisecondsSinceEpoch,
    'expectedDelivery': expectedDelivery?.millisecondsSinceEpoch,
    'notes': notes,
  };

  factory SupplierOrder.fromMap(Map<String, dynamic> map) => SupplierOrder(
    id: map['id'], supplierId: map['supplierId'], supplierName: map['supplierName'],
    items: List<Map<String, dynamic>>.from(map['items'] ?? []),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
    paymentStatus: SupplierPaymentStatus.values[map['paymentStatus'] ?? 0],
    paymentMethod: map['paymentMethod'] ?? 'Espèces',
    orderDate: DateTime.fromMillisecondsSinceEpoch(map['orderDate']),
    deliveryDate: map['deliveryDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['deliveryDate']) : null,
    expectedDelivery: map['expectedDelivery'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expectedDelivery']) : null,
    notes: map['notes'],
  );
}
