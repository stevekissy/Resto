import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/models.dart';

// ── Helper : convertit un champ Firestore (Timestamp ou int) en DateTime ──
DateTime _toDateTime(dynamic val, {DateTime? fallback}) {
  if (val == null) return fallback ?? DateTime.now();
  if (val is Timestamp) return val.toDate();
  if (val is int)       return DateTime.fromMillisecondsSinceEpoch(val);
  return fallback ?? DateTime.now();
}

DateTime? _toDateTimeNullable(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is int)       return DateTime.fromMillisecondsSinceEpoch(val);
  return null;
}

class FirebaseService {
  // Lazy getters — accédés APRÈS Firebase.initializeApp() dans main()
  FirebaseAuth      get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db   => FirebaseFirestore.instance;

  // =================== AUTH ===================

  /// Active la persistance locale Firebase Auth sur Web (localStorage).
  /// À appeler UNE FOIS après Firebase.initializeApp(), avant tout accès auth.
  /// Sur Android/iOS la persistance est locale par défaut — appel ignoré.
  Future<void> enableWebPersistence() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(Persistence.LOCAL);
      debugPrint('[FirebaseService] ✅ Persistance Auth Web : LOCAL');
    } catch (e) {
      // Non bloquant — certains navigateurs (Safari privé) refusent localStorage
      debugPrint('[FirebaseService] ⚠ setPersistence: $e');
    }
  }

  /// Attend que Firebase Auth ait résolu l'état initial de session.
  /// Sur Web avec persistance LOCAL, cela prend ~50-200ms le temps que
  /// Firebase lise le token dans localStorage et vérifie sa validité.
  /// Retourne l'utilisateur connecté, ou null si déconnecté.
  Future<User?> resolveAuthState() async {
    try {
      // authStateChanges().first émet l'état actuel UNE SEULE FOIS
      // puis termine — c'est exactement ce qu'on veut au démarrage.
      final user = await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[FirebaseService] ⚠ resolveAuthState timeout — traité comme déconnecté');
          return null;
        },
      );
      debugPrint('[FirebaseService] resolveAuthState → ${user?.email ?? "null (non connecté)"}');
      return user;
    } catch (e) {
      debugPrint('[FirebaseService] resolveAuthState erreur: $e');
      return null;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async => await _auth.signOut();

  /// Crée un compte Firebase Auth + document Firestore en une seule opération atomique.
  /// - Si Auth échoue  → exception propagée, aucun doc Firestore créé.
  /// - Si Firestore échoue après Auth → rollback impossible côté Auth (limitation Firebase)
  ///   mais l'exception est propagée pour affichage clair dans l'UI.
  /// Retourne l'AppUser créé.
  Future<AppUser> createUserWithAuth({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required String createdBy,
  }) async {
    // ÉTAPE 1 — Créer le compte Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    // ÉTAPE 2 — Créer le document Firestore (uniquement si Auth a réussi)
    final newUser = AppUser(
      id: uid,
      name: name,
      email: email.trim(),
      phone: '',
      role: role,
      isActive: true,
    );
    await _db.collection('users').doc(uid).set({
      'id': uid,
      'name': name,
      'email': email.trim(),
      'role': role.index,
      'isActive': true,
      'isOnline': false,
      'phone': '',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    debugPrint('[FirebaseService] ✅ Utilisateur créé Auth+Firestore : $email ($uid)');
    return newUser;
  }

  /// Lecture synchrone — peut retourner null brièvement au démarrage Web.
  /// Préférer resolveAuthState() pour la reprise de session au boot.
  User? get currentFirebaseUser => _auth.currentUser;

  // =================== USERS ===================

  /// Crée le document user s'il n'existe pas encore.
  Future<AppUser> ensureUserDoc(String uid, String email, UserRole role, String displayName) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return _userFromDoc(doc.data()!, uid);
      }
      // Créer automatiquement
      final newUser = AppUser(
        id: uid, name: displayName, email: email,
        phone: '', role: role, isActive: true,
      );
      await _db.collection('users').doc(uid).set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FirebaseService] User doc créé pour $email');
      return newUser;
    } catch (e) {
      debugPrint('[FirebaseService] ensureUserDoc error: $e');
      return AppUser(id: uid, name: displayName, email: email, phone: '', role: role);
    }
  }

  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return _userFromDoc(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      debugPrint('[FirebaseService] getUserByUid error: $e');
      return null;
    }
  }

  AppUser _userFromDoc(Map<String, dynamic> d, String id) => AppUser(
    id: id,
    name: d['name'] as String? ?? 'Utilisateur',
    email: d['email'] as String? ?? '',
    phone: d['phone'] as String? ?? '',
    role: UserRole.values[(d['role'] as int?) ?? 0],
    avatarUrl: d['avatarUrl'] as String?,
    isActive: d['isActive'] as bool? ?? true,
    isOnline: d['isOnline'] as bool? ?? false,
    createdAt: _toDateTime(d['createdAt']),
  );

  // Stream sans orderBy — tri en mémoire (aucun index requis)
  Stream<List<AppUser>> streamUsers() {
    return _db.collection('users').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try { return _userFromDoc(d.data(), d.id); }
        catch (e) { debugPrint('[stream.users] doc ${d.id}: $e'); return null; }
      }).whereType<AppUser>().toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.id).set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUser(AppUser user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> setUserOnline(String uid, bool online) async {
    try { await _db.collection('users').doc(uid).update({'isOnline': online}); }
    catch (_) {}
  }

  // =================== PRODUCTS ===================

  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return Product(
            id: d.id,
            name: data['name'] as String? ?? '',
            category: data['category'] as String? ?? 'Plats',
            price: (data['price'] as num?)?.toDouble() ?? 0,
            prepTime: (data['prepTime'] as num?)?.toDouble() ?? 0,
            description: data['description'] as String?,
            imageUrl: data['imageUrl'] as String?,
            isAvailable: data['isAvailable'] as bool? ?? true,
            stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
            minStockAlert: (data['minStockAlert'] as num?)?.toInt() ?? 10,
            ingredients: Map<String, double>.from(data['ingredients'] ?? {}),
          );
        } catch (e) {
          debugPrint('[stream.products] doc ${d.id}: $e');
          return null;
        }
      }).whereType<Product>().toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> saveProduct(Product product) async {
    await _db.collection('products').doc(product.id).set(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _db.collection('products').doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  // =================== ORDER COUNTER ===================

  /// Retourne le prochain numéro de commande unique via transaction Firestore.
  /// Collection : counters  |  Document : orderCounter  |  Champ : lastNumber
  /// Utilise runTransaction() pour éviter tout doublon même en cas de
  /// créations simultanées depuis plusieurs postes.
  Future<int> getNextOrderNumber() async {
    final counterRef = _db.collection('counters').doc('orderCounter');
    int nextNumber = 101;
    await _db.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      if (snap.exists) {
        final last = (snap.data()!['lastNumber'] as num?)?.toInt() ?? 100;
        nextNumber = last + 1;
      } else {
        nextNumber = 101;
      }
      txn.set(counterRef, {
        'lastNumber': nextNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    debugPrint('[FirebaseService] getNextOrderNumber → $nextNumber');
    return nextNumber;
  }

  // =================== ORDERS ===================
  // PAS de .orderBy() → aucun index composite requis → tri en mémoire

  Stream<List<Order>> streamOrders() {
    return _db.collection('orders').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return Order(
            id: d.id,
            orderNumber: (data['orderNumber'] as num?)?.toInt() ?? 0,
            tableNumber: data['tableNumber'] as String? ?? '',
            serverName: data['serverName'] as String?,
            items: _parseOrderItems(data['items']),
            status: OrderStatus.values[(data['status'] as int?) ?? 0],
            specialInstructions: data['specialInstructions'] as String?,
            isUrgent: data['isUrgent'] as bool? ?? false,
            createdAt: _toDateTime(data['createdAt']),
            startedAt: _toDateTimeNullable(data['startedAt']),
            readyAt: _toDateTimeNullable(data['readyAt']),
            servedAt: _toDateTimeNullable(data['servedAt']),
            discount: (data['discount'] as num?)?.toDouble() ?? 0,
            isPaid: data['isPaid'] as bool? ?? false,
            paymentMethod: data['paymentMethod'] as String?,
            amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0,
            // ── Cycle de vie caisse 2 étapes ──────────────────────────
            cashStatus: CashStatus.values[
              (data['cashStatus'] as int?) ?? CashStatus.pending_cashout.index
            ],
            cashoutInvoiceGenerated:
                data['cashoutInvoiceGenerated'] as bool? ?? false,
            settlementInvoiceGenerated:
                data['settlementInvoiceGenerated'] as bool? ?? false,
            cashoutInvoiceNumber:
                data['cashoutInvoiceNumber'] as String?,
            cashoutAt: _toDateTimeNullable(data['cashoutAt']),
            cashierId: data['cashierId'] as String?,
            cashierName: data['cashierName'] as String?,
            settlementInvoiceNumber:
                data['settlementInvoiceNumber'] as String?,
            settledAt: _toDateTimeNullable(data['settledAt']),
            changeAmount:
                (data['changeAmount'] as num?)?.toDouble() ?? 0,
            receiptPrinted: data['receiptPrinted'] as bool? ?? false,
            settlementPrinted:
                data['settlementPrinted'] as bool? ?? false,
            serverId: data['serverId'] as String?,
            serverEmail: data['serverEmail'] as String?,
            updatedAt: _toDateTimeNullable(data['updatedAt']),
            cancelledAt: _toDateTimeNullable(data['cancelledAt']),
            cancelledBy: data['cancelledBy'] as String?,
            cancelReason: data['cancelReason'] as String?,
            paymentStatus: data['paymentStatus'] as String?,
            settlementStatus: data['settlementStatus'] as String?,
          );
        } catch (e) {
          debugPrint('[stream.orders] doc ${d.id}: $e');
          return null;
        }
      }).whereType<Order>().toList();
      // Tri en mémoire : plus récent en premier
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  List<OrderItem> _parseOrderItems(dynamic raw) {
    if (raw == null) return [];
    try {
      return (raw as List).map((i) {
        final m = i as Map<String, dynamic>;
        return OrderItem(
          productId: m['productId'] as String? ?? '',
          productName: m['productName'] as String? ?? '',
          quantity: (m['quantity'] as num?)?.toInt() ?? 1,
          unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
          specialComment: m['specialComment'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[parseOrderItems] $e');
      return [];
    }
  }

  Future<void> saveOrder(Order order) async {
    await _db.collection('orders').doc(order.id).set({
      ...order.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOrder(Order order) async {
    await _db.collection('orders').doc(order.id).update(order.toMap());
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final data = <String, dynamic>{'status': status.index};
    if (status == OrderStatus.preparing) data['startedAt'] = FieldValue.serverTimestamp();
    if (status == OrderStatus.ready)     data['readyAt']   = FieldValue.serverTimestamp();
    if (status == OrderStatus.served)    data['servedAt']  = FieldValue.serverTimestamp();
    await _db.collection('orders').doc(orderId).update(data);
  }

  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
  }

  /// Met à jour les articles et infos d'une commande (modification)
  Future<void> updateOrderItems({
    required String orderId,
    required List<OrderItem> items,
    required String tableNumber,
    String? serverName,
    String? serverId,
    String? serverEmail,
    String? specialInstructions,
    bool? isUrgent,
    double discount = 0,
  }) async {
    final updates = <String, dynamic>{
      'items': items.map((i) => i.toMap()).toList(),
      'tableNumber': tableNumber,
      'discount': discount,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (serverName != null) updates['serverName'] = serverName;
    if (serverId != null)   updates['serverId']   = serverId;
    if (serverEmail != null) updates['serverEmail'] = serverEmail;
    if (specialInstructions != null) updates['specialInstructions'] = specialInstructions;
    if (isUrgent != null)   updates['isUrgent']   = isUrgent;
    await _db.collection('orders').doc(orderId).update(updates);
  }

  /// Annule une commande (orderStatus = cancelled)
  Future<void> cancelOrder({
    required String orderId,
    required String cancelledBy,
    required String cancelReason,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.cancelled.index,
      'cancelledAt': DateTime.now().millisecondsSinceEpoch,
      'cancelledBy': cancelledBy,
      'cancelReason': cancelReason,
    });
  }

  // =================== STOCK ===================

  Stream<List<StockItem>> streamStock() {
    return _db.collection('stock').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return StockItem(
            id: d.id,
            name: data['name'] as String? ?? '',
            unit: data['unit'] as String? ?? 'unité',
            currentQuantity: (data['currentQuantity'] as num?)?.toDouble() ?? 0,
            minQuantity: (data['minQuantity'] as num?)?.toDouble() ?? 0,
            maxQuantity: (data['maxQuantity'] as num?)?.toDouble() ?? 100,
            unitCost: (data['unitCost'] as num?)?.toDouble() ?? 0,
            category: data['category'] as String? ?? 'Divers',
            expiryDate: _toDateTimeNullable(data['expiryDate']),
          );
        } catch (e) {
          debugPrint('[stream.stock] doc ${d.id}: $e');
          return null;
        }
      }).whereType<StockItem>().toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> saveStockItem(StockItem item) async {
    await _db.collection('stock').doc(item.id).set(item.toMap());
  }

  Future<void> updateStockItem(StockItem item) async {
    await _db.collection('stock').doc(item.id).update(item.toMap());
  }

  Future<void> deleteStockItem(String itemId) async {
    await _db.collection('stock').doc(itemId).delete();
  }

  // =================== MESSAGES ===================
  // PAS de .orderBy() → tri en mémoire

  Stream<List<ChatMessage>> streamMessages() {
    return _db.collection('messages').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return ChatMessage(
            id: d.id,
            senderId: data['senderId'] as String? ?? '',
            senderName: data['senderName'] as String? ?? '',
            content: data['content'] as String? ?? '',
            type: MessageType.values[(data['type'] as int?) ?? 0],
            sentAt: _toDateTime(data['sentAt']),
            receiverId: data['receiverId'] as String?,
            isRead: data['isRead'] as bool? ?? false,
          );
        } catch (e) {
          debugPrint('[stream.messages] doc ${d.id}: $e');
          return null;
        }
      }).whereType<ChatMessage>().toList();
      list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return list;
    });
  }

  Future<void> sendMessage(ChatMessage message) async {
    await _db.collection('messages').doc(message.id).set({
      ...message.toMap(),
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.collection('messages').doc(messageId).delete();
  }

  // =================== SUPPLIERS ===================

  Stream<List<Supplier>> streamSuppliers() {
    return _db.collection('suppliers').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return Supplier(
            id: d.id,
            name: data['name'] as String? ?? '',
            contact: data['contact'] as String? ?? '',
            phone: data['phone'] as String? ?? '',
            email: data['email'] as String?,
            address: data['address'] as String?,
          );
        } catch (e) {
          debugPrint('[stream.suppliers] doc ${d.id}: $e');
          return null;
        }
      }).whereType<Supplier>().toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> saveSupplier(Supplier supplier) async {
    await _db.collection('suppliers').doc(supplier.id).set(supplier.toMap());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _db.collection('suppliers').doc(supplier.id).update(supplier.toMap());
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _db.collection('suppliers').doc(supplierId).delete();
  }

  // =================== SUPPLIER ORDERS ===================
  // PAS de .orderBy() → tri en mémoire

  Stream<List<SupplierOrder>> streamSupplierOrders() {
    return _db.collection('supplierOrders').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return SupplierOrder(
            id: d.id,
            supplierId: data['supplierId'] as String? ?? '',
            supplierName: data['supplierName'] as String? ?? '',
            items: List<Map<String, dynamic>>.from(data['items'] ?? []),
            totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
            paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
            paymentStatus: SupplierPaymentStatus.values[(data['paymentStatus'] as int?) ?? 0],
            paymentMethod: data['paymentMethod'] as String? ?? '',
            orderDate: _toDateTime(data['orderDate']),
            expectedDelivery: _toDateTimeNullable(data['expectedDelivery']),
            notes: data['notes'] as String?,
          );
        } catch (e) {
          debugPrint('[stream.supplierOrders] doc ${d.id}: $e');
          return null;
        }
      }).whereType<SupplierOrder>().toList();
      list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return list;
    });
  }

  Future<void> saveSupplierOrder(SupplierOrder order) async {
    await _db.collection('supplierOrders').doc(order.id).set(order.toMap());
  }

  Future<void> updateSupplierOrder(SupplierOrder order) async {
    await _db.collection('supplierOrders').doc(order.id).update(order.toMap());
  }

  // =================== ATTENDANCES ===================

  Stream<List<Attendance>> streamAttendances() {
    return _db.collection('attendances').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          final data = d.data();
          return Attendance(
            id: d.id,
            userId: data['userId'] as String? ?? '',
            userName: data['userName'] as String? ?? '',
            date: _toDateTime(data['date']),
            morningPresent: data['morningPresent'] as bool? ?? false,
            morningTime: _toDateTimeNullable(data['morningTime']),
            eveningPresent: data['eveningPresent'] as bool? ?? false,
            eveningTime: _toDateTimeNullable(data['eveningTime']),
          );
        } catch (e) {
          debugPrint('[stream.attendances] doc ${d.id}: $e');
          return null;
        }
      }).whereType<Attendance>().toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> saveAttendance(Attendance attendance) async {
    await _db.collection('attendances').doc(attendance.id).set(attendance.toMap());
  }

  // =================== DAILY CHARGES ===================

  /// Stream des charges du jour — filtre en mémoire sur la date du jour.
  /// Collection : daily_charges  |  Champs : label, amount, date, createdAt, createdBy
  /// Pas de .where() avec Timestamp → on récupère toutes les charges
  /// et on filtre côté client pour éviter tout index composite.
  Stream<List<Map<String, dynamic>>> streamDailyCharges() {
    return _db.collection('daily_charges').snapshots().map((snap) {
      final today = DateTime.now();
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final date = _toDateTime(data['date']);
          list.add({
            'id':        doc.id,
            'label':     data['label']     as String? ?? '',
            'amount':    (data['amount']   as num?)?.toDouble() ?? 0.0,
            'note':      data['note']      as String? ?? '',
            'date':      date,
            'createdBy': data['createdBy'] as String? ?? '',
          });
        } catch (e) {
          debugPrint('[stream.daily_charges] doc ${doc.id}: $e');
        }
      }
      // Filtrer sur la date du jour côté client
      final todayCharges = list.where((c) {
        final d = c['date'] as DateTime;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).toList();
      todayCharges.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return todayCharges;
    });
  }

  Future<void> addDailyCharge({
    required String id,
    required String label,
    required double amount,
    required String createdBy,
    String note = '',
  }) async {
    await _db.collection('daily_charges').doc(id).set({
      'id':        id,
      'label':     label,
      'amount':    amount,
      'note':      note,
      'date':      FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });
    debugPrint('[FirebaseService] Charge ajoutée : $label ($amount)');
  }

  Future<void> removeDailyCharge(String id) async {
    await _db.collection('daily_charges').doc(id).delete();
    debugPrint('[FirebaseService] Charge supprimée : $id');
  }

  // =================== RECEIPTS ===================

  /// Sauvegarde un reçu (encaissement ou règlement) dans Firestore
  /// Collection : receipts/{receiptId}
  Future<void> saveReceipt({
    required String receiptId,
    required String type,         // 'encaissement' ou 'reglement'
    required String orderId,
    required int orderNumber,
    required double amount,
    required String paymentMethod,
    required String createdBy,
    String? receiptNumber,
    String? settlementNumber,
  }) async {
    await _db.collection('receipts').doc(receiptId).set({
      'id': receiptId,
      'type': type,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      if (receiptNumber != null) 'receiptNumber': receiptNumber,
      if (settlementNumber != null) 'settlementNumber': settlementNumber,
    });
  }

  /// Met à jour les flags d'impression sur la commande
  Future<void> updateOrderPrintStatus({
    required String orderId,
    bool? receiptPrinted,
    bool? settlementPrinted,
  }) async {
    final updates = <String, dynamic>{};
    if (receiptPrinted != null) updates['receiptPrinted'] = receiptPrinted;
    if (settlementPrinted != null) updates['settlementPrinted'] = settlementPrinted;
    if (updates.isNotEmpty) {
      await _db.collection('orders').doc(orderId).update(updates);
    }
  }

  // =================== CAISSE 2 ÉTAPES ===================

  /// ÉTAPE 1 — Encaissement provisoire.
  /// cashStatus → awaiting_payment, crée doc dans cashout_invoices
  Future<void> cashoutOrder({
    required String orderId,
    required String cashoutInvoiceNumber,
    required String cashierId,
    required String cashierName,
    required double amountDue,
    required double discount,
    required List<Map<String, dynamic>> items,
    required int orderNumber,
    required String tableNumber,
    String? serverName,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Mettre à jour la commande
    await _db.collection('orders').doc(orderId).update({
      'cashStatus': CashStatus.awaiting_payment.index,
      'cashoutInvoiceGenerated': true,
      'cashoutInvoiceNumber': cashoutInvoiceNumber,
      'cashoutAt': nowMs,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'discount': discount,
    });

    // 2. Créer le document dans cashout_invoices
    await _db.collection('cashout_invoices').doc(cashoutInvoiceNumber).set({
      'id': cashoutInvoiceNumber,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'serverName': serverName,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'amountDue': amountDue,
      'discount': discount,
      'items': items,
      'status': 'provisoire',
      'createdAt': FieldValue.serverTimestamp(),
      'cashoutAtMs': nowMs,
    });

    debugPrint('[FirebaseService] Encaissement ordre $orderId => $cashoutInvoiceNumber');
  }

  /// ÉTAPE 2 — Règlement définitif.
  /// cashStatus → paid, isPaid = true, crée docs dans settlement_invoices + cash_reports
  Future<void> settleOrder({
    required String orderId,
    required String settlementInvoiceNumber,
    required String cashoutInvoiceNumber,
    required String cashierId,
    required String cashierName,
    required String paymentMethod,
    required double amountDue,
    required double amountPaid,
    required double changeAmount,
    required int orderNumber,
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String? serverName,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Mettre à jour la commande (définitivement payée)
    await _db.collection('orders').doc(orderId).update({
      'cashStatus': CashStatus.paid.index,
      'settlementInvoiceGenerated': true,
      'settlementInvoiceNumber': settlementInvoiceNumber,
      'settledAt': nowMs,
      'isPaid': true,
      'paymentStatus': 'paid',           // ← requis par Point de Caisse
      'settlementStatus': 'completed',   // ← requis par Point de Caisse
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
      'changeAmount': changeAmount,
      'servedAt': nowMs,
      'status': OrderStatus.served.index,
    });

    // 2. Créer le document dans settlement_invoices
    await _db.collection('settlement_invoices').doc(settlementInvoiceNumber).set({
      'id': settlementInvoiceNumber,
      'cashoutInvoiceNumber': cashoutInvoiceNumber,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'serverName': serverName,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'paymentMethod': paymentMethod,
      'amountDue': amountDue,
      'amountPaid': amountPaid,
      'changeAmount': changeAmount,
      'items': items,
      'status': 'definitif',
      'createdAt': FieldValue.serverTimestamp(),
      'settledAtMs': nowMs,
    });

    // 3. Créer une entrée dans cash_reports (point de caisse)
    final reportId = 'CR-$settlementInvoiceNumber';
    await _db.collection('cash_reports').doc(reportId).set({
      'id': reportId,
      'settlementInvoiceNumber': settlementInvoiceNumber,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'paymentMethod': paymentMethod,
      'amount': amountDue,
      'amountPaid': amountPaid,
      'changeAmount': changeAmount,
      'type': 'encaissement_client',
      'createdAt': FieldValue.serverTimestamp(),
      'settledAtMs': nowMs,
    });

    debugPrint('[FirebaseService] Règlement ordre $orderId => $settlementInvoiceNumber');
  }
}
