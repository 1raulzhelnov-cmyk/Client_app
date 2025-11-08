import 'package:json_annotation/json_annotation.dart';

part 'customization_option.g.dart';

@JsonSerializable()
class CustomizationOption {
  const CustomizationOption({
    required this.id,
    required this.name,
    this.price = 0,
    this.isRequired = false,
    this.isSelected = false,
    this.group,
  });

  final String id;
  final String name;
  final double price;
  final bool isRequired;
  final bool isSelected;
  final String? group;

  CustomizationOption copyWith({
    String? id,
    String? name,
    double? price,
    bool? isRequired,
    bool? isSelected,
    String? group,
  }) {
    return CustomizationOption(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isRequired: isRequired ?? this.isRequired,
      isSelected: isSelected ?? this.isSelected,
      group: group ?? this.group,
    );
  }

  factory CustomizationOption.fromJson(Map<String, dynamic> json) =>
      _$CustomizationOptionFromJson(json);

  Map<String, dynamic> toJson() => _$CustomizationOptionToJson(this);
}
