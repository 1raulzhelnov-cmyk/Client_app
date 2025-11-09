import 'dart:async';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockApiService extends Mock implements ApiService {}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._user);

  final UserModel _user;
  bool logoutCalled = false;

  @override
  FutureOr<UserModel?> build() => _user;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileNotifier deleteAccount', () {
    late ProviderContainer container;
    late MockFirebaseAuth firebaseAuth;
    late MockFirebaseUser firebaseUser;
    late MockFirestoreService firestoreService;
    late MockApiService apiService;
    late _StubAuthNotifier authNotifier;
    late UserModel user;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      firebaseUser = MockFirebaseUser();
      firestoreService = MockFirestoreService();
      apiService = MockApiService();
      user = const UserModel(
        id: 'uid-123',
        name: 'Tester',
        email: 'test@example.com',
      );
      authNotifier = _StubAuthNotifier(user);

      when(firebaseAuth.currentUser).thenReturn(firebaseUser);
      when(firebaseUser.uid).thenReturn(user.id);
      when(firebaseUser.delete()).thenAnswer((_) async {});
      when(firestoreService.getUserDoc(user.id)).thenAnswer(
        (_) async => {
          'id': user.id,
          'name': user.name,
          'email': user.email,
        },
      );

      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(firebaseAuth),
          firestoreServiceProvider.overrideWithValue(firestoreService),
          apiServiceProvider.overrideWithValue(apiService),
          authNotifierProvider.overrideWith(() => authNotifier),
        ],
      );
      addTearDown(container.dispose);
    });

    test('deletes firebase user and triggers logout', () async {
      await container.read(profileNotifierProvider.future);
      await container.read(profileNotifierProvider.notifier).deleteAccount();

      verify(firebaseUser.delete()).called(1);
      expect(authNotifier.logoutCalled, isTrue);
    });
  });
}
