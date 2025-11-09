import 'customization_option.dart';

enum CustomizationCategory { size, addOn, modification, unknown }

CustomizationCategory _mapGroup(String? rawGroup) {
  if (rawGroup == null || rawGroup.isEmpty) {
    return CustomizationCategory.unknown;
  }
  final normalized = rawGroup.toLowerCase().trim();
  if (normalized.contains('size') || normalized.contains('размер')) {
    return CustomizationCategory.size;
  }
  if (normalized.contains('addon') ||
      normalized.contains('add-on') ||
      normalized.contains('add_on') ||
      normalized.contains('extra') ||
      normalized.contains('доп') ||
      normalized.contains('добав')) {
    return CustomizationCategory.addOn;
  }
  if (normalized.contains('mod') ||
      normalized.contains('change') ||
      normalized.contains('modifier') ||
      normalized.contains('опция') ||
      normalized.contains('измен')) {
    return CustomizationCategory.modification;
  }
  return CustomizationCategory.unknown;
}

class CustomizationModel {
  const CustomizationModel({
    this.sizes = const <CustomizationOption>[],
    this.addOns = const <CustomizationOption>[],
    this.modifications = const <CustomizationOption>[],
  });

  final List<CustomizationOption> sizes;
  final List<CustomizationOption> addOns;
  final List<CustomizationOption> modifications;

  bool get hasOptions =>
      sizes.isNotEmpty || addOns.isNotEmpty || modifications.isNotEmpty;

  factory CustomizationModel.fromOptions(List<CustomizationOption> options) {
    if (options.isEmpty) {
      return const CustomizationModel();
    }
    final sizes = <CustomizationOption>[];
    final addOns = <CustomizationOption>[];
    final modifications = <CustomizationOption>[];
    for (final option in options) {
      switch (_mapGroup(option.group)) {
        case CustomizationCategory.size:
          sizes.add(option);
          break;
        case CustomizationCategory.addOn:
          addOns.add(option);
          break;
        case CustomizationCategory.modification:
          modifications.add(option);
          break;
        case CustomizationCategory.unknown:
          addOns.add(option);
          break;
      }
    }
    return CustomizationModel(
      sizes: sizes,
      addOns: addOns,
      modifications: modifications,
    );
  }

  List<CustomizationOption> mergeSelections(
    CustomizationOption? size,
    Iterable<CustomizationOption> addOnSelections,
    Iterable<CustomizationOption> modificationSelections,
  ) {
    final result = <CustomizationOption>[];
    if (size != null) {
      result.add(size);
    }
    result
      ..addAll(addOnSelections.where((option) => option.isSelected))
      ..addAll(modificationSelections.where((option) => option.isSelected));
    return result;
  }
}

class CustomizationSelection {
  const CustomizationSelection({
    this.size,
    this.addOns = const <CustomizationOption>[],
    this.modifications = const <CustomizationOption>[],
    this.instructions,
  });

  final CustomizationOption? size;
  final List<CustomizationOption> addOns;
  final List<CustomizationOption> modifications;
  final String? instructions;

  List<CustomizationOption> get selectedOptions {
    return <CustomizationOption>[
      if (size != null) size!,
      ...addOns.where((option) => option.isSelected),
      ...modifications.where((option) => option.isSelected),
    ];
  }

  double get extraPrice => selectedOptions.fold<double>(
        0,
        (previousValue, element) => previousValue + element.price,
      );

  bool get hasSelections =>
      size != null ||
      addOns.any((option) => option.isSelected) ||
      modifications.any((option) => option.isSelected) ||
      (instructions != null && instructions!.trim().isNotEmpty);

  CustomizationSelection copyWith({
    CustomizationOption? size,
    List<CustomizationOption>? addOns,
    List<CustomizationOption>? modifications,
    String? instructions,
  }) {
    return CustomizationSelection(
      size: size ?? this.size,
      addOns: addOns ?? this.addOns,
      modifications: modifications ?? this.modifications,
      instructions: instructions ?? this.instructions,
    );
  }
}
