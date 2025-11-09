import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late MockFirebaseAuth firebaseAuth;
    late MockApiService apiService;
    late AuthService service;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      apiService = MockApiService();
      service = AuthService(
        firebaseAuth: firebaseAuth,
        apiService: apiService,
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
  });
}
