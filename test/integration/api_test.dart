import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService', () {
    late MockHttpClient client;
    late MockFirebaseAuth auth;
    late MockUser user;
    late ApiService service;

    setUp(() {
      client = MockHttpClient();
      auth = MockFirebaseAuth();
      user = MockUser();
      service = ApiService(
        client: client,
        firebaseAuth: auth,
        baseUrl: 'https://api.example.com',
      );
    });

    test('successful GET request returns Right result', () async {
      when(auth.currentUser).thenReturn(user);
      when(user.getIdToken()).thenAnswer((_) async => 'token');
      when(
        client.get(
          Uri.parse('https://api.example.com/test'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"message":"ok"}', 200),
      );

      final result = await service.get<String>(
        '/test',
        decoder: (dynamic data) => data['message'] as String,
      );

      expect(result, isA<Right<Failure, String>>());
      expect(result.getOrElse(() => ''), 'ok');
    });
  });
}
