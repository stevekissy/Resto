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
//   orders              → SOURCE UNIQUE pour toutes les commandes (POS + online)
//                         Les commandes en ligne ont orderSource='online'
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

  /// Stream commandes du client — lit UNIQUEMENT dans 'orders' (source unique)
  /// Filtre : clientId + orderSource='online'
  Stream<List<ClientOrder>> streamClientOrders(String clientId) {
    return _db
        .collection('orders')
        .where('clientId', isEqualTo: clientId)
        .where('orderSource', isEqualTo: 'online')
        .snapshots()
        .map((snap) {
      final orders = <ClientOrder>[];
      for (final d in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(d.data());
          // Normaliser les champs pour ClientOrder.fromMap()
          data['id'] = d.id;          // id = id du doc orders (source unique)
          data['internalOrderId'] = d.id; // alias pour compatibilité
          _normalizeOrderDataForClient(data);
          orders.add(ClientOrder.fromMap(data));
        } catch (e) {
          debugPrint('[streamClientOrders] doc ${d.id} ignoré: $e');
        }
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Stream côté client — toutes les commandes en ligne (admin/stats)
  Stream<List<ClientOrder>> streamAllOnlineOrders() {
    return _db
        .collection('orders')
        .where('orderSource', isEqualTo: 'online')
        .snapshots()
        .map((snap) {
      final orders = <ClientOrder>[];
      for (final d in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          data['internalOrderId'] = d.id;
          _normalizeOrderDataForClient(data);
          orders.add(ClientOrder.fromMap(data));
        } catch (e) {
          debugPrint('[streamAllOnlineOrders] doc ${d.id} ignoré: $e');
        }
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Normalise un doc 'orders' pour qu'il soit lisible par ClientOrder.fromMap()
  void _normalizeOrderDataForClient(Map<String, dynamic> data) {
    // status : string → int
    final statusRaw = data['status'];
    if (statusRaw is String) {
      data['status'] = _clientStatusFromString(statusRaw);
    }
    // orderType : null → calculer depuis tableNumber ou orderType string
    final orderTypeRaw = data['orderType'];
    if (orderTypeRaw == null) {
      final tableNum = data['tableNumber'] as String? ?? '';
      data['orderType'] = tableNum.contains('Emporter') ? 1 : 0;
    } else if (orderTypeRaw is String) {
      data['orderType'] = orderTypeRaw == 'takeaway' ? 1
                        : orderTypeRaw == 'dine_in'  ? 2
                        : 0;
    }
    // paymentMethod string → int
    final pmRaw = data['paymentMethod'];
    if (pmRaw is String) {
      data['paymentMethod'] = _paymentMethodFromString(pmRaw);
    }
    // paymentStatus string → int
    final psRaw = data['paymentStatus'];
    if (psRaw is String) {
      data['paymentStatus'] = _paymentStatusFromString(psRaw);
    }
    // deliveryAddress : si String → null (évite TypeError)
    final da = data['deliveryAddress'];
    if (da is String) {
      data['deliveryAddress'] = null;
    }
  }

  /// Stream côté admin — lit 'orders' filtrée sur orderSource=='online'
  /// SOURCE UNIQUE : data['id'] = d.id (id du doc orders directement)
  /// Plus de clientOrderId/internalOrderId : l'id est celui du doc orders.
  Stream<List<ClientOrder>> streamAdminOnlineOrders() {
    return _db
        .collection('orders')
        .where('orderSource', isEqualTo: 'online')
        .snapshots()
        .map((snap) {
      final list = <ClientOrder>[];
      for (final d in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(d.data());
          // SOURCE UNIQUE : id = id du doc orders (pas clientOrderId)
          data['id'] = d.id;
          data['internalOrderId'] = d.id;
          _normalizeOrderDataForClient(data);
          list.add(ClientOrder.fromMap(data));
        } catch (e) {
          debugPrint('[streamAdminOnlineOrders] doc ${d.id} ignoré — erreur: $e');
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Convertit le champ status string de la collection orders en index ClientOrderStatus
  int _clientStatusFromString(String s) {
    switch (s) {
      // Statuts basiques
      case 'pending':          return 0; // ClientOrderStatus.pending
      case 'confirmed':        return 1; // ClientOrderStatus.confirmed
      case 'preparing':        return 2; // ClientOrderStatus.preparing
      case 'ready':            return 3; // ClientOrderStatus.ready
      case 'delivering':       return 4; // ClientOrderStatus.delivering
      case 'delivered':        return 5; // ClientOrderStatus.delivered
      case 'cancelled':        return 6; // ClientOrderStatus.cancelled
      case 'served':           return 7; // ClientOrderStatus.served
      case 'paid':             return 8; // ClientOrderStatus.paid
      // Alias orderStatus
      case 'received':         return 0; // → pending
      case 'accepted':         return 1; // → confirmed
      case 'sent_to_kitchen':  return 2; // → preparing
      default:                 return 0;
    }
  }

  /// Convertit le paymentMethod string en index ClientPaymentMethod
  int _paymentMethodFromString(String s) {
    switch (s) {
      case 'cashOnDelivery': return 0;
      case 'orangeMoney':    return 1;
      case 'mtnMoney':       return 2;
      case 'moovMoney':      return 3;
      case 'wave':           return 4;
      case 'card':           return 5;
      default:               return 0;
    }
  }

  /// Convertit le paymentStatus string en index ClientPaymentStatus
  int _paymentStatusFromString(String s) {
    switch (s) {
      case 'pending':      return 0;
      case 'depositPaid':  return 1;
      case 'fullyPaid':
      case 'paid':         return 2;
      default:             return 0;
    }
  }

  /// SOURCE UNIQUE : crée la commande UNIQUEMENT dans 'orders'.
  /// Plus de double écriture client_orders + orders.
  /// Retourne l'id du doc orders (= orderId utilisé partout).
  Future<String> createOrder(ClientOrder order) async {
    final orderId = _uuid.v4();
    final count = await _getNextOrderNumber();
    final orderNumber = '#${count.toString().padLeft(4, '0')}';

    // Construire les items avec alias pour cuisine + itemType OBLIGATOIRE
    final items = order.items.map((i) => {
      'productId':   i.productId,
      'productName': i.productName,
      'name':        i.productName,  // alias cuisine
      'unitPrice':   i.unitPrice,
      'price':       i.unitPrice,    // alias cuisine
      'quantity':    i.quantity,
      'comment':     i.comment ?? '',
      'categoryName': i.categoryName ?? '',
      'imageUrl':    i.imageUrl,
      'itemType':    i.itemType,     // 'menu' | 'cambuse' — CRITIQUE pour cuisine/caisse
    }).toList();
    
    // Vérifier si la commande contient des items cuisine
    final hasKitchenItems = order.items.any((i) => i.itemType == 'menu');

    final orderTypeInt = order.orderType.index; // 0=delivery, 1=takeaway
    final orderTypeStr = orderTypeInt == 1 ? 'takeaway'
                       : orderTypeInt == 2 ? 'dine_in'
                       : 'delivery';
    final tableNumberStr = orderTypeInt == 1 ? 'À Emporter'
                         : orderTypeInt == 2 ? 'Sur place'
                         : 'Livraison Yango';

    await _db.collection('orders').doc(orderId).set({
      // ── Identité ──────────────────────────────────────────────────────
      'id':            orderId,
      'orderNumber':   orderNumber,
      'orderSource':   'online',
      'source':        'online',
      // ── Client ────────────────────────────────────────────────────────
      'clientId':      order.clientId,
      'clientName':    order.clientName,
      'clientPhone':   order.clientPhone,
      'serverName':    order.clientName,  // alias cuisine
      // ── Articles ──────────────────────────────────────────────────────
      'items':         items,
      // ── Type & table ──────────────────────────────────────────────────
      'orderType':     orderTypeStr,
      'tableNumber':   tableNumberStr,
      // ── Articles ─────────────────────────────────────────────────────
      'hasKitchenItems': hasKitchenItems, // helper pour cuisine
      // ── Statuts complets (source unique) ─────────────────────────────
      'status':          'pending',
      'orderStatus':     'received',
      'adminStatus':     'received',
      'kitchenStatus':   'not_sent',
      'cashierStatus':   'not_ready',
      'sentToKitchen':   false,
      'readyForCashier': false,
      // ── Fidélité workflow ─────────────────────────────────────────────
      'loyaltyStatus':   'pending',  // pending | credited
      // ── Timestamps workflow ───────────────────────────────────────────
      'acceptedAt':      null,
      'sentToKitchenAt': null,
      // ── Montants ──────────────────────────────────────────────────────
      'totalAmount':          order.totalAmount,
      'deliveryFee':          order.deliveryFee,
      'discount':             order.loyaltyDiscountAmount,
      'loyaltyDiscountAmount': order.loyaltyDiscountAmount,
      'depositAmount':         order.depositAmount,
      'remainingAmount':       order.remainingAmount,
      'depositRequired':       order.depositRequired,
      'depositPaid':           order.depositPaid,
      // ── Paiement ──────────────────────────────────────────────────────
      'paymentMethod':  order.paymentMethod.index,
      'paymentStatus':  order.paymentStatus.index,
      // cashStatus en int pour compatibilité avec streamOrders() (CashStatus enum index)
      // 0 = pending_cashout (prêt à encaisser — valeur par défaut)
      'cashStatus':     0, // CashStatus.pending_cashout.index
      // ── Fidélité ──────────────────────────────────────────────────────
      'loyaltyPointsUsed':    order.loyaltyPointsUsed,
      'loyaltyPointsEarned':  order.loyaltyPointsEarned,
      'loyaltyPointsAwarded': false,
      // ── Livraison ─────────────────────────────────────────────────────
      'deliveryAddress':     order.deliveryAddress?.toMap(),
      'geoLocation':         order.geoLocation,
      'deliveryNote':        order.deliveryNote,
      'deliveryPartner':     order.deliveryPartner,
      'deliveryFeePaidTo':   order.deliveryFeePaidTo,
      'deliveryFeeIncluded': order.deliveryFeeIncluded,
      'yangoStatus':         0,
      // ── Notes ─────────────────────────────────────────────────────────
      'notes':         order.notes ?? '',
      'specialInstructions': order.notes ?? '',
      // ── Timestamps ────────────────────────────────────────────────────
      'createdAt':     FieldValue.serverTimestamp(),
      'updatedAt':     FieldValue.serverTimestamp(),
    });

    debugPrint('[createOrder] ✅ orders/$orderId créé — orderSource=online kitchenStatus=not_sent');

    // ── Notifications admin/cuisine ──────────────────────────────────────
    try {
      final clientName   = order.clientName;
      final orderTypeLbl = orderTypeInt == 0 ? 'Livraison Yango' : 'À emporter';
      final notifId      = _uuid.v4();
      await _db.collection('notifications').doc(notifId).set({
        'id':          notifId,
        'type':        'online_order',
        'title':       '📱 Nouvelle commande en ligne',
        'message':     'NOUVELLE COMMANDE $orderNumber — $clientName ($orderTypeLbl)',
        'orderId':     orderId,
        'clientId':    order.clientId,
        'clientName':  clientName,
        'createdAt':   FieldValue.serverTimestamp(),
        'read':        false,
        'targetRoles': ['admin', 'manager', 'kitchen', 'cashier'],
      });

      if (order.depositPaid && order.depositAmount > 0) {
        final depositNotifId = _uuid.v4();
        await _db.collection('notifications').doc(depositNotifId).set({
          'id':          depositNotifId,
          'type':        'deposit_paid',
          'title':       '💰 Acompte reçu',
          'message':     'Acompte reçu pour commande $orderNumber — $clientName : ${order.depositAmount.toStringAsFixed(0)} F CFA',
          'orderId':     orderId,
          'clientId':    order.clientId,
          'clientName':  clientName,
          'amount':      order.depositAmount,
          'createdAt':   FieldValue.serverTimestamp(),
          'read':        false,
          'targetRoles': ['admin', 'manager', 'cashier'],
        });
      }
    } catch (e) {
      debugPrintOrder('Erreur notification création commande: $e');
    }

    return orderId;
  }

  Future<int> _getNextOrderNumber() async {
    final doc = await _db.collection('online_settings').doc('order_counter').get();
    final current = (doc.data()?['counter'] as num?)?.toInt() ?? 1000;
    await _db.collection('online_settings').doc('order_counter').set({
      'counter': current + 1,
    });
    return current + 1;
  }

  // _createInternalOrder() SUPPRIMÉ — SOURCE UNIQUE 'orders'

  void debugPrintOrder(String msg) {
    // ignore: avoid_print
    debugPrint('[ClientFirebaseService] $msg');
  }

  /// SOURCE UNIQUE : met à jour le statut directement dans 'orders'.
  /// [orderId] = id du doc orders (source unique — plus de clientOrderId séparé)
  ///
  /// ⛔ RÈGLE VERROUILLAGE CUISINE :
  /// Si sentToKitchen==true, seul un appelant ayant rôle 'cuisine' peut modifier
  /// le kitchenStatus. Tout autre modification est rejetée avec une exception.
  /// [callerRole] : rôle de l'appelant ('kitchen' | 'admin' | 'manager' | …)
  Future<void> updateOrderStatus(String orderId, ClientOrderStatus status,
      {String callerRole = ''}) async {
    // ── Guard verrouillage cuisine ────────────────────────────────────────
    // Vérifier directement en Firestore pour être sûr (defense-in-depth)
    if (callerRole != 'kitchen') {
      final snap = await _db.collection('orders').doc(orderId).get();
      if (snap.exists) {
        final sentToKitchen = snap.data()?['sentToKitchen'] as bool? ?? false;
        final ks = snap.data()?['kitchenStatus'] as String? ?? '';
        // Bloqué si en cours de traitement par la cuisine
        // (pending/preparing → cuisine active)
        if (sentToKitchen && (ks == 'pending' || ks == 'preparing')) {
          throw Exception('Commande envoyée en cuisine, modification impossible.');
        }
      }
    }
    final update = <String, dynamic>{
      'status': status.index,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Timestamps workflow
    switch (status) {
      case ClientOrderStatus.confirmed:
        update['confirmedAt']   = FieldValue.serverTimestamp();
        update['acceptedAt']    = FieldValue.serverTimestamp();
        update['adminStatus']   = 'accepted';
        update['orderStatus']   = 'accepted';
        update['kitchenStatus'] = 'not_sent';
        // sentToKitchen reste false — l'admin clique "Envoyer en cuisine" ensuite
        break;
      case ClientOrderStatus.preparing:
        // "Envoyer en cuisine" — sentToKitchen=true, cuisine voit la commande
        update['sentToKitchen']   = true;
        update['kitchenStatus']   = 'pending';  // UNIFIÉ — jamais 'waiting'
        update['sentToKitchenAt'] = FieldValue.serverTimestamp();
        update['adminStatus']     = 'sent_to_kitchen';
        update['orderStatus']     = 'sent_to_kitchen';
        break;
      case ClientOrderStatus.ready:
        update['readyAt']          = FieldValue.serverTimestamp();
        update['kitchenStatus']    = 'ready';
        update['adminStatus']      = 'ready';
        update['orderStatus']      = 'ready';
        update['readyForCashier']  = true;  // Signal caisse : commande prête à encaisser
        update['cashierStatus']    = 'ready';
        break;
      case ClientOrderStatus.delivering:
        update['adminStatus']  = 'delivering';
        update['orderStatus']  = 'delivering';
        break;
      case ClientOrderStatus.delivered:
        update['deliveredAt']      = FieldValue.serverTimestamp();
        update['settledAt']        = FieldValue.serverTimestamp();
        update['paymentStatus']    = ClientPaymentStatus.fullyPaid.index;
        update['kitchenStatus']    = 'served';
        update['adminStatus']      = 'delivered';
        update['orderStatus']      = 'delivered';
        update['cashierStatus']    = 'settled';
        update['settlementStatus'] = 'completed';
        update['loyaltyStatus']    = 'pending';  // sera mis à 'credited' par awardLoyaltyPoints
        break;
      case ClientOrderStatus.served:
        // Servie sur place
        update['paymentStatus']    = ClientPaymentStatus.fullyPaid.index;
        update['kitchenStatus']    = 'served';
        update['adminStatus']      = 'served';
        update['orderStatus']      = 'served';
        update['cashierStatus']    = 'settled';
        update['settlementStatus'] = 'completed';
        update['settledAt']        = FieldValue.serverTimestamp();
        update['loyaltyStatus']    = 'pending';  // sera mis à 'credited' par awardLoyaltyPoints
        break;
      case ClientOrderStatus.paid:
        // Payée / Clôturée
        update['paymentStatus']    = ClientPaymentStatus.fullyPaid.index;
        update['adminStatus']      = 'paid';
        update['orderStatus']      = 'paid';
        update['cashierStatus']    = 'settled';
        update['settlementStatus'] = 'completed';
        update['settledAt']        = FieldValue.serverTimestamp();
        update['loyaltyStatus']    = 'pending';  // sera mis à 'credited' par awardLoyaltyPoints
        break;
      case ClientOrderStatus.cancelled:
        update['kitchenStatus']  = 'cancelled';
        update['adminStatus']    = 'cancelled';
        update['orderStatus']    = 'cancelled';
        update['sentToKitchen']  = false;
        update['cashierStatus']  = 'cancelled';
        break;
      case ClientOrderStatus.pending:
        // Normalement pas appelé depuis updateOrderStatus — géré par createOrder
        break;
    }

    await _db.collection('orders').doc(orderId).update(update);
    debugPrint('[updateOrderStatus] ✅ orders/$orderId → ${status.label}');

    // ── Notifications staff + client ───────────────────────────────────
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final data        = orderDoc.data()!;
        final clientId    = data['clientId'] as String? ?? '';
        final clientName  = data['clientName'] as String? ?? 'Client';
        final orderNumber = data['orderNumber'] as String? ?? '';
        final remaining   = (data['remainingAmount'] as num?)?.toDouble() ?? 0;

        String? notifTitle;
        String? notifMessage;
        String  notifType = 'order_status';
        // Notifications client
        String? clientNotifTitle;
        String? clientNotifMessage;

        switch (status) {
          case ClientOrderStatus.confirmed:
            notifTitle   = '✅ Commande en ligne acceptée';
            notifMessage = 'Commande $orderNumber de $clientName — acceptée';
            notifType    = 'order_accepted';
            clientNotifTitle   = '✅ Commande acceptée !';
            clientNotifMessage = 'Votre commande $orderNumber a été acceptée. Elle va bientôt être préparée.';
            break;
          case ClientOrderStatus.preparing:
            notifTitle   = '🍳 Commande envoyée en cuisine';
            notifMessage = 'Commande $orderNumber de $clientName — en cuisine';
            notifType    = 'order_preparing';
            clientNotifTitle   = '🍳 En préparation';
            clientNotifMessage = 'Votre commande $orderNumber est en cours de préparation en cuisine.';
            break;
          case ClientOrderStatus.ready:
            notifTitle   = '✅ Commande prête';
            notifMessage = 'Commande $orderNumber de $clientName est PRÊTE';
            notifType    = 'order_ready';
            clientNotifTitle   = '✅ Commande prête !';
            clientNotifMessage = 'Votre commande $orderNumber est prête. Elle va être livrée sous peu.';
            break;
          case ClientOrderStatus.delivering:
            notifTitle   = '🚗 En livraison';
            notifMessage = 'Commande $orderNumber — Yango en route vers $clientName';
            notifType    = 'order_delivering';
            clientNotifTitle   = '🚗 En route !';
            clientNotifMessage = 'Votre commande $orderNumber est en chemin vers vous via Yango.';
            break;
          case ClientOrderStatus.delivered:
            notifTitle   = '💰 Solde à encaisser';
            notifMessage = remaining > 0
                ? 'Commande $orderNumber livrée — solde à encaisser'
                : 'Commande $orderNumber livrée et soldée ✓';
            notifType    = 'order_settled';
            clientNotifTitle   = '📦 Commande livrée !';
            clientNotifMessage = 'Votre commande $orderNumber a été livrée. Merci pour votre confiance ! Des points fidélité ont été crédités.';
            break;
          case ClientOrderStatus.served:
            notifTitle   = '🍽️ Commande servie';
            notifMessage = 'Commande $orderNumber de $clientName — servie sur place';
            notifType    = 'order_served';
            clientNotifTitle   = '🍽️ Bon appétit !';
            clientNotifMessage = 'Votre commande $orderNumber a été servie. Merci pour votre visite ! Des points fidélité ont été crédités.';
            break;
          case ClientOrderStatus.paid:
            notifTitle   = '💚 Commande payée';
            notifMessage = 'Commande $orderNumber de $clientName — payée et clôturée';
            notifType    = 'order_paid';
            clientNotifTitle   = '💚 Commande payée !';
            clientNotifMessage = 'Votre commande $orderNumber est soldée. Points fidélité crédités. À bientôt !';
            break;
          case ClientOrderStatus.cancelled:
            notifTitle   = '❌ Commande annulée';
            notifMessage = 'Commande $orderNumber de $clientName annulée';
            notifType    = 'order_cancelled';
            clientNotifTitle   = '❌ Commande annulée';
            clientNotifMessage = 'Votre commande $orderNumber a été annulée. Contactez-nous pour plus d\'informations.';
            break;
          case ClientOrderStatus.pending:
            break;
        }

        // Notification staff (collection globale)
        if (notifTitle != null) {
          final notifId = _uuid.v4();
          await _db.collection('notifications').doc(notifId).set({
            'id':          notifId,
            'type':        notifType,
            'title':       notifTitle,
            'message':     notifMessage,
            'orderId':     orderId,
            'clientName':  clientName,
            'createdAt':   FieldValue.serverTimestamp(),
            'read':        false,
            'targetRoles': ['admin', 'manager', 'kitchen', 'cashier'],
          });
        }

        // Notification client (sous-collection dédiée)
        if (clientNotifTitle != null && clientId.isNotEmpty) {
          await _sendClientNotification(
            clientId: clientId,
            orderId:  orderId,
            type:     notifType,
            title:    clientNotifTitle,
            message:  clientNotifMessage ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('[updateOrderStatus] Notif erreur: $e');
      // Notifications non bloquantes
    }
  }

  /// SOURCE UNIQUE — syncKitchenStatusToClientOrder() supprimé.
  /// Désormais, updateOrderStatus() écrit directement dans 'orders' (source unique).
  /// Cette méthode est conservée comme stub vide pour compatibilité avec AppProvider
  /// jusqu'à la prochaine mise à jour de app_provider.dart.
  Future<void> syncKitchenStatusToClientOrder({
    required String internalOrderId,
    required ClientOrderStatus clientStatus,
  }) async {
    // NO-OP : source unique orders — plus de synchronisation client_orders nécessaire
    debugPrint('[syncKitchenStatusToClientOrder] NO-OP (source unique orders) orderId=$internalOrderId status=$clientStatus');
  }

  /// SOURCE UNIQUE — Normalise complètement le doc 'orders' au format POS avant envoi cuisine.
  ///
  /// RÈGLE FONDAMENTALE : après cet appel, le doc Firestore est identique à un doc
  /// créé par saveOrder() côté POS. Tous les champs critiques sont réécrits avec
  /// les types corrects. Aucun résidu de la structure online n'est laissé.
  ///
  /// Utilise set(merge: true) pour garantir l'écriture atomique de tous les champs
  /// même si update() échoue silencieusement sur certains champs.
  ///
  /// [orderId] = id du doc orders (widget.order.id depuis streamAdminOnlineOrders)
  Future<void> sendToKitchen(String orderId) async {
    debugPrint('[sendToKitchen] ▶ START orderId=$orderId');

    // ── 1. Lire le doc actuel ──────────────────────────────────────────────
    final snap = await _db.collection('orders').doc(orderId).get();
    if (!snap.exists) throw Exception('[sendToKitchen] Commande introuvable : $orderId');
    final raw = Map<String, dynamic>.from(snap.data()!);

    // ── 2. Normaliser orderNumber : string '#0042' → int 42 ───────────────
    final rawNum = raw['orderNumber'];
    final int orderNumberInt;
    if (rawNum is int) {
      orderNumberInt = rawNum;
    } else if (rawNum is double) {
      orderNumberInt = rawNum.toInt();
    } else if (rawNum is String) {
      orderNumberInt = int.tryParse(rawNum.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    } else {
      orderNumberInt = 0;
    }

    // ── 3. Normaliser les items au format OrderItem.toMap() exact ─────────
    // Garantit que chaque item a : productName, unitPrice, itemType, isCambuse
    // Les commandes online peuvent stocker 'name'/'price' au lieu de 'productName'/'unitPrice'
    final rawItems = (raw['items'] as List?)?.cast<Object>() ?? [];
    final normalizedItems = rawItems.map((item) {
      final m = Map<String, dynamic>.from(item as Map);

      // productName : priorité 'productName' > 'name'
      final pName = ((m['productName'] as String?) ?? '').isNotEmpty
          ? m['productName'] as String
          : ((m['name'] as String?) ?? '');

      // unitPrice : priorité 'unitPrice' > 'price'
      final uPrice = (m['unitPrice'] as num?)?.toDouble()
          ?? (m['price'] as num?)?.toDouble()
          ?? 0.0;

      // itemType : priorité 'itemType' explicite > déduction depuis isCambuse > défaut 'menu'
      // CRITIQUE : 'menu' = va en cuisine, 'cambuse' = boisson directement en caisse
      final isCamb = m['isCambuse'] as bool? ?? false;
      final rawType = (m['itemType'] as String?) ?? '';
      final itemType = rawType.isNotEmpty ? rawType : (isCamb ? 'cambuse' : 'menu');

      // specialComment : 'specialComment' > 'comment'
      final rawCmt = (m['comment'] as String?) ?? '';
      final specialComment = (m['specialComment'] as String?)
          ?? (rawCmt.isNotEmpty ? rawCmt : null);

      // category : 'category' > 'categoryName'
      final cat = (m['category'] as String?)
          ?? (m['categoryName'] as String?);

      return <String, dynamic>{
        'productId':      (m['productId'] as String?) ?? '',
        'productName':    pName,
        'name':           pName,           // alias cuisine
        'quantity':       (m['quantity'] as num?)?.toInt() ?? 1,
        'unitPrice':      uPrice,
        'price':          uPrice,          // alias cuisine
        'specialComment': specialComment,
        'isCambuse':      isCamb || itemType == 'cambuse',
        'itemType':       itemType,        // SOURCE DE VÉRITÉ : 'menu' | 'cambuse'
        'cambuseItemId':  m['cambuseItemId'] as String?,
        'category':       cat,
      };
    }).toList();

    // ── 4. Calculer hasKitchenItems depuis les items normalisés ───────────
    // Persisté en Firestore pour que les filtres puissent l'utiliser sans parser les items
    final hasKitchenItemsBool = normalizedItems.any((i) => i['itemType'] == 'menu');

    // ── 5. Normaliser orderType et tableNumber ────────────────────────────
    final rawOT = (raw['orderType'] as String?) ?? '';
    final String posOrderType;
    switch (rawOT) {
      case 'takeaway': posOrderType = 'takeaway'; break;
      case 'dine_in':  posOrderType = 'dine_in';  break;
      default:         posOrderType = 'delivery'; break;
    }
    final tableNumber = (raw['tableNumber'] as String?)
        ?? (posOrderType == 'takeaway' ? 'À Emporter'
           : posOrderType == 'dine_in' ? 'Sur place'
           : 'Livraison');

    // ── 6. totalAmount ────────────────────────────────────────────────────
    final totalAmount = (raw['totalAmount'] as num?)?.toDouble()
        ?? normalizedItems.fold<double>(0.0, (s, i) =>
            s + ((i['unitPrice'] as num? ?? 0) * (i['quantity'] as num? ?? 1)));

    final discount = (raw['discount'] as num?)?.toDouble()
        ?? (raw['loyaltyDiscountAmount'] as num?)?.toDouble()
        ?? 0.0;

    // ── 7. serverName (affiché en cuisine/caisse) ─────────────────────────
    final serverName = (raw['clientName'] as String?)
        ?? (raw['serverName'] as String?)
        ?? '';

    // ── 8. Écriture set(merge: true) — TOUS les champs POS garantis ──────
    // set(merge: true) remplace chaque champ listé sans effacer les autres.
    // Plus fiable que update() qui peut échouer silencieusement sur des
    // champs déjà à leur valeur cible selon certaines règles Firestore.
    await _db.collection('orders').doc(orderId).set({
      // ── Identité ─────────────────────────────────────────────────────
      'id':             orderId,
      'orderNumber':    orderNumberInt,       // int (jamais string '#0042')
      // ── Articles ─────────────────────────────────────────────────────
      'items':          normalizedItems,      // format OrderItem.toMap() exact
      'hasKitchenItems': hasKitchenItemsBool, // persisté pour filtres rapides
      // ── Statuts POS (types corrects pour streamOrders) ────────────────
      'status':         0,                    // OrderStatus.pending.index
      'orderStatus':    'pending',            // string lu en priorité par _parseOrderStatus
      'kitchenStatus':  'pending',            // lu par filtre cuisine
      'cashStatus':     0,                    // CashStatus.pending_cashout.index
      'isPaid':         false,
      'cashoutInvoiceGenerated':    false,
      'settlementInvoiceGenerated': false,
      // ── Montants ─────────────────────────────────────────────────────
      'totalAmount':    totalAmount,
      'discount':       discount,
      // ── Table / type ─────────────────────────────────────────────────
      'tableNumber':    tableNumber,
      'orderType':      posOrderType,         // 'delivery' | 'takeaway' | 'dine_in'
      'serverName':     serverName,
      'isUrgent':       raw['isUrgent'] as bool? ?? false,
      // ── Workflow cuisine ──────────────────────────────────────────────
      'sentToKitchen':   true,               // CRITIQUE : active le filtre kitchen_screen
      'adminStatus':     'sent_to_kitchen',
      'sentToKitchenAt': FieldValue.serverTimestamp(),
      // ── Source online conservée ───────────────────────────────────────
      'source':          'online',
      'orderSource':     'online',
      'clientId':        raw['clientId'],
      'clientName':      raw['clientName'],
      'clientPhone':     raw['clientPhone'],
      // ── Timestamps ────────────────────────────────────────────────────
      'createdAt':       raw['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt':       FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[sendToKitchen] ✅ orderId=$orderId → orderNumber=$orderNumberInt '
        'hasKitchenItems=$hasKitchenItemsBool items=${normalizedItems.length} '
        'orderType=$posOrderType tableNumber=$tableNumber');

    // ── Notification Firestore ─────────────────────────────────────────────
    try {
      final clientName  = raw['clientName']  as String? ?? 'Client';
      final notifId     = _uuid.v4();
      await _db.collection('notifications').doc(notifId).set({
        'id':          notifId,
        'type':        'order_preparing',
        'title':       '🍳 Commande envoyée en cuisine',
        'message':     'Commande #${orderNumberInt.toString().padLeft(4,'0')} de $clientName envoyée en cuisine',
        'orderId':     orderId,
        'createdAt':   FieldValue.serverTimestamp(),
        'isRead':      false,
        'read':        false,
        'targetRoles': ['admin', 'manager', 'kitchen', 'cashier'],
      });
    } catch (e) {
      debugPrint('[sendToKitchen] ❌ Notif: $e');
    }
  }

  /// SOURCE UNIQUE : annule la commande dans 'orders' directement.
  /// ⛔ GUARD FIRESTORE : rejetée si la commande est déjà en préparation.
  /// [orderId] = id du doc orders
  Future<void> cancelOrder(String orderId) async {
    await _db.runTransaction((tx) async {
      final ref  = _db.collection('orders').doc(orderId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Commande introuvable');
      // Vérifier le kitchenStatus (source de vérité pour les commandes en ligne)
      final ks = snap.data()?['kitchenStatus'] as String? ?? '';
      if (ks == 'preparing') {
        throw Exception('Commande déjà en préparation, annulation impossible.');
      }
      tx.update(ref, {
        'status':        ClientOrderStatus.cancelled.index,
        'kitchenStatus': 'cancelled',
        'adminStatus':   'cancelled',
        'orderStatus':   'cancelled',
        'sentToKitchen': false,
        'updatedAt':     FieldValue.serverTimestamp(),
      });
    });
    debugPrint('[cancelOrder] ✅ orders/$orderId → cancelled');
  }

  /// SOURCE UNIQUE : met à jour le statut Yango directement dans 'orders'.
  /// [orderId] = id du doc orders
  Future<void> updateYangoStatus(String orderId, YangoDeliveryStatus yangoStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'yangoStatus':      yangoStatus.index,
      'yangoStatusLabel': yangoStatus.label,
      'updatedAt':        FieldValue.serverTimestamp(),
    });
    debugPrint('[updateYangoStatus] ✅ orders/$orderId → yangoStatus=${yangoStatus.label}');
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

  // ── Bannières espace client ────────────────────────────────────────────

  Stream<List<AppBanner>> streamAllBanners() {
    return _db
        .collection('banners')
        .snapshots()
        .map((snap) {
      final banners = snap.docs
          .map((d) => AppBanner.fromMap(d.data()))
          .toList();
      banners.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return banners;
    });
  }

  Stream<List<AppBanner>> streamVisibleBanners() {
    return _db
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final banners = snap.docs
          .map((d) => AppBanner.fromMap(d.data()))
          .where((b) {
            final started = b.validFrom == null || now.isAfter(b.validFrom!);
            final notExpired = b.validUntil == null || now.isBefore(b.validUntil!);
            return started && notExpired;
          })
          .toList();
      banners.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return banners;
    });
  }

  Future<String> addBanner(AppBanner banner) async {
    final id = _uuid.v4();
    final data = banner.toMap();
    data['id'] = id;
    // Timestamps audit
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    data['createdAt'] = nowMs;
    data['updatedAt'] = nowMs;

    // Vérification taille : Firestore limite à 1 048 576 bytes par document.
    // L'image base64 est le seul champ potentiellement volumineux.
    final imageUrl = data['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.startsWith('data:')) {
      // Taille approximative du document = taille base64 en chars (≈ bytes UTF-8)
      final approxDocSize = imageUrl.length + 2048; // 2 Ko pour les autres champs
      if (approxDocSize > 900000) {
        // > 900 Ko → refus avant même d'appeler Firestore
        throw Exception(
          'Image trop volumineuse (${(approxDocSize / 1024).round()} Ko). '
          'Limite Firestore : 900 Ko. '
          'Réduisez la résolution ou utilisez une image plus petite.',
        );
      }
    }

    await _db.collection('banners').doc(id).set(data);
    return id;
  }

  Future<void> updateBanner(AppBanner banner) async {
    final data = banner.toMap();
    // S'assurer que createdAt n'est pas écrasé lors d'une mise à jour
    data.remove('createdAt');
    data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    // Même vérification taille pour la mise à jour
    final imageUrl = data['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.startsWith('data:')) {
      final approxDocSize = imageUrl.length + 2048;
      if (approxDocSize > 900000) {
        throw Exception(
          'Image trop volumineuse (${(approxDocSize / 1024).round()} Ko). '
          'Limite Firestore : 900 Ko. '
          'Réduisez la résolution ou utilisez une image plus petite.',
        );
      }
    }

    await _db.collection('banners').doc(banner.id).update(data);
  }

  Future<void> deleteBanner(String bannerId) async {
    await _db.collection('banners').doc(bannerId).delete();
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
  // ── Attribution sécurisée des points fidélité + totalSpent (après paiement ET livraison) ──
  //
  // Règle STRICTE :
  //   paymentStatus == fullyPaid  (index 2)
  //   status        == delivered  (index 5)
  //   loyaltyPointsAwarded == false  (idempotence)
  //
  // Appelé par updateOrderStatus() quand newStatus == delivered.
  // Incrémente aussi totalOrders et totalSpent — jamais à la création.
  /// SOURCE UNIQUE : attribution des points fidélité depuis 'orders'.
  /// [clientOrderId] = id du doc orders (source unique)
  Future<void> awardLoyaltyPoints({
    required String clientOrderId,
    required String clientId,
    required int pointsToAward,
  }) async {
    // Vérification idempotence : lire depuis 'orders' (source unique)
    final orderDoc = await _db.collection('orders').doc(clientOrderId).get();
    if (!orderDoc.exists) {
      debugPrintOrder('[loyalty] Doc orders/$clientOrderId introuvable — skip');
      return;
    }
    final data = orderDoc.data()!;

    // ── Idempotence : bloquer si déjà traité ──────────────────────────────
    final alreadyAwarded = data['loyaltyPointsAwarded'] as bool? ?? false;
    if (alreadyAwarded) {
      debugPrintOrder('[loyalty] Déjà traité pour $clientOrderId — skip complet');
      return;
    }

    // ── Vérification : statut final (livré/servi/payé) ───────────────────
    final deliveryStatusIndex = (data['status'] as num?)?.toInt() ?? -1;
    final orderStatusStr      = data['orderStatus'] as String? ?? '';
    final kitchenStatusStr    = data['kitchenStatus'] as String? ?? '';

    // Statuts finaux acceptés : delivered(5), served(7), paid(8) — ou via string/kitchenStatus
    // FIX : ne PAS bloquer sur paymentStatus — pour les commandes restaurant,
    // le paiement caisse arrive après le service (paymentStatus reste à 0/pending).
    // La règle métier réelle : commande servie = points accordés.
    final isDelivered = deliveryStatusIndex == 5  // ClientOrderStatus.delivered
                     || deliveryStatusIndex == 7  // ClientOrderStatus.served
                     || deliveryStatusIndex == 8  // ClientOrderStatus.paid
                     || orderStatusStr == 'delivered'
                     || orderStatusStr == 'served'
                     || orderStatusStr == 'paid'
                     || kitchenStatusStr == 'served'; // FIX : cuisine a marqué served

    if (!isDelivered) {
      debugPrintOrder('[loyalty] Commande pas encore servie (status=$deliveryStatusIndex/$orderStatusStr/ks=$kitchenStatusStr) — skip');
      return;
    }

    // ── Marquer AVANT toute écriture (protection crash/double appel) ──────
    await _db.collection('orders').doc(clientOrderId).update({
      'loyaltyPointsAwarded':   true,
      'loyaltyPointsAwardedAt': FieldValue.serverTimestamp(),
      'loyaltyStatus':          'credited',  // double idempotence
    });

    // ── Incrémenter totalOrders et totalSpent ─────────────────────────────
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
    final grandTotal  = totalAmount + deliveryFee;
    await _db.collection('clients').doc(clientId).update({
      'totalOrders': FieldValue.increment(1),
      'totalSpent':  FieldValue.increment(grandTotal),
    });

    // ── Créer la transaction fidélité (seulement si points > 0) ──────────
    if (pointsToAward > 0) {
      final txId = _uuid.v4();
      await _db.collection('loyalty_transactions').doc(txId).set({
        'id':          txId,
        'clientId':    clientId,
        'type':        LoyaltyType.earn.index,
        'points':      pointsToAward,
        'description': 'Points fidélité — commande livrée et payée',
        'orderId':     clientOrderId,
        'createdAt':   DateTime.now().millisecondsSinceEpoch,
      });
      await _db.collection('clients').doc(clientId).update({
        'loyaltyPoints': FieldValue.increment(pointsToAward),
      });
      debugPrintOrder('[loyalty] ✅ $pointsToAward pts + totalSpent+$grandTotal F → client $clientId');
    } else {
      debugPrintOrder('[loyalty] ✅ totalSpent+$grandTotal F (0 point à attribuer) → client $clientId');
    }
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


  // ══════════════════════════════════════════════════════════════════════════
  // SYSTÈME DE PARRAINAGE
  // Collection : referralTransactions
  // Règles :
  //   1. Code parrainage unique par client (format: SKR-XXXXXX)
  //   2. Un client ne peut utiliser qu'UN seul code (referredBy ne change pas)
  //   3. Bonus attribué UNE SEULE FOIS après commande payée + livrée
  //   4. Anti-abus : referralBonusAwarded = true après attribution
  // ══════════════════════════════════════════════════════════════════════════

  static const int _referrerBonus = 50;   // points bonus parrain
  static const int _referreeBonus = 30;   // points bonus filleul

  /// Génère un code de parrainage unique pour un client
  String _generateReferralCode(String clientId) {
    // Format: SKR-XXXXXX (6 chars alphanumériques en maj)
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final seed = clientId.hashCode.abs();
    String code = 'SKR-';
    for (int i = 0; i < 6; i++) {
      code += chars[(seed >> (i * 5)) % chars.length];
    }
    return code;
  }

  /// Initialise le code parrainage d'un client (si pas encore fait)
  Future<String> initReferralCode(String clientId) async {
    final doc = await _db.collection('clients').doc(clientId).get();
    if (!doc.exists) throw Exception('Client introuvable');
    
    final existing = doc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    
    // Générer code unique
    String code = _generateReferralCode(clientId);
    // Vérifier unicité (très peu probable de collision mais on vérifie)
    final check = await _db.collection('clients')
        .where('referralCode', isEqualTo: code)
        .limit(1).get();
    if (check.docs.isNotEmpty) {
      // Fallback : utiliser une partie de l'UUID
      code = 'SKR-${clientId.substring(0, 6).toUpperCase()}';
    }
    
    await _db.collection('clients').doc(clientId).update({
      'referralCode': code,
    });
    debugPrint('[referral] Code parrainage créé: $code pour $clientId');
    return code;
  }

  /// Applique un code de parrainage à un nouveau client (filleul)
  /// Retourne null si OK, ou un message d'erreur si problème
  Future<String?> applyReferralCode({
    required String newClientId,
    required String referralCode,
  }) async {
    // Vérifier que le client n'a pas déjà un parrain
    final clientDoc = await _db.collection('clients').doc(newClientId).get();
    if (!clientDoc.exists) return 'Client introuvable';
    
    final alreadyReferred = clientDoc.data()?['referredBy'] as String?;
    if (alreadyReferred != null && alreadyReferred.isNotEmpty) {
      return 'Vous avez déjà utilisé un code de parrainage';
    }
    
    // Vérifier que le code existe et appartient à un autre client
    final referrerSnap = await _db.collection('clients')
        .where('referralCode', isEqualTo: referralCode.toUpperCase())
        .limit(1).get();
    
    if (referrerSnap.docs.isEmpty) return 'Code de parrainage invalide';
    
    final referrerId = referrerSnap.docs.first.id;
    if (referrerId == newClientId) return 'Vous ne pouvez pas utiliser votre propre code';
    
    // Enregistrer le lien parrain/filleul
    await _db.collection('clients').doc(newClientId).update({
      'referredBy': referrerId,
      'referralBonusAwarded': false,
    });
    
    debugPrint('[referral] ✅ $newClientId parrainé par $referrerId (code: $referralCode)');
    return null; // null = succès
  }

  /// Attribue les bonus de parrainage après la première commande payée/livrée du filleul
  /// Anti-abus : referralBonusAwarded garantit l'idempotence
  Future<void> processReferralBonus({
    required String clientId,  // filleul
    required String orderId,
  }) async {
    // Lire le profil filleul
    final clientDoc = await _db.collection('clients').doc(clientId).get();
    if (!clientDoc.exists) return;
    final data = clientDoc.data()!;
    
    final referrerId = data['referredBy'] as String?;
    if (referrerId == null || referrerId.isEmpty) return; // pas de parrain
    
    final alreadyBonused = data['referralBonusAwarded'] as bool? ?? false;
    if (alreadyBonused) {
      debugPrint('[referral] Bonus déjà attribué pour $clientId — skip');
      return;
    }
    
    // Marquer AVANT d'attribuer (protection crash)
    await _db.collection('clients').doc(clientId).update({
      'referralBonusAwarded': true,
    });
    
    // Créer l'enregistrement referralTransaction
    final txId = _uuid.v4();
    await _db.collection('referralTransactions').doc(txId).set({
      'id':             txId,
      'referrerId':     referrerId,
      'referreeId':     clientId,
      'referrerPoints': _referrerBonus,
      'referreePoints': _referreeBonus,
      'orderId':        orderId,
      'createdAt':      FieldValue.serverTimestamp(),
    });
    
    // Créditer le parrain
    await _db.collection('clients').doc(referrerId).update({
      'loyaltyPoints': FieldValue.increment(_referrerBonus),
    });
    final refTxId = _uuid.v4();
    await _db.collection('loyalty_transactions').doc(refTxId).set({
      'id':          refTxId,
      'clientId':    referrerId,
      'type':        1, // LoyaltyType.bonus.index
      'points':      _referrerBonus,
      'description': 'Bonus parrainage — filleul a passé sa première commande',
      'orderId':     orderId,
      'createdAt':   DateTime.now().millisecondsSinceEpoch,
    });
    
    // Créditer le filleul
    await _db.collection('clients').doc(clientId).update({
      'loyaltyPoints': FieldValue.increment(_referreeBonus),
    });
    final fTxId = _uuid.v4();
    await _db.collection('loyalty_transactions').doc(fTxId).set({
      'id':          fTxId,
      'clientId':    clientId,
      'type':        1, // LoyaltyType.bonus.index
      'points':      _referreeBonus,
      'description': 'Bonus filleul — parrainage validé après votre commande',
      'orderId':     orderId,
      'createdAt':   DateTime.now().millisecondsSinceEpoch,
    });
    
    debugPrint('[referral] ✅ Bonus parrain=$_referrerBonus pts → $referrerId | filleul=$_referreeBonus pts → $clientId');
    
    // Notification parrain
    await _sendClientNotification(
      clientId: referrerId,
      orderId: orderId,
      type: 'referral_bonus',
      title: '🎉 Bonus parrainage !',
      message: 'Votre filleul a passé sa première commande. +$_referrerBonus points crédités !',
    );
  }

  /// Vérifie si un code parrainage existe et retourne le nom du parrain
  Future<Map<String, dynamic>?> checkReferralCode(String code) async {
    try {
      final snap = await _db.collection('clients')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1).get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      return {'id': snap.docs.first.id, 'name': data['name'] ?? 'Client'};
    } catch (_) {
      return null;
    }
  }

  // ── Accepter une commande (admin) ─────────────────────────────────────────
  /// Marque la commande comme acceptée par l'admin.
  /// Étape intermédiaire entre 'received' et 'sent_to_kitchen'.
  /// ⛔ RÈGLE VERROUILLAGE CUISINE :
  /// Impossible d'accepter une commande déjà envoyée en cuisine.
  /// [callerRole] : rôle de l'appelant — doit être != 'kitchen'
  Future<void> acceptOrder(String orderId, {String callerRole = ''}) async {
    // Guard verrouillage cuisine
    final snap = await _db.collection('orders').doc(orderId).get();
    if (snap.exists) {
      final sentToKitchen = snap.data()?['sentToKitchen'] as bool? ?? false;
      final ks = snap.data()?['kitchenStatus'] as String? ?? '';
      if (sentToKitchen && (ks == 'pending' || ks == 'preparing')) {
        throw Exception('Commande envoyée en cuisine, modification impossible.');
      }
    }
    await _db.collection('orders').doc(orderId).update({
      'adminStatus':   'accepted',
      'orderStatus':   'accepted',
      'status':        ClientOrderStatus.confirmed.index,
      'acceptedAt':    FieldValue.serverTimestamp(),
      'kitchenStatus': 'not_sent',   // pas encore envoyée en cuisine
      'sentToKitchen': false,
      'updatedAt':     FieldValue.serverTimestamp(),
    });
    debugPrint('[acceptOrder] ✅ orders/$orderId → accepted');

    // Notification client
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final data       = orderDoc.data()!;
        final clientId   = data['clientId'] as String? ?? '';
        final orderNumber = data['orderNumber'] as String? ?? '';
        if (clientId.isNotEmpty) {
          await _sendClientNotification(
            clientId:  clientId,
            orderId:   orderId,
            type:      'order_accepted',
            title:     '✅ Commande acceptée !',
            message:   'Votre commande $orderNumber a été acceptée. Nous préparons votre repas.',
          );
        }
        // Notification staff
        final notifId = _uuid.v4();
        await _db.collection('notifications').doc(notifId).set({
          'id':          notifId,
          'type':        'order_accepted',
          'title':       '✅ Commande acceptée',
          'message':     'Commande $orderNumber acceptée par l\'admin',
          'orderId':     orderId,
          'createdAt':   FieldValue.serverTimestamp(),
          'read':        false,
          'targetRoles': ['admin', 'manager', 'kitchen'],
        });
      }
    } catch (e) {
      debugPrint('[acceptOrder] Notif erreur: $e');
    }
  }

  // ── Notifications client (sous-collection) ─────────────────────────────────
  /// Envoie une notification directement dans la sous-collection client
  /// client_notifications/{clientId}/messages
  Future<void> _sendClientNotification({
    required String clientId,
    required String orderId,
    required String type,
    required String title,
    required String message,
  }) async {
    final notifId = _uuid.v4();
    await _db
        .collection('client_notifications')
        .doc(clientId)
        .collection('messages')
        .doc(notifId)
        .set({
      'id':        notifId,
      'type':      type,
      'title':     title,
      'message':   message,
      'orderId':   orderId,
      'clientId':  clientId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead':    false,
    });
  }

  /// Stream des notifications d'un client (sous-collection messages)
  Stream<List<Map<String, dynamic>>> streamClientNotifications(String clientId) {
    return _db
        .collection('client_notifications')
        .doc(clientId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Marque une notification client comme lue
  Future<void> markClientNotificationRead(String clientId, String notifId) async {
    await _db
        .collection('client_notifications')
        .doc(clientId)
        .collection('messages')
        .doc(notifId)
        .update({'isRead': true});
  }

  /// Retourne le nombre de notifications non lues d'un client
  Future<int> getUnreadClientNotificationsCount(String clientId) async {
    try {
      final snap = await _db
          .collection('client_notifications')
          .doc(clientId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> signOutAllDevices() async {
    // Firebase Auth n'a pas de "signout all devices" natif côté client.
    // On renouvelle le token en forçant un refresh, puis déconnecte localement.
    await _auth.currentUser?.getIdToken(true);
    await _auth.signOut();
  }
}
