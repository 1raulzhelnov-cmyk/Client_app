import 'package:json_annotation/json_annotation.dart';

import 'customization_option.dart';

part 'product_model.g.dart';

enum ProductType { food, flower }

@JsonSerializable(explicitToJson: true)
class ProductModel {
  const ProductModel({
    required this.id,
    required this.venueId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.available = true,
    this.category,
    this.type = ProductType.food,
    this.customizations = const <CustomizationOption>[],
  });

  final String id;
  final String venueId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool available;
  final String? category;
  final ProductType type;
  final List<CustomizationOption> customizations;

  ProductModel copyWith({
    String? id,
    String? venueId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? available,
    String? category,
    ProductType? type,
    List<CustomizationOption>? customizations,
  }) {
    return ProductModel(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      available: available ?? this.available,
      category: category ?? this.category,
      type: type ?? this.type,
      customizations: customizations ?? this.customizations,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProductModelToJson(this);
}
