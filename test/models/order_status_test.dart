import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';

void main() {
  OrderModel buildOrder(OrderStatus status) {
    return OrderModel(
      id: 'order-1',
      userId: 'user-1',
      items: [
        CartItemModel(
          id: 'item-1',
          product: const ProductModel(
            id: 'product-1',
            venueId: 'venue-1',
            name: 'Пицца',
            description: 'Сырная',
            price: 600,
            imageUrl: 'https://example.com/pizza.jpg',
          ),
          quantity: 1,
        ),
      ],
      total: 600,
      address: const AddressModel(
        id: 'address-1',
        formatted: 'Москва, Арбат, 1',
        lat: 55.7558,
        lng: 37.6173,
      ),
      status: status,
      createdAt: DateTime(2024, 1, 1, 12),
    );
  }

  test('OrderStatus содержит этапы в ожидаемом порядке', () {
    expect(
      OrderStatus.values,
      equals(
        <OrderStatus>[
          OrderStatus.placed,
          OrderStatus.confirmed,
          OrderStatus.preparing,
          OrderStatus.transit,
          OrderStatus.delivered,
          OrderStatus.cancelled,
        ],
      ),
    );
  });

  test('statusProgress соответствует индексу статуса', () {
    const activeStatuses = <OrderStatus>[
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.transit,
      OrderStatus.delivered,
    ];

    for (var i = 0; i < activeStatuses.length; i++) {
      final status = activeStatuses[i];
      final order = buildOrder(status);
      final expectedProgress = (i + 1) / activeStatuses.length;
      expect(order.statusProgress, closeTo(expectedProgress, 1e-9));
    }

    final cancelledOrder = buildOrder(OrderStatus.cancelled);
    expect(cancelledOrder.statusProgress, 0);
  });
}
