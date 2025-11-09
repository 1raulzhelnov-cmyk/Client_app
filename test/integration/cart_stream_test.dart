import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/cart/providers/cart_notifier.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cart stream', () {
    late ProviderContainer container;
    late MockFirestoreService firestoreService;
    late SharedPreferences prefs;
    late StreamController<List<CartItemModel>> controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      firestoreService = MockFirestoreService();
      controller = StreamController<List<CartItemModel>>.broadcast();

      when(firestoreService.getCartStream()).thenAnswer(
        (_) => controller.stream,
      );

      container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          sharedPrefsProvider.overrideWith(
            (ref) => Future.value(prefs),
          ),
        ],
      );
    });

    tearDown(() async {
      await controller.close();
      container.dispose();
    });

    test('передаёт обновления из FirestoreService', () async {
      const product = ProductModel(
        id: 'prod-1',
        venueId: 'venue-1',
        name: 'Пицца',
        description: 'Сырная',
        price: 600,
        imageUrl: 'https://example.com/pizza.jpg',
      );
      const addon = CustomizationOption(
        id: 'option-1',
        name: 'Доп сыр',
        price: 80,
      );

      final initialItem = CartItemModel(
        id: 'cart-1',
        product: product,
        quantity: 1,
        selectedCustomizations: const <CustomizationOption>[addon],
      );
      final updatedItem = initialItem.copyWith(quantity: 3);

      final stream = container.read(cartNotifierProvider.stream);

      scheduleMicrotask(() {
        controller.add(<CartItemModel>[initialItem]);
        controller.add(<CartItemModel>[updatedItem]);
      });

      await expectLater(
        stream,
        emitsInOrder([
          <CartItemModel>[initialItem],
          <CartItemModel>[updatedItem],
        ]),
      );
    });
  });
}
