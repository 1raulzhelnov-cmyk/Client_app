import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/failure.dart';

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

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

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
}
