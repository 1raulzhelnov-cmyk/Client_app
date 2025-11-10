import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier', () {
    late MockAuthService authService;
    late MockFirebaseAuth firebaseAuth;
    late ProviderContainer container;
    late AuthNotifier notifier;
    late MockUser firebaseUser;

    setUp(() {
      authService = MockAuthService();
      firebaseAuth = MockFirebaseAuth();
      firebaseUser = MockUser();
      when(firebaseAuth.currentUser).thenReturn(null);
      when(firebaseUser.uid).thenReturn('uid-123');

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

    test('loginEmail sets AsyncError on failure', () async {
      const email = 'fail@example.com';
      const password = 'BadPassword';
      final failure = Failure(message: 'Неверный логин');

      when(authService.loginWithEmail(email, password))
          .thenAnswer((_) async => left(failure));

      await notifier.loginEmail(email, password);

      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, failure);
    });

    test('registerEmail stores user on success', () async {
      const email = 'new@example.com';
      const password = 'Password1!';
      const createdUser = UserModel(
        id: 'uid-999',
        name: 'Новый пользователь',
        email: email,
      );

      when(authService.registerWithEmail(email, password))
          .thenAnswer((_) async => right(createdUser));

      await notifier.registerEmail(email, password);

      final state = container.read(authNotifierProvider);
      expect(state.value, createdUser);
    });

    test('sendOtp caches verification and returns result', () async {
      const phone = '+1234567890';
      const verificationId = 'verification-123';
      final otpResult = OtpVerificationResult(
        verificationId: verificationId,
        resendToken: 42,
      );

      when(
        authService.sendOtp(
          phone: phone,
          forceResendToken: anyNamed('forceResendToken'),
        ),
      ).thenAnswer((_) async => right(otpResult));

      final result = await notifier.sendOtp(phone);

      expect(result, isNotNull);
      expect(result!.verificationId, verificationId);
      expect(container.read(authNotifierProvider).hasError, isFalse);
    });

    test('verifyOtp without stored verification id emits failure', () async {
      await notifier.verifyOtp('123456');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<AuthFailure>()
            .having(
              (failure) => failure.message,
              'message',
              contains('Отсутствует идентификатор'),
            ),
      );
    });

    test('verifyOtp succeeds with stored verification id', () async {
      const phone = '+19998887766';
      const verificationId = 'vid-777';
      const verifiedUser = UserModel(
        id: 'uid-verified',
        name: 'OTP User',
      );

      when(
        authService.sendOtp(
          phone: phone,
          forceResendToken: anyNamed('forceResendToken'),
        ),
      ).thenAnswer(
        (_) async => right(
          const OtpVerificationResult(
            verificationId: verificationId,
          ),
        ),
      );

      when(
        authService.verifyOtp(
          verificationId: verificationId,
          smsCode: anyNamed('smsCode'),
        ),
      ).thenAnswer((_) async => right(verifiedUser));

      await notifier.sendOtp(phone);
      await notifier.verifyOtp('654321');

      final state = container.read(authNotifierProvider);
      expect(state.value, verifiedUser);
      expect(state.hasError, isFalse);
    });

    test('googleSignIn propagates failure message', () async {
      final failure =
          AuthFailure(message: 'Google вход отменён', code: 'cancelled');

      when(authService.googleSignIn()).thenAnswer((_) async => left(failure));

      await notifier.googleSignIn();

      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, failure);
    });

    test('googleSignIn updates state when success', () async {
      const user = UserModel(
        id: 'google-uid',
        name: 'Google User',
      );

      when(authService.googleSignIn()).thenAnswer((_) async => right(user));

      await notifier.googleSignIn();

      final state = container.read(authNotifierProvider);
      expect(state.value, user);
    });

    test('appleSignIn returns error on failure', () async {
      final failure =
          AuthFailure(message: 'Apple error', code: 'apple-failure');
      when(authService.appleSignIn()).thenAnswer((_) async => left(failure));

      await notifier.appleSignIn();

      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, failure);
    });

    test('logout clears state and calls service', () async {
      when(authService.logout()).thenAnswer((_) async => right(unit));
      when(firebaseAuth.currentUser).thenReturn(firebaseUser);

      await notifier.logout();

      final state = container.read(authNotifierProvider);
      expect(state.valueOrNull, isNull);
      verify(authService.logout()).called(1);
    });
  });
}
