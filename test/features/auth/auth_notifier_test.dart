import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier', () {
    late MockAuthService authService;
    late MockFirebaseAuth firebaseAuth;
    late ProviderContainer container;
    late AuthNotifier notifier;

    setUp(() {
      authService = MockAuthService();
      firebaseAuth = MockFirebaseAuth();
      when(firebaseAuth.currentUser).thenReturn(null);

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          firebaseAuthProvider.overrideWithValue(firebaseAuth),
        ],
      );
      addTearDown(container.dispose);

      notifier = container.read(authNotifierProvider.notifier);
    });

    test('loginEmail updates state with user on success', () async {
      const email = 'test@example.com';
      const password = 'Password1';
      const expectedUser = UserModel(
        id: 'uid-123',
        name: 'Tester',
        email: email,
      );

      when(authService.loginWithEmail(email, password))
          .thenAnswer((_) async => right(expectedUser));

      await notifier.loginEmail(email, password);

      final state = container.read(authNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasValue, isTrue);
      expect(state.value, equals(expectedUser));
      verify(authService.loginWithEmail(email, password)).called(1);
    });
  });
}
