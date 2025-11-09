import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/failure.dart';
import '../../models/cart_item_model.dart';
import '../../models/customization_option.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

class FirestoreService {
  FirestoreService({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseAuth firebaseAuth,
  })  : _firestore = firestore,
        _storage = storage,
        _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> _cartCollection(String uid) =>
      _usersCollection.doc(uid).collection('cart');
  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection('orders');

  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return {
        'id': uid,
        ...data,
      };
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось получить данные профиля.',
        code: error.code,
      );
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final sanitized = Map<String, dynamic>.fromEntries(
      data.entries.where((entry) => entry.value != null),
    );
    if (sanitized.isEmpty) {
      return;
    }
    try {
      await _usersCollection.doc(uid).set(
            sanitized,
            SetOptions(merge: true),
          );
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось обновить профиль.',
        code: error.code,
      );
    }
  }

  Future<String> uploadPhoto(File file) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    try {
      final ref = _storage.ref().child('users/${user.uid}/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(file, metadata);
      return ref.getDownloadURL();
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось загрузить фото профиля.',
        code: error.code,
      );
    }
  }

  /// Поток корзины текущего пользователя с синхронизацией в реальном времени.
  Stream<List<CartItemModel>> getCartStream() {
    final user = currentUser;
    if (user == null) {
      return const Stream<List<CartItemModel>>.value(<CartItemModel>[]);
    }
    final collection = _cartCollection(user.uid)
        .orderBy('createdAt', descending: false)
        .withConverter<CartItemModel>(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data();
            if (data == null) {
              throw const Failure(message: 'Элемент корзины отсутствует.');
            }
            final json = Map<String, dynamic>.from(data);
            json['id'] = snapshot.id;
            return CartItemModel.fromJson(json);
          },
          toFirestore: (item, _) => item.toFirestoreJson(),
        );

    return collection.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
    );
  }

  Stream<OrderModel> getOrderStream(String orderId) {
    final normalizedId = orderId.trim();
    if (normalizedId.isEmpty) {
      return Stream<OrderModel>.error(
        const Failure(message: 'Идентификатор заказа не указан.'),
      );
    }

    final docRef = _ordersCollection.doc(normalizedId);
    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw const Failure(message: 'Заказ не найден.');
      }
      final data = snapshot.data();
      if (data == null) {
        throw const Failure(message: 'Данные заказа недоступны.');
      }
      final json = Map<String, dynamic>.from(data);
      json['id'] = snapshot.id;
      return OrderModel.fromJson(json);
    }).handleError((error, stackTrace) {
      if (error is FirebaseException) {
        throw Failure(
          message: error.message ?? 'Не удалось получить статус заказа.',
          code: error.code,
        );
      }
      throw error;
    });
  }

  Future<void> addToCart(CartItemModel item) async {
    final user = currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }

    try {
      final collection = _cartCollection(user.uid);
      final existing = await collection
          .where('itemKey', isEqualTo: item.itemKey)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first.reference;
        await doc.update({
          'quantity': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await collection.add({
          ...item.toFirestoreJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось обновить корзину.',
        code: error.code,
      );
    }
  }

  Future<void> updateCartItem({
    required String cartItemId,
    int? quantity,
    List<CustomizationOption>? selectedCustomizations,
    String? note,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }
    if (quantity != null && quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (quantity != null) {
      updates['quantity'] = quantity;
    }
    if (selectedCustomizations != null) {
      updates['selectedCustom'] =
          selectedCustomizations.map((option) => option.toJson()).toList();
      final productSnapshot =
          await _cartCollection(user.uid).doc(cartItemId).get();
      final currentData = productSnapshot.data();
      if (currentData != null) {
        final productJson = Map<String, dynamic>.from(
          (currentData['product'] ?? <String, dynamic>{}) as Map,
        );
        final product = ProductModel.fromJson(productJson);
        final newItem = CartItemModel(
          id: cartItemId,
          product: product,
          quantity: quantity ?? (currentData['quantity'] as int? ?? 1),
          selectedCustomizations: selectedCustomizations,
          note: note ?? currentData['note'] as String?,
        );
        updates['itemKey'] = newItem.itemKey;
      }
    }
    if (note != null) {
      updates['note'] = note;
    }

    try {
      await _cartCollection(user.uid).doc(cartItemId).update(updates);
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось обновить корзину.',
        code: error.code,
      );
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    final user = currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }

    try {
      await _cartCollection(user.uid).doc(cartItemId).delete();
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось удалить товар из корзины.',
        code: error.code,
      );
    }
  }

  Future<void> clearCart() async {
    final user = currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }

    try {
      final batch = _firestore.batch();
      final snapshot = await _cartCollection(user.uid).get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Failure(
        message: error.message ?? 'Не удалось очистить корзину.',
        code: error.code,
      );
    }
  }
}
