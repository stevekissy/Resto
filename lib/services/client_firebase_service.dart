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
      case 'pending':    return 0; // ClientOrderStatus.pending
      case 'confirmed':  return 1; // ClientOrderStatus.confirmed
      case 'preparing':  return 2; // ClientOrderStatus.preparing
      case 'ready':      return 3; // ClientOrderStatus.ready
      case 'delivering': return 4; // ClientOrderStatus.delivering
      case 'delivered':  return 5; // ClientOrderStatus.delivered
      case 'cancelled':  return 6; // ClientOrderStatus.cancelled
      default:           return 0;
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

    // Construire les items avec alias pour cuisine
    final items = order.items.map((i) => {
      'productId': i.productId,
      'productName': i.productName,
      'name': i.productName,         // alias cuisine
      'unitPrice': i.unitPrice,
      'price': i.unitPrice,          // alias cuisine
      'quantity': i.quantity,
      'comment': i.comment ?? '',
      'categoryName': i.categoryName ?? '',
      'imageUrl': i.imageUrl,
    }).toList();

    final orderTypeInt = order.orderType.index; // 0=delivery, 1=takeaway
    final orderTypeStr = orderTypeInt == 1 ? 'takeaway'
                       : orderTypeInt == 2 ? 'dine_in'
                       : 'delivery';
    final tableNumberStr = orderTypeInt == 1 ? 'À Emporter'
                         : orderTypeInt == 2 ? 'Sur place'
                         : 'Livraison Yango';

    final now = DateTime.now().millisecondsSinceEpoch;

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
      // ── Statuts ───────────────────────────────────────────────────────
      'status':        'pending',
      'orderStatus':   'received',
      'adminStatus':   'received',
      'kitchenStatus': 'not_sent',
      'sentToKitchen': false,
      // ── Cuisine workflow ──────────────────────────────────────────────
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
      'cashStatus':     order.depositAmount > 0 ? 'deposit_received' : 'pending_cashout',
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
  Future<void> updateOrderStatus(String orderId, ClientOrderStatus status) async {
    final update = <String, dynamic>{
      'status': status.index,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Timestamps workflow
    switch (status) {
      case ClientOrderStatus.confirmed:
        update['confirmedAt']  = FieldValue.serverTimestamp();
        update['adminStatus']  = 'confirmed';
        update['kitchenStatus'] = 'not_sent';
        // sentToKitchen reste false — l'admin clique "Envoyer en cuisine" ensuite
        break;
      case ClientOrderStatus.preparing:
        // "Envoyer en cuisine" — sentToKitchen=true, cuisine voit la commande
        update['sentToKitchen']   = true;
        update['kitchenStatus']   = 'pending';
        update['sentToKitchenAt'] = FieldValue.serverTimestamp();
        update['adminStatus']     = 'sent_to_kitchen';
        update['orderStatus']     = 'sent_to_kitchen';
        break;
      case ClientOrderStatus.ready:
        update['readyAt']       = FieldValue.serverTimestamp();
        update['kitchenStatus'] = 'ready';
        update['adminStatus']   = 'ready';
        break;
      case ClientOrderStatus.delivering:
        update['adminStatus'] = 'delivering';
        break;
      case ClientOrderStatus.delivered:
        update['deliveredAt']       = FieldValue.serverTimestamp();
        update['settledAt']         = FieldValue.serverTimestamp();
        update['paymentStatus']     = ClientPaymentStatus.fullyPaid.index;
        update['kitchenStatus']     = 'served';
        update['adminStatus']       = 'delivered';
        update['settlementStatus']  = 'completed';
        break;
      case ClientOrderStatus.cancelled:
        update['kitchenStatus'] = 'cancelled';
        update['adminStatus']   = 'cancelled';
        update['sentToKitchen'] = false;
        break;
      default:
        break;
    }

    await _db.collection('orders').doc(orderId).update(update);
    debugPrint('[updateOrderStatus] ✅ orders/$orderId → $status');

    // ── Notifications ──────────────────────────────────────────────────
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        final clientName  = data['clientName'] as String? ?? 'Client';
        final orderNumber = data['orderNumber'] as String? ?? '';
        final remaining   = (data['remainingAmount'] as num?)?.toDouble() ?? 0;

        String? notifTitle;
        String? notifMessage;
        String notifType = 'order_status';

        switch (status) {
          case ClientOrderStatus.confirmed:
            notifTitle   = '🍳 Commande en ligne confirmée';
            notifMessage = 'Commande $orderNumber de $clientName — confirmée';
            notifType    = 'kitchen_online_order';
            break;
          case ClientOrderStatus.preparing:
            notifTitle   = '🍳 Commande envoyée en cuisine';
            notifMessage = 'Commande $orderNumber de $clientName — en cuisine';
            notifType    = 'order_preparing';
            break;
          case ClientOrderStatus.ready:
            notifTitle   = '✅ Commande prête';
            notifMessage = 'Commande $orderNumber de $clientName est PRÊTE';
            notifType    = 'order_ready';
            break;
          case ClientOrderStatus.delivering:
            notifTitle   = '🚗 En livraison';
            notifMessage = 'Commande $orderNumber — Yango en route vers $clientName';
            notifType    = 'order_delivering';
            break;
          case ClientOrderStatus.delivered:
            notifTitle   = '💰 Solde à encaisser';
            notifMessage = remaining > 0
                ? 'Commande $orderNumber livrée — solde à encaisser'
                : 'Commande $orderNumber livrée et soldée ✓';
            notifType    = 'order_settled';
            break;
          case ClientOrderStatus.cancelled:
            notifTitle   = '❌ Commande annulée';
            notifMessage = 'Commande $orderNumber de $clientName annulée';
            notifType    = 'order_cancelled';
            break;
          default:
            break;
        }

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
      }
    } catch (_) {
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

  /// SOURCE UNIQUE : update direct du doc orders par orderId.
  /// [orderId] = id du doc orders (widget.order.id depuis streamAdminOnlineOrders)
  /// Plus de triple-stratégie, plus de client_orders.
  Future<void> sendToKitchen(String orderId) async {
    debugPrint('[sendToKitchen] START orderId=$orderId');

    await _db.collection('orders').doc(orderId).update({
      'sentToKitchen':   true,
      'kitchenStatus':   'pending',
      'sentToKitchenAt': FieldValue.serverTimestamp(),
      'status':          'pending',
      'orderStatus':     'sent_to_kitchen',
      'adminStatus':     'sent_to_kitchen',
      'updatedAt':       FieldValue.serverTimestamp(),
    });
    debugPrint('[sendToKitchen] ✅ orders/$orderId → sentToKitchen=true kitchenStatus=pending');

    // Notification Firestore
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        final clientName  = data['clientName']  as String? ?? 'Client';
        final orderNumber = data['orderNumber'] as String? ?? '';
        final notifId     = _uuid.v4();
        await _db.collection('notifications').doc(notifId).set({
          'id':          notifId,
          'type':        'order_preparing',
          'title':       '🍳 Commande envoyée en cuisine',
          'message':     'Commande $orderNumber de $clientName envoyée en cuisine',
          'orderId':     orderId,
          'createdAt':   FieldValue.serverTimestamp(),
          'isRead':      false,
          'read':        false,
          'targetRoles': ['admin', 'manager', 'kitchen', 'cashier'],
        });
      }
    } catch (e) {
      debugPrint('[sendToKitchen] ❌ Notif: $e');
    }
  }

  /// SOURCE UNIQUE : annule la commande dans 'orders' directement.
  /// [orderId] = id du doc orders
  Future<void> cancelOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status':        ClientOrderStatus.cancelled.index,
      'kitchenStatus': 'cancelled',
      'adminStatus':   'cancelled',
      'orderStatus':   'cancelled',
      'sentToKitchen': false,
      'updatedAt':     FieldValue.serverTimestamp(),
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

    // ── Vérification : payé + livré/servi ─────────────────────────────────
    final deliveryStatusIndex = (data['status'] as num?)?.toInt() ?? -1;
    final paymentStatusIndex  = (data['paymentStatus'] as num?)?.toInt() ?? -1;
    final isDelivered  = deliveryStatusIndex == 5; // ClientOrderStatus.delivered
    final isFullyPaid  = paymentStatusIndex  == 2; // ClientPaymentStatus.fullyPaid
    final paymentMethod    = (data['paymentMethod'] as num?)?.toInt() ?? -1;
    final isCashOnDelivery = paymentMethod == 0;
    final paymentOk = isFullyPaid || (isCashOnDelivery && isDelivered);

    if (!isDelivered || !paymentOk) {
      debugPrintOrder('[loyalty] Conditions non remplies (delivered=$isDelivered, paymentOk=$paymentOk) — skip');
      return;
    }

    // ── Marquer AVANT toute écriture (protection crash/double appel) ──────
    await _db.collection('orders').doc(clientOrderId).update({
      'loyaltyPointsAwarded':   true,
      'loyaltyPointsAwardedAt': FieldValue.serverTimestamp(),
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

  Future<void> signOutAllDevices() async {
    // Firebase Auth n'a pas de "signout all devices" natif côté client.
    // On renouvelle le token en forçant un refresh, puis déconnecte localement.
    await _auth.currentUser?.getIdToken(true);
    await _auth.signOut();
  }
}
