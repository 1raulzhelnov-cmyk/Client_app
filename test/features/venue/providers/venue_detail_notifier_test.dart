import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/venue/providers/venue_detail_notifier.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/models/venue_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('venueDetailProvider', () {
    late ProviderContainer container;
    late _MockApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      apiService = _MockApiService();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('возвращает модель заведения при успешном ответе API', () async {
      final response = <String, dynamic>{
        'id': 'venue-123',
        'name': 'Test Venue',
        'type': 'food',
        'rating': 4.6,
        'cuisines': ['итальянская'],
        'avgPrice': 950,
        'photos': ['https://example.com/venue.jpg'],
        'deliveryFee': 150,
        'deliveryTimeMinutes': '25-35',
        'address': <String, dynamic>{
          'id': 'addr-1',
          'formatted': 'Москва, ул. Пушкина, 10',
          'lat': 55.751999,
          'lng': 37.617734,
          'instructions': 'Домофон 123',
          'isDefault': false,
        },
        'description': 'Аутентичная итальянская кухня.',
        'isOpen': true,
        'hours': <String, String>{'mon-fri': '10:00-23:00'},
        'contacts': <String, String>{
          'phone': '+7 900 123-45-67',
          'instagram': '@testvenue',
        },
        'menu': [
          <String, dynamic>{
            'id': 'pizza-margherita',
            'venueId': 'venue-123',
            'name': 'Пицца Маргарита',
            'description': 'Классическая с томатами и базиликом',
            'price': 610,
            'imageUrl': '',
            'available': true,
            'category': 'Пиццы',
            'type': ProductType.food.name,
          },
          <String, dynamic>{
            'id': 'tiramisu',
            'venueId': 'venue-123',
            'name': 'Тирамису',
            'description': 'Домашний десерт со сливочным кремом',
            'price': 320,
            'imageUrl': '',
            'available': true,
            'category': 'Десерты',
            'type': ProductType.food.name,
          },
        ],
      };

      when(
        apiService.get<Map<String, dynamic>>('/venues/venue-123'),
      ).thenAnswer((_) async => right(response));

      final venue =
          await container.read(venueDetailProvider('venue-123').future);

      expect(venue, isA<VenueModel>());
      expect(venue.id, equals('venue-123'));
      expect(venue.menu, hasLength(2));
      expect(venue.contacts['phone'], equals('+7 900 123-45-67'));
    });

    test('пробрасывает Failure при ошибке API', () async {
      const failure = Failure(message: 'Сервис недоступен');

      when(
        apiService.get<Map<String, dynamic>>('/venues/error-venue'),
      ).thenAnswer((_) async => left(failure));

      expect(
        () => container.read(venueDetailProvider('error-venue').future),
        throwsA(failure),
      );
    });

    test('генерирует ParsingFailure при неверном ответе', () async {
      when(
        apiService.get<Map<String, dynamic>>('/venues/broken-venue'),
      ).thenAnswer((_) async => right(<String, dynamic>{'unexpected': true}));

      expect(
        () => container.read(venueDetailProvider('broken-venue').future),
        throwsA(isA<ParsingFailure>()),
      );
    });
  });
}
