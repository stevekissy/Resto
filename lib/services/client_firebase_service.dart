import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/client_models.dart';
import '../models/models.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT FIREBASE SERVICE
// Gère toutes les opérations Firestore liées à l'espace client
// Collections :
//   clients             → profils clients
//   client_orders       → commandes en ligne
//   client_addresses    → adresses livraison
//   loyalty_transactions → historique points
//   promotions          → offres promotionnelles
//   online_settings     → configuration commandes en ligne (doc unique)
// ═══════════════════════════════════════════════════════════════════════════

class ClientFirebaseService {
  static final ClientFirebaseService _instance = ClientFirebaseService._();
  factory ClientFirebaseService() => _instance;
  ClientFirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // ── Authentification ───────────────────────────────────────────────────

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) => _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  User? get currentAuthUser => _auth.currentUser;

  // ── Profil client ──────────────────────────────────────────────────────

  Future<void> createClientProfile(ClientUser client) async {
    // 1. Profil dans la collection dédiée `clients`
    await _db.collection('clients').doc(client.id).set(client.toMap());

    // 2. Document dans `users` avec role=client (index 6) pour accès unifié
    //    Permet à loginWithFirebase de détecter et bloquer l'accès staff.
    await _db.collection('users').doc(client.id).set({
      'id': client.id,
      'name': client.name,
      'email': client.email,
      'phone': client.phone,
      'role': 6, // UserRole.client.index
      'accountType': 'customer',
      'active': true,
      'isActive': true,
      'canLogin': true,
      'hasAppAccess': false,  // pas d'accès à l'interface staff
      'createdBy': 'self_registration',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ClientUser?> getClientProfile(String uid) async {
    try {
      final doc = await _db.collection('clients').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return ClientUser.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<ClientUser?> streamClientProfile(String uid) {
    return _db.collection('clients').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ClientUser.fromMap(snap.data()!);
    });
  }

  Future<void> updateClientProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('clients').doc(uid).update(data);
  }

  Future<void> updateLastLogin(String uid) async {
    await _db.collection('clients').doc(uid).update({
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Vérification si UID est un client ────────────────────────────────────

  /// Vérifie par UID (doc Firestore `clients/{uid}`) — plus rapide et fiable.
  Future<bool> isClientUser(String uid) async {
    try {
      final doc = await _db.collection('clients').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── Vérification si email est déjà client ──────────────────────────────

  Future<bool> isClientEmail(String email) async {
    try {
      final snap = await _db.collection('clients')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Adresses de livraison ──────────────────────────────────────────────

  Stream<List<DeliveryAddress>> streamAddresses(String clientId) {
    return _db
        .collection('client_addresses')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DeliveryAddress.fromMap(d.data()))
            .toList()
          ..sort((a, b) => b.isDefault ? 1 : -1));
  }

  Future<String> addAddress(String clientId, DeliveryAddress address) async {
    final id = _uuid.v4();
    final data = address.toMap();
    data['id'] = id;
    data['clientId'] = clientId;
    // Si marquée par défaut, enlever le défaut des autres
    if (address.isDefault) {
      await _clearDefaultAddress(clientId);
    }
    await _db.collection('client_addresses').doc(id).set(data);
    return id;
  }

  Future<void> updateAddress(DeliveryAddress address) async {
    await _db.collection('client_addresses').doc(address.id).update(address.toMap());
  }

  Future<void> deleteAddress(String addressId) async {
    await _db.collection('client_addresses').doc(addressId).delete();
  }

  Future<void> setDefaultAddress(String clientId, String addressId) async {
    await _clearDefaultAddress(clientId);
    await _db.collection('client_addresses').doc(addressId).update({'isDefault': true});
  }

  Future<void> _clearDefaultAddress(String clientId) async {
    final snap = await _db.collection('client_addresses')
        .where('clientId', isEqualTo: clientId)
        .where('isDefault', isEqualTo: true)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'isDefault': false});
    }
  }

  // ── Commandes client ───────────────────────────────────────────────────

  Stream<List<ClientOrder>> streamClientOrders(String clientId) {
    return _db
        .collection('client_orders')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) {
      final orders = snap.docs
          .map((d) => ClientOrder.fromMap(d.data()))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<List<ClientOrder>> streamAllOnlineOrders() {
    return _db
        .collection('client_orders')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClientOrder.fromMap(d.data()))
            .toList());
  }

  Future<String> createOrder(ClientOrder order) async {
    final id = _uuid.v4();
    // Générer numéro de commande
    final count = await _getNextOrderNumber();
    final data = order.toMap();
    data['id'] = id;
    data['orderNumber'] = '#${count.toString().padLeft(4, '0')}';
    await _db.collection('client_orders').doc(id).set(data);

    // Créer aussi dans la collection 'orders' pour le tableau de bord cuisine
    await _createInternalOrder(data, id);

    // Mettre à jour les stats client
    await _db.collection('clients').doc(order.clientId).update({
      'totalOrders': FieldValue.increment(1),
      'totalSpent': FieldValue.increment(order.grandTotal),
    });

    return id;
  }

  Future<int> _getNextOrderNumber() async {
    final doc = await _db.collection('online_settings').doc('order_counter').get();
    final current = (doc.data()?['counter'] as num?)?.toInt() ?? 1000;
    await _db.collection('online_settings').doc('order_counter').set({
      'counter': current + 1,
    });
    return current + 1;
  }

  /// Crée une commande miroir dans la collection interne 'orders' de l'app de gestion
  Future<void> _createInternalOrder(Map<String, dynamic> clientOrderData, String clientOrderId) async {
    try {
      final items = (clientOrderData['items'] as List? ?? []).map((i) {
        final m = i as Map<String, dynamic>;
        return {
          'productId': m['productId'],
          'name': m['productName'],
          'price': m['unitPrice'],
          'quantity': m['quantity'],
          'comment': m['comment'] ?? '',
          'categoryName': m['categoryName'] ?? '',
        };
      }).toList();

      final internalOrderId = _uuid.v4();
      final totalAmount = (clientOrderData['totalAmount'] as num?)?.toDouble() ?? 0;
      final deliveryFee = (clientOrderData['deliveryFee'] as num?)?.toDouble() ?? 0;

      final orderType = (clientOrderData['orderType'] as num?)?.toInt() ?? 0;
      final depositAmount = (clientOrderData['depositAmount'] as num?)?.toDouble() ?? 0;
      final loyaltyDiscount = (clientOrderData['loyaltyDiscountAmount'] as num?)?.toDouble() ?? 0;
      final deliveryAddr = clientOrderData['deliveryAddress'] as Map<String, dynamic>?;

      await _db.collection('orders').doc(internalOrderId).set({
        'id': internalOrderId,
        'clientOrderId': clientOrderId,
        'orderNumber': clientOrderData['orderNumber'],
        'tableNumber': orderType == 0 ? 'Livraison Yango' : 'À Emporter',
        'serverName': clientOrderData['clientName'] ?? '',
        'items': items,
        'status': 'pending',
        'totalAmount': totalAmount,
        'discount': loyaltyDiscount,
        'cashStatus': depositAmount > 0 ? 'deposit_received' : 'pending_cashout',
        'notes': clientOrderData['notes'] ?? '',
        'createdAt': clientOrderData['createdAt'],
        // Source et identification commande en ligne
        'source': 'online',
        'orderSource': 'online',
        'clientId': clientOrderData['clientId'],
        'clientName': clientOrderData['clientName'],
        'clientPhone': clientOrderData['clientPhone'],
        // Adresse livraison
        'deliveryAddress': deliveryAddr?['address'] ?? '',
        'geoLocation': clientOrderData['geoLocation'],
        // Acompte
        'depositRequired': clientOrderData['depositRequired'] ?? true,
        'depositAmount': depositAmount,
        'depositPaid': clientOrderData['depositPaid'] ?? false,
        'paymentMethod': clientOrderData['paymentMethod'],
        'paymentStatus': clientOrderData['paymentStatus'],
        // Points fidélité
        'loyaltyPointsUsed': clientOrderData['loyaltyPointsUsed'] ?? 0,
        'loyaltyDiscountAmount': loyaltyDiscount,
        // Yango delivery
        'deliveryPartner': 'Yango',
        'deliveryFeePaidTo': 'driver',
        'deliveryFeeIncluded': false,
        'deliveryNote': clientOrderData['deliveryNote'],
        'yangoStatus': 0,  // YangoDeliveryStatus.waiting
        'remainingAmount': clientOrderData['remainingAmount'],
        'kitchenStatus': 'pending',
      });

      // Mettre à jour clientOrderData avec l'id interne
      await _db.collection('client_orders').doc(clientOrderId).update({
        'internalOrderId': internalOrderId,
      });

      // ── Notification admin/cuisine Firestore ────────────────────────
      // Écrite dans la collection 'notifications' pour que l'admin la voie
      // même s'il se connecte après la commande (persistant).
      try {
        final notifId = _uuid.v4();
        final clientName = clientOrderData['clientName'] as String? ?? 'Client';
        final orderNum   = clientOrderData['orderNumber'] as String? ?? '';
        await _db.collection('notifications').doc(notifId).set({
          'id': notifId,
          'type': 'online_order',
          'title': 'Nouvelle commande en ligne',
          'message': 'NOUVELLE COMMANDE EN LIGNE $orderNum — $clientName à traiter',
          'orderId': internalOrderId,
          'clientOrderId': clientOrderId,
          'clientId': clientOrderData['clientId'],
          'clientName': clientName,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'targetRoles': ['admin', 'manager', 'kitchen', 'cashier'],
        });
      } catch (e) {
        debugPrintOrder('Erreur création notification admin: $e');
      }
      // ────────────────────────────────────────────────────────────────

    } catch (e) {
      // Non bloquant — la commande client a déjà été créée
      debugPrintOrder('Erreur création commande interne: $e');
    }
  }

  // ignore: avoid_print
  void debugPrintOrder(String msg) {}

  Future<void> updateOrderStatus(String orderId, ClientOrderStatus status) async {
    await _db.collection('client_orders').doc(orderId).update({
      'status': status.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await _db.collection('client_orders').doc(orderId).update({
      'status': ClientOrderStatus.cancelled.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateYangoStatus(String orderId, YangoDeliveryStatus yangoStatus) async {
    await _db.collection('client_orders').doc(orderId).update({
      'yangoStatus': yangoStatus.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Mettre à jour aussi dans la collection orders principale
    try {
      final snap = await _db.collection('orders')
          .where('clientOrderId', isEqualTo: orderId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'yangoStatus': yangoStatus.index,
          'yangoStatusLabel': yangoStatus.label,
        });
      }
    } catch (_) {}
  }

  // ── Paramètres commandes en ligne ──────────────────────────────────────

  Stream<OnlineOrderSettings> streamOnlineSettings() {
    return _db
        .collection('online_settings')
        .doc('config')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return OnlineOrderSettings.defaults;
      return OnlineOrderSettings.fromMap(snap.data()!);
    });
  }

  Future<OnlineOrderSettings> getOnlineSettings() async {
    final doc = await _db.collection('online_settings').doc('config').get();
    if (!doc.exists || doc.data() == null) return OnlineOrderSettings.defaults;
    return OnlineOrderSettings.fromMap(doc.data()!);
  }

  Future<void> saveOnlineSettings(OnlineOrderSettings settings) async {
    await _db.collection('online_settings').doc('config').set(settings.toMap());
  }

  // ── Promotions ─────────────────────────────────────────────────────────

  Stream<List<Promotion>> streamActivePromotions() {
    return _db
        .collection('promotions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map((d) => Promotion.fromMap(d.data()))
          .where((p) => p.validUntil == null || p.validUntil!.isAfter(now))
          .toList();
    });
  }

  Stream<List<Promotion>> streamAllPromotions() {
    return _db.collection('promotions').snapshots().map((snap) =>
        snap.docs.map((d) => Promotion.fromMap(d.data())).toList());
  }

  Future<String> addPromotion(Promotion promo) async {
    final id = _uuid.v4();
    final data = promo.toMap();
    data['id'] = id;
    await _db.collection('promotions').doc(id).set(data);
    return id;
  }

  Future<void> updatePromotion(Promotion promo) async {
    await _db.collection('promotions').doc(promo.id).update(promo.toMap());
  }

  Future<void> deletePromotion(String promoId) async {
    await _db.collection('promotions').doc(promoId).delete();
  }

  // ── Programme fidélité ─────────────────────────────────────────────────

  Stream<List<LoyaltyTransaction>> streamLoyaltyHistory(String clientId) {
    return _db
        .collection('loyalty_transactions')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) {
      final txs = snap.docs
          .map((d) => LoyaltyTransaction.fromMap(d.data()))
          .toList();
      txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return txs;
    });
  }

  Future<void> addLoyaltyTransaction(LoyaltyTransaction tx) async {
    final id = _uuid.v4();
    final data = tx.toMap();
    data['id'] = id;
    await _db.collection('loyalty_transactions').doc(id).set(data);
    // Mettre à jour le solde points du client
    final delta = tx.type == LoyaltyType.redeem ? -tx.points : tx.points;
    await _db.collection('clients').doc(tx.clientId).update({
      'loyaltyPoints': FieldValue.increment(delta),
    });
  }

  // ── Attribution sécurisée des points fidélité (après paiement) ────────
  //
  // Règle : les points ne sont attribués QU'UNE SEULE FOIS, uniquement
  // après livraison/paiement complet. Le champ loyaltyPointsAwarded
  // garantit l'idempotence (pas de double crédit si appelé deux fois).
  //
  // Appelé par updateOrderStatus() quand newStatus == delivered.
  Future<void> awardLoyaltyPoints({
    required String clientOrderId,
    required String clientId,
    required int pointsToAward,
  }) async {
    if (pointsToAward <= 0) return;

    // Vérification idempotence : ne pas re-créditer si déjà attribués
    final orderDoc = await _db.collection('client_orders').doc(clientOrderId).get();
    if (!orderDoc.exists) return;
    final alreadyAwarded = orderDoc.data()?['loyaltyPointsAwarded'] as bool? ?? false;
    if (alreadyAwarded) {
      debugPrintOrder('[loyalty] Points déjà attribués pour $clientOrderId — skip');
      return;
    }

    // Marquer l'ordre AVANT d'écrire la transaction (protection crash)
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.collection('client_orders').doc(clientOrderId).update({
      'loyaltyPointsAwarded': true,
      'loyaltyPointsAwardedAt': now,
    });

    // Créer la transaction fidélité
    final txId = _uuid.v4();
    await _db.collection('loyalty_transactions').doc(txId).set({
      'id': txId,
      'clientId': clientId,
      'type': LoyaltyType.earn.index,
      'points': pointsToAward,
      'description': 'Points fidélité — commande livrée',
      'orderId': clientOrderId,
      'createdAt': now,
    });

    // Incrémenter le solde du client
    await _db.collection('clients').doc(clientId).update({
      'loyaltyPoints': FieldValue.increment(pointsToAward),
    });

    debugPrintOrder('[loyalty] ✅ $pointsToAward points attribués → client $clientId');
  }

  // ── Menu produits (lecture seule — collection partagée) ────────────────

  Stream<List<Product>> streamAvailableProducts() {
    return _db.collection('products').snapshots().map((snap) => snap.docs
        .map((d) {
          final data = d.data();
          data['id'] = d.id;
          return Product.fromMap(data);
        })
        .where((p) => p.isAvailable && p.stockQuantity > 0)
        .toList());
  }

  Stream<List<String>> streamCategories() {
    return _db.collection('products').snapshots().map((snap) {
      final cats = snap.docs
          .map((d) => d.data()['category'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return cats;
    });
  }

  // ── Gestion clients (admin) ────────────────────────────────────────────

  Stream<List<ClientUser>> streamAllClients() {
    return _db.collection('clients').snapshots().map((snap) {
      final clients = snap.docs
          .map((d) => ClientUser.fromMap(d.data()))
          .toList();
      clients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return clients;
    });
  }

  Future<void> toggleClientActive(String clientId, bool isActive) async {
    await _db.collection('clients').doc(clientId).update({'isActive': isActive});
  }

  /// Retourne tous les clients sous forme de Map (pour l'admin)
  Future<List<Map<String, dynamic>>> getAllClientsRaw() async {
    try {
      final snap = await _db.collection('clients').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Notifications client ───────────────────────────────────────────────

  Future<ClientNotificationSettings> getNotificationSettings(String clientId) async {
    try {
      final doc = await _db.collection('client_notifications').doc(clientId).get();
      if (!doc.exists || doc.data() == null) {
        return ClientNotificationSettings.defaults(clientId);
      }
      return ClientNotificationSettings.fromMap(doc.data()!);
    } catch (_) {
      return ClientNotificationSettings.defaults(clientId);
    }
  }

  Future<void> saveNotificationSettings(ClientNotificationSettings settings) async {
    await _db
        .collection('client_notifications')
        .doc(settings.clientId)
        .set(settings.toMap());
  }

  // ── Tickets support ───────────────────────────────────────────────────

  Stream<List<ClientSupportTicket>> streamSupportTickets(String clientId) {
    return _db
        .collection('client_support_tickets')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) {
      final tickets = snap.docs
          .map((d) => ClientSupportTicket.fromMap(d.data()))
          .toList();
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tickets;
    });
  }

  Future<String> createSupportTicket(ClientSupportTicket ticket) async {
    final id = _uuid.v4();
    final data = ticket.toMap();
    data['id'] = id;
    await _db.collection('client_support_tickets').doc(id).set(data);
    return id;
  }

  // ── Sécurité / Auth avancée ────────────────────────────────────────────

  Future<void> updateEmail(String newEmail) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> reauthenticate(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _auth.currentUser?.reauthenticateWithCredential(credential);
  }

  Future<void> deleteAccount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Supprimer données Firestore
    await _db.collection('clients').doc(uid).delete();
    // Supprimer adresses
    final addrSnap = await _db
        .collection('client_addresses')
        .where('clientId', isEqualTo: uid)
        .get();
    for (final d in addrSnap.docs) {
      await d.reference.delete();
    }
    // Supprimer compte Auth
    await _auth.currentUser?.delete();
  }

  Future<void> signOutAllDevices() async {
    // Firebase Auth n'a pas de "signout all devices" natif côté client.
    // On renouvelle le token en forçant un refresh, puis déconnecte localement.
    await _auth.currentUser?.getIdToken(true);
    await _auth.signOut();
  }
}
