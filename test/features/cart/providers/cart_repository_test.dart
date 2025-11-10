import 'dart:async';
import 'dart:convert';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/cart/providers/cart_notifier.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/services/firestore/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

CartItemModel _cartItem(String id, int quantity) {
  return CartItemModel(
    id: id,
    product: ProductModel(
      id: 'product-$id',
      venueId: 'venue-1',
      name: 'Товар $id',
      description: 'Описание',
      price: 300,
      imageUrl: 'https://example.com/$id.jpg',
    ),
    quantity: quantity,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartRepository', () {
    late MockFirestoreService firestore;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      firestore = MockFirestoreService();
      container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          sharedPrefsProvider.overrideWith((ref) async => prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('watchCart эмитит кеш и обновления Firestore', () async {
      final cached = [_cartItem('cached', 1)];
      await prefs.setString(
        'cart.cache.v1',
        jsonEncode(cached.map((item) => item.toJson()).toList()),
      );

      final updatesController = StreamController<List<CartItemModel>>();
      when(firestore.getCartStream()).thenAnswer((_) => updatesController.stream);

      final repository = container.read(cartRepositoryProvider);
      final stream = repository.watchCart();

      final emitted = <List<CartItemModel>>[];
      final subscription = stream.listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      updatesController.add([_cartItem('remote', 2)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await subscription.cancel();
      await updatesController.close();

      expect(emitted.first.first.id, 'cached');
      expect(emitted.last.first.id, 'remote');
    });

    test('addItem бросает Failure при некорректном количестве', () async {
      final repository = container.read(cartRepositoryProvider);

      expect(
        () => repository.addItem(
          product: ProductModel(
            id: 'p1',
            venueId: 'v1',
            name: 'Товар',
            description: 'desc',
            price: 100,
            imageUrl: '',
          ),
          quantity: 0,
        ),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.message,
            'message',
            contains('Количество'),
          ),
        ),
      );
      verifyNever(firestore.addToCart(any));
    });

    test('обновление и очистка корзины проксируются в Firestore', () async {
      final repository = container.read(cartRepositoryProvider);
      when(firestore.updateCartItem(
        cartItemId: anyNamed('cartItemId'),
        quantity: anyNamed('quantity'),
      )).thenAnswer((_) async {});
      when(firestore.clearCart()).thenAnswer((_) async {});

      await repository.updateQuantity(cartItemId: 'item-1', quantity: 3);
      await repository.clearCart();

      verify(
        firestore.updateCartItem(
          cartItemId: 'item-1',
          quantity: 3,
        ),
      ).called(1);
      verify(firestore.clearCart()).called(1);
    });
  });
}
