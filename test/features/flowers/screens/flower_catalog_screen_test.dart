import 'package:eazy_client_mvp/features/flowers/providers/flower_notifier.dart';
import 'package:eazy_client_mvp/features/flowers/screens/flower_catalog_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/flower_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlowerCatalogScreen', () {
    late FlowerModel birthdayBouquet;
    late FlowerModel weddingBouquet;

    setUp(() {
      birthdayBouquet = FlowerModel(
        id: 'birthday-1',
        venueId: 'venue-1',
        name: 'Весенний букет',
        description: 'Тюльпаны и ранункулюсы',
        price: 2490,
        imageUrl: '',
        occasion: 'birthday',
        season: 'spring',
        careInstructions: 'Менять воду ежедневно.',
      );

      weddingBouquet = FlowerModel(
        id: 'wedding-1',
        venueId: 'venue-2',
        name: 'Свадебная композиция',
        description: 'Пионы и розы в пастельных тонах',
        price: 4890,
        imageUrl: '',
        occasion: 'wedding',
        season: 'summer',
        careInstructions: 'Спрей с водой каждые 4 часа.',
      );
    });

    testWidgets('switches tabs and shows bouquets for selected occasion',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flowerProvider.overrideWithProvider(
              (query) => AutoDisposeFutureProvider<List<FlowerModel>>(
                (ref) async {
                  if (query.occasion == 'birthday') {
                    return [birthdayBouquet];
                  }
                  if (query.occasion == 'wedding') {
                    return [weddingBouquet];
                  }
                  return const <FlowerModel>[];
                },
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
            home: const Scaffold(
              body: FlowerCatalogScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Весенний букет'), findsOneWidget);
      expect(find.text('Свадебная композиция'), findsNothing);

      await tester.tap(find.text('Свадьба'));
      await tester.pumpAndSettle();

      expect(find.text('Весенний букет'), findsNothing);
      expect(find.text('Свадебная композиция'), findsOneWidget);
    });
  });
}
