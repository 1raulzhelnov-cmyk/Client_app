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
}
