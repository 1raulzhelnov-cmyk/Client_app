import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';
import 'package:eazy_client_mvp/models/product_model.dart';

void main() {
  group('CartItemModel', () {
    const product = ProductModel(
      id: 'product-1',
      venueId: 'venue-1',
      name: 'Тестовый товар',
      description: 'Описание товара',
      price: 500,
      imageUrl: 'https://example.com/image.jpg',
    );

    const addons = <CustomizationOption>[
      CustomizationOption(id: 'add-1', name: 'Свечи', price: 50),
      CustomizationOption(id: 'add-2', name: 'Открытка', price: 25),
    ];

    test('корректно считает итоговую стоимость с учётом кастомизаций', () {
      const item = CartItemModel(
        id: 'cart-1',
        product: product,
        quantity: 2,
        selectedCustomizations: addons,
      );

      expect(item.subtotal, closeTo(1150, 0.001));
    });

    test('формирует стабильный ключ itemKey для синхронизации', () {
      const item = CartItemModel(
        product: product,
        quantity: 1,
        selectedCustomizations: addons,
      );

      expect(item.itemKey, 'product-1::add-1|add-2');
    });

    test('подготавливает данные для Firestore с itemKey и кастомизациями', () {
      const item = CartItemModel(
        product: product,
        quantity: 1,
        selectedCustomizations: addons,
      );

      final json = item.toFirestoreJson();

      expect(json['itemKey'], equals(item.itemKey));
      expect(json['selectedCustom'], isA<List>());
      expect((json['selectedCustom'] as List).length, equals(2));
    });
  });
}
