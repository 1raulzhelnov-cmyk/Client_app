import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/orders/screens/order_status_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OrderModel buildOrder(OrderStatus status) {
    return OrderModel(
      id: 'order-42',
      userId: 'user-1',
      items: [
        CartItemModel(
          id: 'item-1',
          product: const ProductModel(
            id: 'product-1',
            venueId: 'venue-1',
            name: 'Лотос',
            description: 'Цветок',
            price: 1200,
            imageUrl: 'https://example.com/lotus.jpg',
          ),
          quantity: 2,
        ),
      ],
      total: 2400,
      address: const AddressModel(
        id: 'addr-1',
        formatted: 'Москва, Тверская 1',
        lat: 55.75,
        lng: 37.61,
      ),
      status: status,
      createdAt: DateTime(2024, 5, 10, 12),
      eta: DateTime(2024, 5, 10, 13, 30),
    );
  }

  testWidgets('показывает прогресс в соответствии со статусом заказа',
      (tester) async {
    final order = buildOrder(OrderStatus.preparing);
    final mockService = MockFirestoreService();

    when(mockService.getOrderStream(order.id)).thenAnswer(
      (_) => Stream.value(order),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(mockService),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: OrderStatusScreen(orderId: order.id),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final indicatorFinder = find.byType(LinearProgressIndicator).first;
    final indicator =
        tester.widget<LinearProgressIndicator>(indicatorFinder);
    final expectedProgress =
        (OrderStatus.preparing.index + 1) / OrderStatus.values.length;

    expect(indicator.value, closeTo(expectedProgress, 1e-9));
    expect(find.textContaining('#${order.id}'), findsOneWidget);
  });
}
