import 'package:eazy_client_mvp/features/orders/providers/orders_notifier.dart';
import 'package:eazy_client_mvp/features/orders/screens/orders_history_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

OrderModel _buildOrder({
  required String id,
  OrderStatus status = OrderStatus.placed,
  DateTime? createdAt,
  double total = 1500,
}) {
  final created = createdAt ?? DateTime(2024, 5, 10, 12);
  return OrderModel(
    id: id,
    userId: 'user-1',
    items: [
      CartItemModel(
        id: 'item-1',
        product: const ProductModel(
          id: 'product-1',
          venueId: 'venue-1',
          name: 'Букет',
          description: 'Описание',
          price: 1500,
          imageUrl: '',
        ),
        quantity: 1,
      ),
    ],
    total: total,
    address: const AddressModel(
      id: 'addr-1',
      formatted: 'Москва, Тестовая 1',
      lat: 55.75,
      lng: 37.61,
    ),
    status: status,
    createdAt: created,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OrdersHistoryScreen отображает заказы и скачивание чека',
      (tester) async {
    final orders = [
      _buildOrder(
        id: 'order-77',
        status: OrderStatus.delivered,
        createdAt: DateTime(2024, 5, 12, 18, 30),
        total: 2100,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersHistoryProvider.overrideWith(
            (ref) async => orders,
          ),
          orderReceiptProvider.overrideWithProvider(
            (orderId) => AutoDisposeFutureProvider<String>(
              (ref) async => 'https://example.com/$orderId.pdf',
            ),
          ),
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

    expect(find.textContaining('#order-77'), findsOneWidget);
    expect(find.textContaining('Скачать чек'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.textContaining('https://example.com/order-77.pdf'),
      findsOneWidget,
    );
  });
}
