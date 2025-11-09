import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/orders/screens/orders_history_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

Map<String, dynamic> _orderPayload(String id, String status) {
  return <String, dynamic>{
    'id': id,
    'userId': 'user-1',
    'items': const <Map<String, dynamic>>[],
    'total': 1000,
    'deliveryFee': 0,
    'cashFee': 0,
    'address': const <String, dynamic>{
      'id': 'addr-1',
      'formatted': 'Москва, Тестовая 1',
      'lat': 55.75,
      'lng': 37.61,
    },
    'status': status,
    'createdAt': DateTime(2024, 5, 10, 12).toIso8601String(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('поиск в истории заказов отправляет параметр search',
      (tester) async {
    final apiService = MockApiService();

    when(
      apiService.get<dynamic>(
        any,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final params =
          invocation.namedArguments[#queryParameters] as Map<String, String>?;
      if (params == null) {
        return right([
          _orderPayload('order-1', 'placed'),
          _orderPayload('order-2', 'delivered'),
        ]);
      }
      expect(params['search'], equals('rose'));
      return right([
        _orderPayload('order-rose', 'delivered'),
      ]);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const OrdersHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('#order-1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rose');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('#order-rose'), findsOneWidget);
    verify(
      apiService.get<dynamic>(
        '/orders/history',
        queryParameters: anyNamed('queryParameters'),
      ),
    ).called(greaterThanOrEqualTo(2));
  });
}
