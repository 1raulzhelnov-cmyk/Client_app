import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/models/customization_model.dart';
import 'package:eazy_client_mvp/models/customization_option.dart';

void main() {
  test('extraPrice складывает стоимость выбранных опций', () {
    const size = CustomizationOption(
      id: 'size-m',
      name: 'Средний',
      price: 100,
      group: 'size',
      isSelected: true,
    );
    const addOns = <CustomizationOption>[
      CustomizationOption(
        id: 'addon-1',
        name: 'Свечи',
        price: 50,
        isSelected: true,
      ),
      CustomizationOption(
        id: 'addon-2',
        name: 'Открытка',
        price: 25,
        isSelected: false,
      ),
    ];
    const modifications = <CustomizationOption>[
      CustomizationOption(
        id: 'mod-1',
        name: 'Без сахара',
        price: 30,
        isSelected: true,
      ),
    ];

    const selection = CustomizationSelection(
      size: size,
      addOns: addOns,
      modifications: modifications,
    );

    expect(selection.extraPrice, closeTo(180, 0.001));
  });

  test('fromOptions корректно раскладывает группы', () {
    const options = <CustomizationOption>[
      CustomizationOption(
        id: 'size-s',
        name: 'Small',
        group: 'Size',
      ),
      CustomizationOption(
        id: 'addon-balloons',
        name: 'Balloons',
        group: 'Add-On',
      ),
      CustomizationOption(
        id: 'mod-sugar',
        name: 'Без сахара',
        group: 'modifier',
      ),
      CustomizationOption(
        id: 'mystery',
        name: 'Сюрприз',
        group: '',
      ),
    ];

    final model = CustomizationModel.fromOptions(options);
    expect(model.sizes, hasLength(1));
    expect(model.addOns, hasLength(2));
    expect(model.modifications, hasLength(1));
    expect(model.hasOptions, isTrue);
  });

  test('hasSelections учитывает заметки и copyWith', () {
    const baseSelection = CustomizationSelection();
    expect(baseSelection.hasSelections, isFalse);

    final selection = baseSelection.copyWith(
      instructions: '   без лука  ',
      addOns: const [
        CustomizationOption(
          id: 'addon-1',
          name: 'Свечи',
          price: 50,
          isSelected: true,
        ),
      ],
    );

    expect(selection.hasSelections, isTrue);
    expect(selection.selectedOptions, hasLength(1));
    expect(selection.instructions, '   без лука  ');
  });
}
