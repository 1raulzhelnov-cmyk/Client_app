import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/orders/providers/order_status_notifier.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late ProviderContainer container;
  late MockApiService apiService;

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

  test('cancelOrder отправляет запрос и возвращает null при успехе', () async {
    when(
      apiService.post<dynamic>(
        any,
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => right(null));

    final notifier = container.read(orderStatusNotifier);
    final failure = await notifier.cancelOrder('order-55', 'Changed mind');

    expect(failure, isNull);
    verify(
      apiService.post<dynamic>(
        '/orders/order-55/cancel',
        body: {'reason': 'Changed mind'},
      ),
    ).called(1);
  });

  test('cancelOrder возвращает Failure при ошибке API', () async {
    const failureResponse = Failure(message: 'Ошибка отмены');

    when(
      apiService.post<dynamic>(
        any,
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => left(failureResponse));

    final notifier = container.read(orderStatusNotifier);
    final failure = await notifier.cancelOrder('order-55', 'Wrong address');

    expect(failure, equals(failureResponse));
  });

  test('cancelOrder не вызывает API для пустого идентификатора', () async {
    final notifier = container.read(orderStatusNotifier);
    final failure = await notifier.cancelOrder('   ', 'Changed mind');

    expect(failure, isA<Failure>());
    verifyNever(
      apiService.post<dynamic>(
        any,
        body: anyNamed('body'),
      ),
    );
  });
}
