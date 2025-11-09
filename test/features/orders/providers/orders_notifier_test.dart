import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/orders/providers/orders_notifier.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

Map<String, dynamic> _orderPayload({
  required String id,
  OrderStatus status = OrderStatus.placed,
  DateTime? createdAt,
  double total = 1200,
}) {
  final timestamp = (createdAt ?? DateTime(2024, 5, 10, 12)).toIso8601String();
  return <String, dynamic>{
    'id': id,
    'userId': 'user-1',
    'items': const <Map<String, dynamic>>[
      {
        'id': 'item-1',
        'quantity': 1,
        'product': <String, dynamic>{
          'id': 'product-1',
          'venueId': 'venue-1',
          'name': 'Товар',
          'description': 'Описание',
          'price': 1200,
          'imageUrl': '',
          'type': 'food',
        },
        'selectedCustom': <Map<String, dynamic>>[],
      },
    ],
    'total': total,
    'deliveryFee': 0,
    'cashFee': 0,
    'address': const <String, dynamic>{
      'id': 'addr-1',
      'formatted': 'Москва, Тестовая 1',
      'lat': 55.75,
      'lng': 37.61,
    },
    'status': status.name,
    'createdAt': timestamp,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ordersHistoryProvider', () {
    late MockApiService apiService;
    late ProviderContainer container;

    setUp(() {
      apiService = MockApiService();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
    });

    test('возвращает отсортированный список заказов', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => right([
          _orderPayload(
            id: 'order-1',
            createdAt: DateTime(2024, 5, 10, 10),
          ),
          _orderPayload(
            id: 'order-2',
            createdAt: DateTime(2024, 5, 11, 14),
          ),
        ]),
      );

      final result = await container.read(ordersHistoryProvider.future);

      expect(result, hasLength(2));
      expect(result.first.id, 'order-2');
      expect(result.last.id, 'order-1');
      verify(
        apiService.get<dynamic>(
          '/orders/history',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });

    test('добавляет поисковый параметр в запрос при вводе', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters]
            as Map<String, String>?;
        expect(params, equals(<String, String>{'search': 'rose'}));
        return right([
          _orderPayload(
            id: 'order-rose',
            status: OrderStatus.delivered,
          ),
        ]);
      });

      container.read(ordersHistorySearchQueryProvider.notifier).state = 'rose';
      final orders = await container.read(ordersHistoryProvider.future);

      expect(orders, hasLength(1));
      expect(orders.first.id, 'order-rose');
      verify(
        apiService.get<dynamic>(
          '/orders/history',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });

    test('пробрасывает ParsingFailure при неверном ответе', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => right(<String, dynamic>{'unexpected': true}),
      );

      expect(
        () => container.read(ordersHistoryProvider.future),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('orderReceiptProvider', () {
    late MockApiService apiService;
    late ProviderContainer container;

    setUp(() {
      apiService = MockApiService();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
    });

    test('возвращает ссылку на чек из ответа API', () async {
      when(
        apiService.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => right(<String, dynamic>{
          'receipt': <String, dynamic>{
            'url': 'https://example.com/receipt.pdf',
          },
        }),
      );

      final url =
          await container.read(orderReceiptProvider('order-1').future);

      expect(url, 'https://example.com/receipt.pdf');
      verify(
        apiService.get<dynamic>(
          '/orders/order-1/receipt',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });
  });
}
