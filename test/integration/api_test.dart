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
    late Uri testUri;

    setUp(() {
      client = MockHttpClient();
      auth = MockFirebaseAuth();
      user = MockUser();
      testUri = Uri.parse('https://api.example.com/test');
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
          testUri,
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

    test('повторяет запрос после 401 и успешного обновления токена', () async {
      when(auth.currentUser).thenReturn(user);
      when(user.getIdToken()).thenAnswer((_) async => 'initial-token');
      when(user.getIdToken(true)).thenAnswer((_) async => 'refreshed-token');

      var attempts = 0;
      when(
        client.get(
          testUri,
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async {
        attempts += 1;
        if (attempts == 1) {
          return http.Response('Unauthorized', 401);
        }
        return http.Response('{"data":"ok"}', 200);
      });

      final result = await service.get<String>(
        '/test',
        decoder: (dynamic data) => data['data'] as String,
      );

      expect(result.getOrElse(() => ''), 'ok');
      expect(attempts, equals(2));
      verify(user.getIdToken(true)).called(1);
    });

    test('возвращает ServerFailure при ошибке 500', () async {
      when(auth.currentUser).thenReturn(user);
      when(user.getIdToken()).thenAnswer((_) async => 'token');
      when(
        client.get(
          testUri,
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"message":"server"}', 500),
      );

      final result = await service.get<dynamic>('/test');

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse(() => Failure(message: '')),
        isA<ServerFailure>()
            .having((failure) => failure.message, 'message', contains('server')),
      );
    });

    test('возвращает NetworkFailure когда клиент выбрасывает исключение',
        () async {
      when(auth.currentUser).thenReturn(user);
      when(user.getIdToken()).thenAnswer((_) async => 'token');
      when(
        client.get(
          testUri,
          headers: anyNamed('headers'),
        ),
      ).thenThrow(Exception('socket error'));

      final result = await service.get<dynamic>('/test');

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse(() => Failure(message: '')),
        isA<NetworkFailure>(),
      );
    });
  });
}
