import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/features/cart/widgets/customization_modal.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/customization_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('модальное окно возвращает выбранные параметры', (tester) async {
    await S.load(const Locale('ru'));

    final customization = CustomizationModel(
      sizes: const [
        CustomizationOption(
          id: 'size-s',
          name: 'Малый',
          group: 'size',
        ),
        CustomizationOption(
          id: 'size-l',
          name: 'Большой',
          price: 150,
          group: 'size',
        ),
      ],
      addOns: const [
        CustomizationOption(
          id: 'addon-1',
          name: 'Свечи',
          price: 50,
          group: 'addon',
        ),
      ],
      modifications: const [
        CustomizationOption(
          id: 'mod-1',
          name: 'Без сахара',
          price: 20,
          group: 'modification',
        ),
      ],
    );

    CustomizationSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCustomizationModal(
                    context: context,
                    productName: 'Торт',
                    customization: customization,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Большой +150 ₽').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Свечи +50 ₽'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Без сахара +20 ₽'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Без орехов');
    await tester.pump();

    await tester.tap(find.text(S.current.addToCart));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final selection = result!;
    expect(selection.size?.id, equals('size-l'));
    expect(selection.addOns.map((option) => option.id).toList(),
        contains('addon-1'));
    expect(selection.modifications.map((option) => option.id).toList(),
        contains('mod-1'));
    expect(selection.instructions, equals('Без орехов'));
    expect(selection.selectedOptions.length, 3);
  });
}
