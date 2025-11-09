import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/flowers/providers/flower_notifier.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

Map<String, dynamic> _flower({
  required String id,
  required String name,
  String? occasion,
  String? season,
}) =>
    <String, dynamic>{
      'id': id,
      'venueId': 'venue-1',
      'name': name,
      'description': '$name description',
      'price': 1990,
      'imageUrl': 'https://example.com/$id.jpg',
      'occasion': occasion,
      'season': season,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flowerProvider', () {
    late MockApiService apiService;
    late ProviderContainer container;

    setUp(() {
      apiService = MockApiService();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('применяет occasion фильтр и сортирует по имени', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        expect(params['type'], 'flowers');
        expect(params['occasion'], 'birthday');
        expect(params['limit'], '50');
        return right([
          _flower(id: 'rose', name: 'Розы', occasion: 'birthday'),
          _flower(id: 'chamomile', name: 'Ромашки', occasion: 'birthday'),
          _flower(id: 'tulip', name: 'Тюльпаны', occasion: 'birthday'),
        ]);
      });

      final flowers = await container
          .read(flowerProvider(const FlowerQuery(occasion: 'Birthday')).future);

      expect(flowers, hasLength(3));
      expect(
        flowers.map((f) => f.name),
        orderedEquals(['Ромашки', 'Розы', 'Тюльпаны']),
      );
    });

    test('передаёт season, search и limit в параметры', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        expect(params['season'], 'spring');
        expect(params['search'], 'ранние');
        expect(params['limit'], '12');
        return right([
          _flower(id: 'spring-1', name: 'Весенний сет', season: 'spring'),
        ]);
      });

      final query =
          const FlowerQuery(season: 'Spring', search: ' ранние ', limit: 12);
      final flowers = await container.read(flowerProvider(query).future);

      expect(flowers.single.season, 'spring');
    });

    test('выбрасывает Failure при некорректном ответе API', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((_) async => right(<String, dynamic>{'unexpected': true}));

      expect(
        () => container.read(flowerProvider(const FlowerQuery()).future),
        throwsA(isA<ParsingFailure>()),
      );
    });
  });
}
