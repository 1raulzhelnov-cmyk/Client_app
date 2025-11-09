import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockAuthService extends Mock implements AuthService {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserModel? _user;

  @override
  FutureOr<UserModel?> build() => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileNotifier', () {
    late ProviderContainer container;
    late MockApiService apiService;
    late MockFirestoreService firestoreService;
    late MockFirebaseAuth firebaseAuth;
    late MockFirebaseUser firebaseUser;
      late MockAuthService authService;
    late UserModel user;

    setUp(() {
      apiService = MockApiService();
        firestoreService = MockFirestoreService();
      firebaseAuth = MockFirebaseAuth();
      firebaseUser = MockFirebaseUser();
        authService = MockAuthService();
      user = const UserModel(
        id: 'uid-123',
        name: 'Tester',
        email: 'test@example.com',
        phone: '+10000000000',
      );

      when(firebaseAuth.currentUser).thenReturn(firebaseUser);
      when(firebaseUser.uid).thenReturn(user.id);
      when(firestoreService.getUserDoc(user.id)).thenAnswer(
        (_) async => {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
        },
      );
      when(firestoreService.updateUser(any, any)).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
          firestoreServiceProvider.overrideWithValue(firestoreService),
          firebaseAuthProvider.overrideWithValue(firebaseAuth),
            authServiceProvider.overrideWithValue(authService),
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('updateName updates state and persists changes', () async {
      when(
        apiService.patch<JsonMap>(
          any,
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => right(<String, dynamic>{}));

      await container.read(profileNotifierProvider.future);
      final notifier = container.read(profileNotifierProvider.notifier);

      await notifier.updateName('Новое имя');

      final state = container.read(profileNotifierProvider);
      expect(state.hasValue, isTrue);
      expect(state.value?.name, 'Новое имя');
      verify(
        apiService.patch<JsonMap>(
          '/profile',
          body: {'name': 'Новое имя'},
        ),
      ).called(1);
      verify(
        firestoreService.updateUser(
          user.id,
          {'name': 'Новое имя'},
        ),
      ).called(1);
    });

      test('updateName sets error state when API fails', () async {
      final failure = Failure(message: 'Ошибка');
      when(
        apiService.patch<JsonMap>(
          any,
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => left(failure));

      await container.read(profileNotifierProvider.future);
      final notifier = container.read(profileNotifierProvider.notifier);

      await notifier.updateName('Новое имя');

      final state = container.read(profileNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, failure);
      verify(
        apiService.patch<JsonMap>(
          '/profile',
          body: {'name': 'Новое имя'},
        ),
      ).called(1);
      verifyNever(firestoreService.updateUser(any, any));
    });

      test('uploadPhoto обновляет фото и вызывает firestore', () async {
        final tempDir = Directory.systemTemp.createTempSync('profile_upload');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });
        final photo = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1]);

        when(
          apiService.patch<JsonMap>(
            any,
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => right(<String, dynamic>{}));
        when(firestoreService.uploadPhoto(photo)).thenAnswer(
          (_) async => 'https://cdn.test/photo.jpg',
        );

        await container.read(profileNotifierProvider.future);
        final notifier = container.read(profileNotifierProvider.notifier);

        final url = await notifier.uploadPhoto(photo);

        final state = container.read(profileNotifierProvider);
        expect(url, 'https://cdn.test/photo.jpg');
        expect(state.value?.photoUrl, 'https://cdn.test/photo.jpg');
        verify(firestoreService.uploadPhoto(photo)).called(1);
      });

      test('deleteAccount вызывает logout после успешного удаления', () async {
        when(firebaseAuth.currentUser).thenReturn(firebaseUser);
        when(firebaseUser.delete()).thenAnswer((_) async => {});
        when(authService.logout()).thenAnswer((_) async => right(unit));

        await container.read(profileNotifierProvider.future);
        final notifier = container.read(profileNotifierProvider.notifier);

        await notifier.deleteAccount();

        verify(firebaseUser.delete()).called(1);
        verify(authService.logout()).called(1);
        final state = container.read(profileNotifierProvider);
        expect(state.isLoading, isFalse);
        expect(state.hasError, isFalse);
      });
  });
}
