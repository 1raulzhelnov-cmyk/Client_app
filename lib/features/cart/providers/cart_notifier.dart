import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/customization_option.dart';
import '../../../models/product_model.dart';
import '../../../services/firestore/firestore_service.dart';

const _cartCacheKey = 'cart.cache.v1';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref);
});

final cartNotifierProvider =
    AutoDisposeStreamProvider<List<CartItemModel>>((ref) {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.watchCart();
});

final cartUpdateNotifier =
    NotifierProvider<CartUpdateNotifier, void>(CartUpdateNotifier.new);

class CartRepository {
  CartRepository(this._ref);

  final Ref _ref;

  FirestoreService get _firestore => _ref.read(firestoreServiceProvider);

  Future<SharedPreferences> get _prefs =>
      _ref.read(sharedPrefsProvider.future);

  Future<void> cacheCart(List<CartItemModel> items) async {
    final prefs = await _prefs;
    final serialized = items.map((item) => item.toJson()).toList();
    await prefs.setString(_cartCacheKey, jsonEncode(serialized));
  }

  Future<List<CartItemModel>> readCachedCart() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_cartCacheKey);
      if (raw == null || raw.isEmpty) {
        return const <CartItemModel>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CartItemModel>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (dynamic item) => CartItemModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const <CartItemModel>[];
    }
  }

  Stream<List<CartItemModel>> watchCart() {
    final controller = StreamController<List<CartItemModel>>.broadcast();
    StreamSubscription<List<CartItemModel>>? remoteSubscription;

    Future<void>(() async {
      final cached = await readCachedCart();
      if (cached.isNotEmpty && !controller.isClosed) {
        controller.add(cached);
      }

      try {
        remoteSubscription = _firestore.getCartStream().listen(
          (items) async {
            await cacheCart(items);
            if (!controller.isClosed) {
              controller.add(items);
            }
          },
          onError: (Object error, StackTrace stackTrace) async {
            final cachedFallback = await readCachedCart();
            if (cachedFallback.isNotEmpty && !controller.isClosed) {
              controller.add(cachedFallback);
            }
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      } on Failure catch (error, stackTrace) {
        final cachedFallback = await readCachedCart();
        if (cachedFallback.isNotEmpty && !controller.isClosed) {
          controller.add(cachedFallback);
        }
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    });

    _ref.onDispose(() async {
      await remoteSubscription?.cancel();
      await controller.close();
    });

    return controller.stream;
  }

    Future<void> addItem({
      required ProductModel product,
      required int quantity,
      List<CustomizationOption> selectedCustomizations =
          const <CustomizationOption>[],
      String? note,
    }) async {
      if (quantity <= 0) {
        throw const Failure(message: 'Количество должно быть больше нуля.');
      }
      final item = CartItemModel(
        product: product,
        quantity: quantity,
        selectedCustomizations: selectedCustomizations,
        note: note,
      );
      await _firestore.addToCart(item);
    }

  Future<void> removeItem(String cartItemId) async {
    await _firestore.removeFromCart(cartItemId);
  }

  Future<void> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    await _firestore.updateCartItem(
      cartItemId: cartItemId,
      quantity: quantity,
    );
  }

  Future<void> clearCart() async {
    await _firestore.clearCart();
  }
}

class CartUpdateNotifier extends Notifier<void> {
  late final CartRepository _repository;

  @override
  void build() {
    _repository = ref.read(cartRepositoryProvider);
  }

  Future<void> addItem(
    ProductModel product,
    int quantity,
    List<CustomizationOption> selectedCustomizations, {
    String? note,
  }) async {
    await _repository.addItem(
      product: product,
      quantity: quantity,
      selectedCustomizations: selectedCustomizations,
      note: note,
    );
  }

  Future<void> updateQty(String cartItemId, int quantity) async {
    await _repository.updateQuantity(
      cartItemId: cartItemId,
      quantity: quantity,
    );
  }

  Future<void> removeItem(String cartItemId) async {
    await _repository.removeItem(cartItemId);
  }

  Future<void> clearCart() async {
    await _repository.clearCart();
  }
}
