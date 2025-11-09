import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/features/cart/widgets/customization_modal.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/customization_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('выбор размера обновляет DropdownButtonFormField', (tester) async {
    await S.load(const Locale('ru'));

    const customization = CustomizationModel(
      sizes: [
        CustomizationOption(
          id: 'size-s',
          name: 'Малый',
          price: 0,
          group: 'size',
        ),
        CustomizationOption(
          id: 'size-l',
          name: 'Большой',
          price: 150,
          group: 'size',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: CustomizationModal(
            productName: 'Тестовый товар',
            customization: customization,
          ),
        ),
      ),
    );

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    expect(dropdownFinder, findsOneWidget);

    var dropdown =
        tester.widget<DropdownButtonFormField<String>>(dropdownFinder);
    expect(dropdown.value, isNull);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Большой +150 ₽').last);
    await tester.pumpAndSettle();

    dropdown = tester.widget<DropdownButtonFormField<String>>(dropdownFinder);
    expect(dropdown.value, equals('size-l'));
  });
}
