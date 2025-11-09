import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/orders/providers/order_status_notifier.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OrderModel buildOrder({
    required String id,
    required OrderStatus status,
  }) {
    return OrderModel(
      id: id,
      userId: 'user-2',
      items: [
        CartItemModel(
          id: 'item-1',
          product: const ProductModel(
            id: 'product-1',
            venueId: 'venue-1',
            name: 'Букет',
            description: 'Полевые цветы',
            price: 900,
            imageUrl: 'https://example.com/bouquet.jpg',
          ),
          quantity: 1,
        ),
      ],
      total: 900,
      address: const AddressModel(
        id: 'addr-1',
        formatted: 'Санкт-Петербург, Невский проспект, 10',
        lat: 59.93,
        lng: 30.33,
      ),
      status: status,
      createdAt: DateTime(2024, 6, 1, 10),
    );
  }

  group('orderStatusProvider stream', () {
    late ProviderContainer container;
    late MockFirestoreService firestoreService;
    late StreamController<OrderModel> controller;
    const orderId = 'order-stream-1';

    setUp(() {
      firestoreService = MockFirestoreService();
      controller = StreamController<OrderModel>.broadcast();

      when(firestoreService.getOrderStream(orderId)).thenAnswer(
        (_) => controller.stream,
      );

      container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
        ],
      );
    });

    tearDown(() async {
      await controller.close();
      container.dispose();
    });

    test('возвращает обновления статуса из FirestoreService', () async {
      final initialOrder = buildOrder(
        id: orderId,
        status: OrderStatus.confirmed,
      );
      final updatedOrder = initialOrder.copyWith(status: OrderStatus.transit);

      final stream = container.read(orderStatusProvider(orderId).stream);

      scheduleMicrotask(() {
        controller
          ..add(initialOrder)
          ..add(updatedOrder);
      });

      await expectLater(
        stream,
        emitsInOrder([initialOrder, updatedOrder]),
      );
    });

      test('поддерживает переход заказа в статус отмены', () async {
        final initialOrder = buildOrder(
          id: orderId,
          status: OrderStatus.confirmed,
        );
        final cancelledOrder =
            initialOrder.copyWith(status: OrderStatus.cancelled);

        final stream = container.read(orderStatusProvider(orderId).stream);

        scheduleMicrotask(() {
          controller
            ..add(initialOrder)
            ..add(cancelledOrder);
        });

        await expectLater(
          stream,
          emitsInOrder([initialOrder, cancelledOrder]),
        );
      });
  });
}
