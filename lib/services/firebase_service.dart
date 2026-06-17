import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =================== AUTH ===================

  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentFirebaseUser => _auth.currentUser;

  // =================== USERS ===================

  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('[FirebaseService] getUserByUid error: $e');
      return null;
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final q = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        return AppUser.fromMap({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('[FirebaseService] getUserByEmail error: $e');
      return null;
    }
  }

  Stream<List<AppUser>> streamUsers() {
    return _db.collection('users').snapshots().map((snap) => snap.docs
        .map((d) => AppUser.fromMap({...d.data(), 'id': d.id}))
        .toList());
  }

  Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(AppUser user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> setUserOnline(String uid, bool online) async {
    try {
      await _db.collection('users').doc(uid).update({'isOnline': online});
    } catch (_) {}
  }

  // =================== PRODUCTS ===================

  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snap) => snap.docs
        .map((d) => Product.fromMap({...d.data(), 'id': d.id}))
        .toList());
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

  // =================== ORDERS ===================

  Stream<List<Order>> streamOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Order.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> saveOrder(Order order) async {
    await _db.collection('orders').doc(order.id).set(order.toMap());
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

  // =================== STOCK ===================

  Stream<List<StockItem>> streamStock() {
    return _db.collection('stock').snapshots().map((snap) => snap.docs
        .map((d) => StockItem.fromMap({...d.data(), 'id': d.id}))
        .toList());
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

  Stream<List<ChatMessage>> streamMessages() {
    return _db
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> sendMessage(ChatMessage message) async {
    await _db.collection('messages').doc(message.id).set(message.toMap());
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.collection('messages').doc(messageId).delete();
  }

  // =================== SUPPLIERS ===================

  Stream<List<Supplier>> streamSuppliers() {
    return _db.collection('suppliers').snapshots().map((snap) => snap.docs
        .map((d) => Supplier.fromMap({...d.data(), 'id': d.id}))
        .toList());
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

  Stream<List<SupplierOrder>> streamSupplierOrders() {
    return _db
        .collection('supplierOrders')
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SupplierOrder.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> saveSupplierOrder(SupplierOrder order) async {
    await _db.collection('supplierOrders').doc(order.id).set(order.toMap());
  }

  Future<void> updateSupplierOrder(SupplierOrder order) async {
    await _db.collection('supplierOrders').doc(order.id).update(order.toMap());
  }

  // =================== ATTENDANCES ===================

  Stream<List<Attendance>> streamAttendances() {
    return _db.collection('attendances').snapshots().map((snap) => snap.docs
        .map((d) => Attendance.fromMap({...d.data(), 'id': d.id}))
        .toList());
  }

  Future<void> saveAttendance(Attendance attendance) async {
    await _db
        .collection('attendances')
        .doc(attendance.id)
        .set(attendance.toMap());
  }
}
