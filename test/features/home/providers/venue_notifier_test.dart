import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/home/providers/venue_notifier.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VenueNotifier', () {
    late ProviderContainer container;
    late MockApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
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

    test('fetchVenues applies filters and stores cache', () async {
      final filtersNotifier =
          container.read(venueFiltersNotifierProvider.notifier);
      filtersNotifier
        ..setType('food')
        ..setCuisine('итальянская')
        ..setMinRating(4.0)
        ..setMaxAvgPrice(1200)
        ..setSort(VenueSort.priceAsc);

      final response = <String, dynamic>{
        'venues': [
          <String, dynamic>{
            'id': 'venue-1',
            'name': 'La Pasta',
            'type': 'food',
            'rating': 4.5,
            'cuisines': ['итальянская'],
            'avgPrice': 950,
            'photos': ['https://example.com/venue-1.jpg'],
            'deliveryFee': 150,
            'deliveryTimeMinutes': '30-40',
            'address': <String, dynamic>{
              'id': 'addr-1',
              'formatted': 'Москва, ул. Тверская, 1',
              'lat': 55.7558,
              'lng': 37.6173,
              'instructions': 'Позвонить за 5 минут',
              'isDefault': false,
            },
            'hours': <String, String>{'mon-fri': '10:00-22:00'},
          },
        ],
        'pagination': <String, dynamic>{'hasNext': true},
      };

      when(
        apiService.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        expect(params['type'], equals('food'));
        expect(params['cuisine'], equals('итальянская'));
        expect(params['minRating'], equals('4.0'));
        expect(params['maxPrice'], equals('1200'));
        expect(params['sort'], equals('price_asc'));
        expect(params['page'], equals('1'));
        expect(params['limit'], equals('20'));
        return right(response);
      });

      final venues = await container.read(venueNotifierProvider.future);

      expect(venues, hasLength(1));
      expect(venues.first.name, equals('La Pasta'));

      final prefs = await container.read(sharedPrefsProvider.future);
      final cacheKey =
          'venues_cache_cuisine=итальянская&limit=20&maxPrice=1200&minRating=4.0&sort=price_asc&type=food';
      expect(prefs.getString(cacheKey), isNotNull);

      verify(
        apiService.get<Map<String, dynamic>>(
          '/venues',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });
  });
}
