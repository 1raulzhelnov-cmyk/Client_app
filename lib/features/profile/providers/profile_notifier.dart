import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/user_model.dart';

typedef JsonMap = Map<String, dynamic>;

final profileNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ProfileNotifier, UserModel>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AutoDisposeAsyncNotifier<UserModel> {
  @override
  Future<UserModel> build() async {
    final authState = ref.watch(authNotifierProvider);
    final authUser = authState.valueOrNull;
    final firebaseAuth = ref.read(firebaseAuthProvider);
    final uid = authUser?.id ?? firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }

    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      final doc = await firestoreService.getUserDoc(uid);
      if (doc == null) {
        if (authUser != null) {
          return authUser;
        }
        final firebaseUser = firebaseAuth.currentUser;
        if (firebaseUser != null) {
          return UserModel.fromFirebase(firebaseUser);
        }
        throw const Failure(message: 'Данные пользователя недоступны.');
      }
      return UserModel.fromJson(doc);
    } on Failure {
      rethrow;
    } catch (error) {
      throw Failure(message: error.toString());
    }
  }

  Future<void> updateName(String name) async {
    await updateProfile({'name': name.trim()});
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = AsyncError(
        const Failure(message: 'Профиль не загружен.'),
        StackTrace.current,
      );
      return;
    }

    final sanitized = Map<String, dynamic>.fromEntries(
      data.entries.where((entry) {
        final value = entry.value;
        if (value == null) {
          return false;
        }
        if (value is String) {
          return value.trim().isNotEmpty;
        }
        return true;
      }),
    );
    if (sanitized.isEmpty) {
      return;
    }

    state = const AsyncLoading();
    final apiService = ref.read(apiServiceProvider);
    final firestoreService = ref.read(firestoreServiceProvider);

    final result = await apiService.patch<JsonMap>(
      '/profile',
      body: sanitized,
    );

    state = await result.fold<FutureOr<AsyncValue<UserModel>>>(
      (failure) async => AsyncError(failure, StackTrace.current),
      (_) async {
        await firestoreService.updateUser(previous.id, sanitized);
        final updated = previous.copyWith(
          name: sanitized['name'] as String? ?? previous.name,
          phone: sanitized['phone'] as String? ?? previous.phone,
          photoUrl: sanitized['photoUrl'] as String? ?? previous.photoUrl,
        );
        return AsyncData(updated);
      },
    );
  }

  Future<String> uploadPhoto(File file) async {
    state = const AsyncLoading();
    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      final url = await firestoreService.uploadPhoto(file);
      await updateProfile({'photoUrl': url});
      return url;
    } on Failure catch (failure, stackTrace) {
      state = AsyncError(failure, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final failure = Failure(message: error.toString());
      state = AsyncError(failure, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    final firebaseAuth = ref.read(firebaseAuthProvider);
    final user = firebaseAuth.currentUser;
    if (user == null) {
      state = AsyncError(
        const Failure(message: 'Пользователь не авторизован.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      await user.delete();
      await ref.read(authNotifierProvider.notifier).logout();
    } on FirebaseAuthException catch (error, stackTrace) {
      state = AsyncError(
        Failure(
          message: error.message ?? 'Не удалось удалить аккаунт.',
          code: error.code,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      state = AsyncError(
        Failure(message: error.toString()),
        stackTrace,
      );
    }
  }
}
