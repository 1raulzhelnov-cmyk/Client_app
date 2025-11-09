import 'package:eazy_client_mvp/features/venue/providers/product_notifier.dart';
import 'package:eazy_client_mvp/features/venue/widgets/menu_catalog.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('раскрывает категории и вызывает onAddToCart', (tester) async {
    final products = [
      _product(
        id: 'pizza-1',
        name: 'Маргарита',
        category: 'Пицца',
      ),
      _product(
        id: 'soup-1',
        name: 'Том Ям',
        category: 'Супы',
      ),
    ];

    final addedProducts = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productProvider.overrideWithProvider(
            (venueId) => AutoDisposeFutureProvider<List<ProductModel>>(
              (ref) async => products,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: MenuCatalog(
              venueId: 'venue-1',
              isMenu: true,
              onAddToCart: (product) => addedProducts.add(product.id),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('Пицца'), findsOneWidget);

    await tester.tap(find.text('Пицца').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined).first);
    await tester.pump();

    expect(addedProducts, equals(['pizza-1']));
  });
}

ProductModel _product({
  required String id,
  required String name,
  required String category,
}) {
  return ProductModel(
    id: id,
    venueId: 'venue-1',
    name: name,
    description: '$name описание',
    price: 450,
    imageUrl: '',
    available: true,
    category: category,
  );
}
