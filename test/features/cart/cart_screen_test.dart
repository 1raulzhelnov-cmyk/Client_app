import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:eazy_client_mvp/features/cart/providers/cart_notifier.dart';
import 'package:eazy_client_mvp/features/cart/screens/cart_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';
import 'package:eazy_client_mvp/models/product_model.dart';

class _FakeCartUpdateNotifier extends CartUpdateNotifier {
  @override
  void build() {}

  @override
  Future<void> addItem(
    ProductModel product,
    int quantity,
    List<CustomizationOption> selectedCustomizations, {
    String? note,
  }) async {}

  @override
  Future<void> updateQty(String cartItemId, int quantity) async {}

  @override
  Future<void> removeItem(String cartItemId) async {}

  @override
  Future<void> clearCart() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CartScreen показывает пустое состояние', (tester) async {
    await S.load(const Locale('ru'));

    final emptyStream = Stream<List<CartItemModel>>.value(const <CartItemModel>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartNotifierProvider.overrideWith((ref) => emptyStream),
          cartUpdateNotifier.overrideWith(_FakeCartUpdateNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const CartScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(S.current.emptyCart), findsOneWidget);
    expect(find.text(S.current.home), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
