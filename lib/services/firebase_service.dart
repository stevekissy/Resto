import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:uuid/uuid.dart';
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

  // ─────────────────────────────────────────────────────────────────
  // CAS 1 — Personnel sans accès : Firestore uniquement, pas de Auth.
  // ─────────────────────────────────────────────────────────────────
  Future<AppUser> addStaffOnly({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required bool isActive,
    required String createdBy,
  }) async {
    final uid = _db.collection('users').doc().id;
    await _db.collection('users').doc(uid).set({
      'id': uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.index,
      'active': isActive,
      'isActive': isActive,     // rétrocompatibilité
      'canLogin': false,
      'hasAppAccess': false,    // rétrocompatibilité
      'isOnline': false,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[FirebaseService] ✅ Personnel Firestore-only : $email ($uid)');
    return AppUser(
      id: uid, name: name.trim(), email: email.trim(),
      phone: phone.trim(), role: role,
      isActive: isActive, canLogin: false, createdBy: createdBy,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // CAS 2 — Utilisateur avec accès : Auth-first PUIS Firestore.
  // Auth échoue → exception propagée, aucun doc Firestore créé.
  // ─────────────────────────────────────────────────────────────────
  Future<AppUser> createUserWithAuth({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required bool isActive,
    required String createdBy,
  }) async {
    // ÉTAPE 1 — Firebase Authentication
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    // ÉTAPE 2 — Document Firestore (uid Firebase comme ID)
    await _db.collection('users').doc(uid).set({
      'id': uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.index,
      'active': isActive,
      'isActive': isActive,     // rétrocompatibilité
      'canLogin': true,
      'hasAppAccess': true,     // rétrocompatibilité
      'isOnline': false,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[FirebaseService] ✅ Utilisateur Auth+Firestore : $email ($uid)');
    return AppUser(
      id: uid, name: name.trim(), email: email.trim(),
      phone: phone.trim(), role: role,
      isActive: isActive, canLogin: true, createdBy: createdBy,
    );
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
    // "active" prioritaire sur "isActive" (nouveaux docs)
    isActive: (d['active'] as bool?) ?? (d['isActive'] as bool?) ?? true,
    isOnline: d['isOnline'] as bool? ?? false,
    // "canLogin" prioritaire sur "hasAppAccess" (nouveaux docs)
    canLogin: (d['canLogin'] as bool?) ?? (d['hasAppAccess'] as bool?) ?? false,
    createdBy: d['createdBy'] as String? ?? '',
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
          return Product.fromMap({'id': d.id, ...d.data()});
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
          // Ignorer les items soft-deleted (active == false)
          final active = data['active'] as bool? ?? true;
          if (!active) return null;
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
            active: true,
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

  /// Soft-delete : marque l'item inactive sans supprimer le document
  Future<void> softDeleteStockItem(String itemId, String deletedByName) async {
    await _db.collection('stock').doc(itemId).update({
      'active': false,
      'deletedAt': DateTime.now().millisecondsSinceEpoch,
      'deletedBy': deletedByName,
    });
  }

  // =================== STOCK CATEGORIES ===================

  Future<List<String>> fetchStockCategories() async {
    final snap = await _db.collection('stock_categories').orderBy('name').get();
    if (snap.docs.isEmpty) return [];
    return snap.docs.map((d) => (d.data()['name'] as String? ?? '')).where((n) => n.isNotEmpty).toList();
  }

  Future<void> addStockCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // Utilise le nom en minuscule comme id pour éviter les doublons
    final id = trimmed.toLowerCase().replaceAll(' ', '_');
    await _db.collection('stock_categories').doc(id).set({'name': trimmed, 'id': id});
  }

  Future<void> updateStockCategory(String oldName, String newName) async {
    final oldId = oldName.trim().toLowerCase().replaceAll(' ', '_');
    final newId = newName.trim().toLowerCase().replaceAll(' ', '_');
    await _db.collection('stock_categories').doc(oldId).delete();
    await _db.collection('stock_categories').doc(newId).set({'name': newName.trim(), 'id': newId});
  }

  Future<void> deleteStockCategory(String name) async {
    final id = name.trim().toLowerCase().replaceAll(' ', '_');
    await _db.collection('stock_categories').doc(id).delete();
  }

  // =================== STOCK MOVEMENTS ===================

  /// Enregistre un mouvement dans la collection stock_movements.
  Future<void> addStockMovement(StockMovement movement) async {
    await _db
        .collection('stock_movements')
        .doc(movement.id)
        .set(movement.toMap());
  }

  // =================== STOCK DEDUCTION (Transaction Firestore) ===================

  /// Vérifie si le stock est suffisant pour une liste d'articles.
  /// Retourne la liste des noms de produits stock en rupture.
  Future<List<String>> checkStockAvailability({
    required List<OrderItem> items,
    required List<Product> products,
  }) async {
    final Map<String, double> needed = {};

    for (final item in items) {
      final product = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: '', name: '', category: '', price: 0, prepTime: 0,
        ),
      );
      for (final link in product.stockLinks) {
        needed[link.stockItemId] =
            (needed[link.stockItemId] ?? 0) +
            link.quantityUsed * item.quantity;
      }
    }

    if (needed.isEmpty) return [];

    final List<String> insufficient = [];
    for (final entry in needed.entries) {
      final doc = await _db.collection('stock').doc(entry.key).get();
      if (!doc.exists) {
        insufficient.add(entry.key);
        continue;
      }
      final current =
          (doc.data()?['currentQuantity'] as num?)?.toDouble() ?? 0;
      if (current < entry.value) {
        insufficient.add(
            doc.data()?['name'] as String? ?? entry.key);
      }
    }
    return insufficient;
  }

  /// Déduit le stock pour une liste d'articles de commande.
  /// Utilise une transaction Firestore pour chaque produit stock touché.
  /// Enregistre aussi les mouvements dans stock_movements.
  Future<void> deductStockForOrder({
    required Order order,
    required List<Product> products,
    required String createdBy,
  }) async {
    // Consolider les besoins par stockItemId
    final Map<String, _StockNeed> needs = {};

    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: '', name: '', category: '', price: 0, prepTime: 0,
        ),
      );
      for (final link in product.stockLinks) {
        final qty = link.quantityUsed * item.quantity;
        if (needs.containsKey(link.stockItemId)) {
          needs[link.stockItemId]!.quantity += qty;
        } else {
          needs[link.stockItemId] = _StockNeed(
            stockItemId: link.stockItemId,
            stockItemName: link.stockItemName,
            quantity: qty,
            unit: link.unit,
            menuId: item.productId,
            menuName: item.productName,
          );
        }
      }
    }

    if (needs.isEmpty) return;

    // Transaction Firestore pour chaque produit stock
    for (final need in needs.values) {
      final ref = _db.collection('stock').doc(need.stockItemId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final current =
            (snap.data()?['currentQuantity'] as num?)?.toDouble() ?? 0;
        final newQty = (current - need.quantity).clamp(0.0, double.infinity);
        tx.update(ref, {
          'currentQuantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Enregistrer le mouvement
      final movId = _db.collection('stock_movements').doc().id;
      await addStockMovement(StockMovement(
        id: movId,
        stockItemId: need.stockItemId,
        stockItemName: need.stockItemName,
        type: StockMovementType.sortieAutomatiqueCommande,
        quantity: need.quantity,
        unit: need.unit,
        orderId: order.id,
        menuId: need.menuId,
        menuName: need.menuName,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ));
    }
  }

  /// Remet en stock les produits d’une commande annulée.
  Future<void> restoreStockForOrder({
    required Order order,
    required List<Product> products,
    required String createdBy,
  }) async {
    final Map<String, _StockNeed> needs = {};

    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: '', name: '', category: '', price: 0, prepTime: 0,
        ),
      );
      for (final link in product.stockLinks) {
        final qty = link.quantityUsed * item.quantity;
        if (needs.containsKey(link.stockItemId)) {
          needs[link.stockItemId]!.quantity += qty;
        } else {
          needs[link.stockItemId] = _StockNeed(
            stockItemId: link.stockItemId,
            stockItemName: link.stockItemName,
            quantity: qty,
            unit: link.unit,
            menuId: item.productId,
            menuName: item.productName,
          );
        }
      }
    }

    if (needs.isEmpty) return;

    for (final need in needs.values) {
      final ref = _db.collection('stock').doc(need.stockItemId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final current =
            (snap.data()?['currentQuantity'] as num?)?.toDouble() ?? 0;
        tx.update(ref, {
          'currentQuantity': current + need.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final movId = _db.collection('stock_movements').doc().id;
      await addStockMovement(StockMovement(
        id: movId,
        stockItemId: need.stockItemId,
        stockItemName: need.stockItemName,
        type: StockMovementType.retourAnnulationCommande,
        quantity: need.quantity,
        unit: need.unit,
        orderId: order.id,
        menuId: need.menuId,
        menuName: need.menuName,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ));
    }
  }

  /// Ajuste le stock lors d’une modification de commande.
  /// Compare l’ancienne et la nouvelle liste d’articles et calcule le delta.
  Future<void> adjustStockForOrderUpdate({
    required Order oldOrder,
    required List<OrderItem> newItems,
    required List<Product> products,
    required String createdBy,
  }) async {
    // Calculer delta par stockItemId (positif = remettre, négatif = déduire)
    final Map<String, _StockDelta> deltas = {};

    void accumulate(List<OrderItem> items, double sign) {
      for (final item in items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: '', name: '', category: '', price: 0, prepTime: 0,
          ),
        );
        for (final link in product.stockLinks) {
          final qty = link.quantityUsed * item.quantity * sign;
          if (deltas.containsKey(link.stockItemId)) {
            deltas[link.stockItemId]!.delta += qty;
          } else {
            deltas[link.stockItemId] = _StockDelta(
              stockItemId: link.stockItemId,
              stockItemName: link.stockItemName,
              delta: qty,
              unit: link.unit,
              menuId: item.productId,
              menuName: item.productName,
            );
          }
        }
      }
    }

    accumulate(oldOrder.items, 1);   // remettre les anciens
    accumulate(newItems, -1);         // déduire les nouveaux

    for (final d in deltas.values) {
      if (d.delta.abs() < 0.001) continue; // pas de changement

      final ref = _db.collection('stock').doc(d.stockItemId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final current =
            (snap.data()?['currentQuantity'] as num?)?.toDouble() ?? 0;
        final newQty = (current + d.delta).clamp(0.0, double.infinity);
        tx.update(ref, {
          'currentQuantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final movId = _db.collection('stock_movements').doc().id;
      await addStockMovement(StockMovement(
        id: movId,
        stockItemId: d.stockItemId,
        stockItemName: d.stockItemName,
        type: StockMovementType.ajustementModificationCommande,
        quantity: d.delta.abs(),
        unit: d.unit,
        orderId: oldOrder.id,
        menuId: d.menuId,
        menuName: d.menuName,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ));
    }
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
    // On ne filtre PAS active==true ici pour éviter un index composite ;
    // le provider filtre en mémoire.
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
            productOrService: data['productOrService'] as String?,
            active: data['active'] as bool? ?? true,
            deletedAt: _toDateTimeNullable(data['deletedAt']),
            deletedBy: data['deletedBy'] as String?,
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

  /// Soft-delete : marque active=false si le fournisseur a des commandes liées.
  Future<void> softDeleteSupplier(String supplierId, String deletedBy) async {
    await _db.collection('suppliers').doc(supplierId).update({
      'active': false,
      'deletedAt': DateTime.now().millisecondsSinceEpoch,
      'deletedBy': deletedBy,
    });
  }

  /// Hard-delete : suppression définitive (uniquement si aucune commande liée).
  Future<void> hardDeleteSupplier(String supplierId) async {
    await _db.collection('suppliers').doc(supplierId).delete();
  }

  /// Vérifie si un fournisseur a des commandes liées.
  Future<bool> supplierHasOrders(String supplierId) async {
    final snap = await _db
        .collection('supplierOrders')
        .where('supplierId', isEqualTo: supplierId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // =================== SUPPLIER ORDERS ===================
  // PAS de .orderBy() → tri en mémoire

  Stream<List<SupplierOrder>> streamSupplierOrders() {
    return _db.collection('supplierOrders').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          return SupplierOrder.fromMap({'id': d.id, ...d.data()});
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

  // =================== SUPPLIER PAYMENTS ===================

  /// Stream de tous les paiements (triés par date décroissante en mémoire).
  Stream<List<SupplierPayment>> streamSupplierPayments() {
    return _db.collection('supplier_payments').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        try {
          return SupplierPayment.fromMap({'id': d.id, ...d.data()});
        } catch (e) {
          debugPrint('[stream.supplier_payments] doc ${d.id}: $e');
          return null;
        }
      }).whereType<SupplierPayment>().toList();
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return list;
    });
  }

  /// Sauvegarde un paiement ET recalcule paidAmount/remainingAmount/status sur la commande.
  Future<void> addSupplierPayment({
    required SupplierPayment payment,
    required SupplierOrder order,
  }) async {
    final batch = _db.batch();

    // 1. Créer le document paiement
    batch.set(
      _db.collection('supplier_payments').doc(payment.id),
      payment.toMap(),
    );

    // 2. Recalculer la commande
    final newPaid = (order.paidAmount + payment.amount)
        .clamp(0, order.totalAmount);
    final newRemaining = order.totalAmount - newPaid;
    final SupplierPaymentStatus newStatus;
    if (newRemaining <= 0) {
      newStatus = SupplierPaymentStatus.paid;
    } else if (newPaid > 0) {
      newStatus = SupplierPaymentStatus.partial;
    } else {
      newStatus = SupplierPaymentStatus.unpaid;
    }

    batch.update(
      _db.collection('supplierOrders').doc(order.id),
      {
        'paidAmount': newPaid,
        'remainingAmount': newRemaining,
        'paymentStatus': newStatus.name,
        'paymentMethod': payment.paymentMethod,
      },
    );

    await batch.commit();
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

  // =====================================================================
  // PERMISSIONS PAR RÔLE — collection role_permissions
  // Doc ID = nom du rôle (ex: "admin", "cashier", "gestionnaire_stock")
  // =====================================================================

  /// Retourne le nom Firestore d'un rôle
  static String roleDocId(UserRole role) {
    switch (role) {
      case UserRole.admin:        return 'admin';
      case UserRole.manager:      return 'manager';
      case UserRole.cashier:      return 'caissier';
      case UserRole.kitchen:      return 'cuisine';
      case UserRole.server:       return 'serveur';
      case UserRole.stockManager: return 'gestionnaire_stock';
    }
  }

  /// Permissions par défaut (fallback si document absent dans Firestore)
  static Map<String, bool> defaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return {
          'dashboard': true, 'orders': true, 'kitchen': true, 'cashier': true,
          'stock': true, 'personnel': true, 'messages': true, 'statistics': true,
          'suppliers': true, 'productManagement': true, 'adminManagement': true,
        };
      case UserRole.manager:
        return {
          'dashboard': true, 'orders': true, 'kitchen': true, 'cashier': true,
          'stock': true, 'personnel': true, 'messages': true, 'statistics': true,
          'suppliers': true, 'productManagement': true, 'adminManagement': false,
        };
      case UserRole.cashier:
        return {
          'dashboard': true, 'orders': true, 'kitchen': false, 'cashier': true,
          'stock': false, 'personnel': false, 'messages': true, 'statistics': false,
          'suppliers': false, 'productManagement': false, 'adminManagement': false,
        };
      case UserRole.kitchen:
        return {
          'dashboard': true, 'orders': false, 'kitchen': true, 'cashier': false,
          'stock': true, 'personnel': false, 'messages': true, 'statistics': false,
          'suppliers': false, 'productManagement': false, 'adminManagement': false,
        };
      case UserRole.server:
        return {
          'dashboard': true, 'orders': true, 'kitchen': false, 'cashier': false,
          'stock': false, 'personnel': false, 'messages': true, 'statistics': false,
          'suppliers': false, 'productManagement': false, 'adminManagement': false,
        };
      case UserRole.stockManager:
        return {
          'dashboard': true, 'orders': false, 'kitchen': false, 'cashier': false,
          'stock': true, 'personnel': false, 'messages': true, 'statistics': false,
          'suppliers': true, 'productManagement': true, 'adminManagement': false,
        };
    }
  }

  /// Stream temps réel sur TOUS les documents role_permissions
  Stream<Map<UserRole, Map<String, bool>>> streamRolePermissions() {
    return _db.collection('role_permissions').snapshots().map((snapshot) {
      final result = <UserRole, Map<String, bool>>{};
      for (final role in UserRole.values) {
        result[role] = Map<String, bool>.from(defaultPermissions(role));
      }
      for (final doc in snapshot.docs) {
        final roleId = doc.id;
        final data = doc.data();
        UserRole? role;
        for (final r in UserRole.values) {
          if (roleDocId(r) == roleId) { role = r; break; }
        }
        if (role == null) continue;
        final perms = Map<String, bool>.from(defaultPermissions(role));
        for (final entry in data.entries) {
          if (entry.value is bool) perms[entry.key] = entry.value as bool;
        }
        result[role] = perms;
      }
      return result;
    });
  }

  /// Sauvegarde UNE permission pour un rôle dans Firestore
  Future<void> saveRolePermission(UserRole role, String module, bool value) async {
    final docId = roleDocId(role);
    await _db.collection('role_permissions').doc(docId).set(
      {module: value},
      SetOptions(merge: true),
    );
    debugPrint('[FirebaseService] Permission $docId.$module = $value');
  }

  /// Charge les permissions d'un rôle (lecture unique)
  Future<Map<String, bool>> loadRolePermissions(UserRole role) async {
    try {
      final doc = await _db.collection('role_permissions').doc(roleDocId(role)).get();
      final defaults = Map<String, bool>.from(defaultPermissions(role));
      if (!doc.exists) return defaults;
      final data = doc.data() ?? {};
      for (final entry in data.entries) {
        if (entry.value is bool) defaults[entry.key] = entry.value as bool;
      }
      return defaults;
    } catch (e) {
      debugPrint('[FirebaseService] loadRolePermissions erreur: $e');
      return Map<String, bool>.from(defaultPermissions(role));
    }
  }

  /// Initialise les documents role_permissions en Firestore (si absents)
  Future<void> initRolePermissions() async {
    for (final role in UserRole.values) {
      final docId = roleDocId(role);
      final ref = _db.collection('role_permissions').doc(docId);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set(defaultPermissions(role));
        debugPrint('[FirebaseService] Permissions initialisées pour $docId');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  APPROVISIONNER STOCK
  // ══════════════════════════════════════════════════════════════════════

  /// Met à jour la quantité d'un article de stock et enregistre le mouvement.
  Future<void> restockItem({
    required String stockItemId,
    required double qty,
    double? purchasePrice,
    String? supplierId,
    String? supplierName,
    String? note,
    required String createdBy,
  }) async {
    final ref = _db.collection('stock').doc(stockItemId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Article stock introuvable');
      final current = (snap.data()!['currentQuantity'] as num?)?.toDouble() ?? 0;
      tx.update(ref, {'currentQuantity': current + qty});
    });
    // Enregistrer le mouvement
    final movId = const Uuid().v4();
    final stockSnap = await ref.get();
    final itemName = stockSnap.data()?['name'] as String? ?? stockItemId;
    final unit     = stockSnap.data()?['unit'] as String? ?? '';
    final movement = StockMovement(
      id: movId,
      stockItemId: stockItemId,
      stockItemName: itemName,
      type: StockMovementType.approvisionnement,
      quantity: qty,
      unit: unit,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      supplierId: supplierId,
      supplierName: supplierName,
      purchasePrice: purchasePrice,
      note: note,
    );
    await _db.collection('stock_movements').doc(movId).set(movement.toMap());
    debugPrint('[FirebaseService] restockItem: +$qty $unit pour $itemName');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  HISTORIQUE FACTURES (CAISSE)
  // ══════════════════════════════════════════════════════════════════════

  /// Stream combiné : cashout_invoices + settlement_invoices
  /// Chaque doc reçoit un champ 'invoiceKind' = 'cashout' | 'settlement'
  /// NOTE: Les champs timestamp réels sont 'cashoutAtMs' et 'settledAtMs' (int ms).
  Stream<List<Map<String, dynamic>>> streamInvoiceHistory() {
    // On utilise un stream simple sur cashout_invoices SANS orderBy
    // pour éviter l'erreur d'index (le champ 'cashoutAt' n'existe pas — c'est 'cashoutAtMs').
    // Le tri se fait en mémoire après fusion.
    return _db
        .collection('cashout_invoices')
        .limit(300)
        .snapshots()
        .asyncMap((cashoutSnap) async {
      // settlement_invoices — également sans orderBy pour éviter index manquant
      final settSnap = await _db
          .collection('settlement_invoices')
          .limit(300)
          .get();

      final list = <Map<String, dynamic>>[];

      for (final doc in cashoutSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['invoiceKind'] = 'cashout';
        d['docId'] = doc.id;
        // Normaliser le timestamp : cashoutAtMs → cashoutAt pour l'UI
        if (d['cashoutAtMs'] != null) {
          d['cashoutAt'] = (d['cashoutAtMs'] as num).toInt();
        } else if (d['cashoutAt'] is int) {
          // déjà bon
        } else {
          d['cashoutAt'] = 0;
        }
        // Normaliser totalAmount (stocké sous amountDue dans cashout_invoices)
        d['totalAmount'] ??= d['amountDue'];
        list.add(d);
      }

      for (final doc in settSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['invoiceKind'] = 'settlement';
        d['docId'] = doc.id;
        // Normaliser le timestamp : settledAtMs → settledAt pour l'UI
        if (d['settledAtMs'] != null) {
          d['settledAt'] = (d['settledAtMs'] as num).toInt();
        } else if (d['settledAt'] is int) {
          // déjà bon
        } else {
          d['settledAt'] = 0;
        }
        // Normaliser totalAmount (stocké sous amountDue dans settlement_invoices)
        d['totalAmount'] ??= d['amountDue'];
        list.add(d);
      }

      // Trier par date décroissante (champs normalisés)
      list.sort((a, b) {
        final ta = _invoiceTimestamp(a);
        final tb = _invoiceTimestamp(b);
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// Extrait le timestamp ms d'une facture (cashout ou settlement)
  int _invoiceTimestamp(Map<String, dynamic> inv) {
    final v = inv['settledAt'] ?? inv['cashoutAt'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  APPELS TEMPS RÉEL
  // ══════════════════════════════════════════════════════════════════════

  /// Crée un document d'appel dans la collection `calls`.
  Future<String> initiateCall({
    required String callerId,
    required String callerName,
    String? calleeId,
    String? calleeName,
    bool isConference = false,
  }) async {
    final callId = const Uuid().v4();
    final session = CallSession(
      id: callId,
      callerId: callerId,
      callerName: callerName,
      calleeId: calleeId,
      calleeName: calleeName,
      isConference: isConference,
      status: CallStatus.calling,
      createdAt: DateTime.now(),
    );
    await _db.collection('calls').doc(callId).set(session.toMap());
    // Ajouter l'appelant comme premier participant
    final pId = const Uuid().v4();
    final participant = CallParticipant(
      id: pId,
      callId: callId,
      userId: callerId,
      userName: callerName,
      joinedAt: DateTime.now(),
    );
    await _db
        .collection('calls')
        .doc(callId)
        .collection('call_participants')
        .doc(pId)
        .set(participant.toMap());
    return callId;
  }

  /// Stream sur l'appel entrant pour un utilisateur donné.
  /// Retourne le premier appel actif (status = calling | ringing) destiné à cet utilisateur.
  Stream<CallSession?> streamIncomingCall(String userId) {
    return _db
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .where('status', whereIn: ['calling', 'ringing'])
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return CallSession.fromMap(snap.docs.first.data());
        });
  }

  /// Met à jour le statut d'un appel.
  Future<void> updateCallStatus(String callId, CallStatus status) async {
    final data = <String, dynamic>{'status': status.name};
    if (status == CallStatus.accepted) data['answeredAt'] = DateTime.now().millisecondsSinceEpoch;
    if (status == CallStatus.ended || status == CallStatus.rejected || status == CallStatus.missed) {
      data['endedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    await _db.collection('calls').doc(callId).update(data);
  }

  /// Ajoute un participant à une conférence et met à jour son statut.
  Future<void> joinConference(String callId, String userId, String userName) async {
    final pId = const Uuid().v4();
    final participant = CallParticipant(
      id: pId,
      callId: callId,
      userId: userId,
      userName: userName,
      joinedAt: DateTime.now(),
    );
    await _db
        .collection('calls')
        .doc(callId)
        .collection('call_participants')
        .doc(pId)
        .set(participant.toMap());
    // Mettre à jour le statut global si nécessaire
    await _db.collection('calls').doc(callId).update({'status': CallStatus.accepted.name});
  }

  /// Stream sur les participants d'un appel (conférence)
  Stream<List<CallParticipant>> streamCallParticipants(String callId) {
    return _db
        .collection('calls')
        .doc(callId)
        .collection('call_participants')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CallParticipant.fromMap(d.data()))
            .toList());
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CATÉGORIES FIRESTORE (persistance)
  // ══════════════════════════════════════════════════════════════════════

  /// Stream des catégories depuis Firestore
  Stream<List<String>> streamCategories() {
    return _db
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data()['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList());
  }

  /// Ajoute une catégorie dans Firestore
  Future<void> addCategoryFirestore(String name) async {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    await _db.collection('categories').doc(id).set({'name': name, 'id': id});
  }

  /// Supprime une catégorie de Firestore
  Future<void> deleteCategoryFirestore(String name) async {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    await _db.collection('categories').doc(id).delete();
  }

  /// Renomme une catégorie dans Firestore
  Future<void> renameCategoryFirestore(String oldName, String newName) async {
    final oldId = oldName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final newId = newName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final batch = _db.batch();
    batch.delete(_db.collection('categories').doc(oldId));
    batch.set(_db.collection('categories').doc(newId), {'name': newName, 'id': newId});
    await batch.commit();
  }

  /// Initialise les catégories par défaut si la collection est vide
  Future<void> initDefaultCategories(List<String> defaults) async {
    final snap = await _db.collection('categories').limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final name in defaults) {
      final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      batch.set(_db.collection('categories').doc(id), {'name': name, 'id': id});
    }
    await batch.commit();
  }
}

// ── Helpers privés pour les transactions stock ─────────────────────────────
class _StockNeed {
  final String stockItemId;
  final String stockItemName;
  double quantity;
  final String unit;
  final String menuId;
  final String menuName;

  _StockNeed({
    required this.stockItemId,
    required this.stockItemName,
    required this.quantity,
    required this.unit,
    required this.menuId,
    required this.menuName,
  });
}

class _StockDelta {
  final String stockItemId;
  final String stockItemName;
  double delta;
  final String unit;
  final String menuId;
  final String menuName;

  _StockDelta({
    required this.stockItemId,
    required this.stockItemName,
    required this.delta,
    required this.unit,
    required this.menuId,
    required this.menuName,
  });
}
