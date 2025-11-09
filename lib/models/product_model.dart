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
  @JsonKey(readValue: _readDescription, defaultValue: '')
  final String description;
  @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson)
  final double price;
  @JsonKey(readValue: _readImageUrl, defaultValue: '')
  final String imageUrl;
  @JsonKey(fromJson: _boolFromJson, defaultValue: true)
  final bool available;
  @JsonKey(readValue: _readCategory)
  final String? category;
  @JsonKey(name: 'type', unknownEnumValue: ProductType.food)
  final ProductType type;
  @JsonKey(
    defaultValue: <CustomizationOption>[],
    fromJson: _customizationsFromJson,
  )
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

  static Object? _readDescription(Map<dynamic, dynamic> json, String key) {
    return json['description'] ??
        json['desc'] ??
        json['shortDescription'] ??
        json['details'] ??
        '';
  }

  static Object? _readImageUrl(Map<dynamic, dynamic> json, String key) {
    return json['imageUrl'] ??
        json['image'] ??
        json['image_url'] ??
        json['photo'] ??
        '';
  }

  static Object? _readCategory(Map<dynamic, dynamic> json, String key) {
    return json['category'] ??
        json['categoryName'] ??
        json['group'] ??
        json['section'];
  }

  static double _priceFromJson(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static double _priceToJson(double value) => value;

  static bool _boolFromJson(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return true;
  }

  static List<CustomizationOption> _customizationsFromJson(dynamic value) {
    if (value is List) {
      return value
          .map(
            (dynamic item) => CustomizationOption.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    if (value is Map) {
      // Иногда бэкенд возвращает словарь с группами.
      return value.values
          .whereType<List>()
          .expand((options) => options)
          .whereType<Map>()
          .map(
            (dynamic item) => CustomizationOption.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    return const <CustomizationOption>[];
  }
}
