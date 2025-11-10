import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/home/providers/venue_notifier.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/venue_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiService extends Mock implements ApiService {}

final _baseVenueJson = <String, dynamic>{
  'id': 'venue-1',
  'name': 'La Pasta',
  'type': 'food',
  'rating': 4.5,
  'cuisines': ['итальянская'],
  'avgPrice': 950,
  'photos': ['https://example.com/venue-1.jpg'],
  'deliveryFee': 150,
  'deliveryTimeMinutes': '30-40',
  'address': const AddressModel(
    id: 'addr-1',
    formatted: 'Москва, ул. Тверская, 1',
    lat: 55.7558,
    lng: 37.6173,
    instructions: 'Позвонить за 5 минут',
  ).toJson(),
  'hours': <String, String>{'mon-fri': '10:00-22:00'},
};

Map<String, dynamic> _response({
  required List<Map<String, dynamic>> venues,
  bool hasNext = false,
}) {
  return <String, dynamic>{
    'venues': venues,
    'pagination': <String, dynamic>{'hasNext': hasNext},
  };
}

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

    test('fetchVenues применяет фильтры и кэширует результат', () async {
      final filtersNotifier =
          container.read(venueFiltersNotifierProvider.notifier);
      filtersNotifier
        ..setType('food')
        ..setCuisine('итальянская')
        ..setMinRating(4.0)
        ..setMaxAvgPrice(1200)
        ..setSort(VenueSort.priceAsc);

      when(
        apiService.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        expect(params['type'], 'food');
        expect(params['cuisine'], 'итальянская');
        expect(params['minRating'], '4.0');
        expect(params['maxPrice'], '1200');
        expect(params['sort'], 'price_asc');
        expect(params['page'], '1');
        expect(params['limit'], '20');
        return right(
          _response(
            venues: [_baseVenueJson],
            hasNext: true,
          ),
        );
      });

      final venues = await container.read(venueNotifierProvider.future);
      expect(venues, hasLength(1));
      expect(venues.first.name, 'La Pasta');

      final prefs = await container.read(sharedPrefsProvider.future);
      final cacheKey =
          'venues_cache_cuisine=итальянская&limit=20&maxPrice=1200&minRating=4.0&sort=price_asc&type=food';
      expect(prefs.getString(cacheKey), isNotNull);
    });

    test('loadMore догружает вторую страницу и обновляет кэш', () async {
      final venuesPage1 = [_baseVenueJson];
      final venuesPage2 = [
        {
          ..._baseVenueJson,
          'id': 'venue-2',
          'name': 'Tokyo Line',
        },
      ];

      when(
        apiService.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        final page = params['page'];
        if (page == '1') {
          return right(_response(venues: venuesPage1, hasNext: true));
        } else if (page == '2') {
          return right(_response(venues: venuesPage2, hasNext: false));
        }
        return right(_response(venues: []));
      });

      final notifier = container.read(venueNotifierProvider.notifier);
      await notifier.build(); // initial load
      await notifier.loadMore();

      final state = container.read(venueNotifierProvider);
      expect(state.value, hasLength(2));
      expect(state.value?.last.name, 'Tokyo Line');
      expect(notifier.hasMore, isFalse);
    });

    test('fetchVenues возвращает данные из кэша при ошибке API', () async {
      final cacheKey = 'venues_cache_limit=20&sort=rating_desc&type=food';
      final cachedJson = jsonEncode([
        VenueModel(
          id: 'cached-1',
          name: 'Cached Venue',
          type: VenueType.food,
          rating: 4.2,
          cuisines: const ['итальянская'],
          averagePrice: 890,
          photos: const ['https://example.com/cached.jpg'],
          deliveryFee: 100,
          deliveryTimeMinutes: '20-30',
          address: const AddressModel(
            id: 'cached-addr',
            formatted: 'Москва, cached',
            lat: 55.7,
            lng: 37.6,
            instructions: 'позвонить',
          ),
        ).toJson(),
      ]);
      SharedPreferences.setMockInitialValues(<String, Object>{
        cacheKey: cachedJson,
      });

      apiService = MockApiService();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );

      when(
        apiService.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((_) async => left(NetworkFailure(message: 'offline')));

      final notifier = container.read(venueNotifierProvider.notifier);
      final venues = await notifier.fetchVenues(
        container.read(venueFilterProvider),
        page: 1,
      );

      expect(venues, hasLength(1));
      expect(venues.first.name, 'Cached Venue');
      expect(notifier.hasMore, isFalse);
    });
  });
}
