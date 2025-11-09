import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/flowers/providers/flower_notifier.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flowerProvider', () {
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
    });

    test('applies occasion filter to query parameters', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );

        expect(params['type'], equals('flowers'));
        expect(params['occasion'], equals('birthday'));
        expect(params.containsKey('season'), isFalse);

        return right([
          <String, dynamic>{
            'id': 'flower-1',
            'venueId': 'venue-1',
            'name': 'Ruby Roses',
            'description': '12 red roses with greenery',
            'price': 1990,
            'imageUrl': '',
            'occasion': 'birthday',
            'season': 'spring',
          },
        ]);
      });

      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);

      final flowers = await container.read(
        flowerProvider(const FlowerQuery(occasion: 'Birthday')).future,
      );

      expect(flowers, hasLength(1));
      expect(flowers.first.name, 'Ruby Roses');
      expect(flowers.first.occasion?.toLowerCase(), 'birthday');

      verify(
        apiService.get<dynamic>(
          '/products',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });
  });
}
