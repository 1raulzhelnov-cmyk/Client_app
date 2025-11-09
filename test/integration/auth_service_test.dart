import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockApiService extends Mock implements ApiService {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockAppleSignInFacade extends Mock implements AppleSignInFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late MockFirebaseAuth firebaseAuth;
    late MockApiService apiService;
    late MockGoogleSignIn googleSignIn;
    late MockAppleSignInFacade appleSignIn;
    late AuthService service;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      apiService = MockApiService();
      googleSignIn = MockGoogleSignIn();
      appleSignIn = MockAppleSignInFacade();
      service = AuthService(
        firebaseAuth: firebaseAuth,
        apiService: apiService,
        googleSignIn: googleSignIn,
        appleSignIn: appleSignIn,
      );
    });

    test('loginWithEmail returns user model when Firebase succeeds', () async {
      const email = 'test@example.com';
      const password = 'Password1';
      final credential = MockUserCredential();
      final firebaseUser = MockUser();

      when(firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenAnswer((_) async => credential);
      when(credential.user).thenReturn(firebaseUser);
      when(firebaseUser.uid).thenReturn('uid-123');
      when(firebaseUser.displayName).thenReturn('Tester');
      when(firebaseUser.email).thenReturn(email);
      when(firebaseUser.phoneNumber).thenReturn('+10000000000');
      when(firebaseUser.photoURL).thenReturn(null);

      final result = await service.loginWithEmail(email, password);

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected success but got $failure'),
        (user) {
          expect(user, isA<UserModel>());
          expect(user.id, 'uid-123');
          expect(user.email, email);
        },
      );
      verify(firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).called(1);
    });

    test('googleSignIn maps firebase user to domain model', () async {
      final googleAccount = MockGoogleSignInAccount();
      final googleAuth = MockGoogleSignInAuthentication();
      final credential = MockUserCredential();
      final firebaseUser = MockUser();

      when(firebaseAuth.currentUser).thenReturn(null);
      when(googleSignIn.signIn()).thenAnswer((_) async => googleAccount);
      when(googleAccount.authentication).thenAnswer((_) async => googleAuth);
      when(googleAuth.idToken).thenReturn('id-token');
      when(googleAuth.accessToken).thenReturn('access-token');
      when(firebaseAuth.signInWithCredential(any))
          .thenAnswer((_) async => credential);
      when(credential.user).thenReturn(firebaseUser);
      when(firebaseUser.uid).thenReturn('uid-123');
      when(firebaseUser.displayName).thenReturn('Tester');
      when(firebaseUser.email).thenReturn('test@example.com');
      when(firebaseUser.phoneNumber).thenReturn('+10000000000');
      when(firebaseUser.photoURL).thenReturn(null);

      final result = await service.googleSignIn();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected success'),
        (user) {
          expect(user, isA<UserModel>());
          expect(user.id, 'uid-123');
          expect(user.email, 'test@example.com');
        },
      );

      final capturedCredential =
          verify(firebaseAuth.signInWithCredential(captureAny))
              .captured
              .single as OAuthCredential;
      expect(capturedCredential.providerId, equals('google.com'));
      verify(googleSignIn.signIn()).called(1);
    });
  });
}
