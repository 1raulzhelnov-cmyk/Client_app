import 'package:json_annotation/json_annotation.dart';

import 'address_model.dart';
import 'product_model.dart';

part 'venue_model.g.dart';

enum VenueType { food, flower }

@JsonSerializable(explicitToJson: true)
class VenueModel {
  const VenueModel({
    required this.id,
    required this.name,
    required this.type,
    required this.rating,
    required this.cuisines,
    required this.averagePrice,
    required this.photos,
    required this.deliveryFee,
    required this.deliveryTimeMinutes,
    required this.address,
    this.description,
    this.isOpen = true,
    this.hours = const <String, String>{},
    this.contacts = const <String, String>{},
    this.menu = const <ProductModel>[],
    this.catalog = const <ProductModel>[],
  });

  final String id;
  final String name;
  @JsonKey(name: 'type', unknownEnumValue: VenueType.food)
  final VenueType type;
  @JsonKey(fromJson: _toDouble, toJson: _doubleToJson, defaultValue: 0.0)
  final double rating;
  @JsonKey(defaultValue: <String>[], fromJson: _stringListFromJson)
  final List<String> cuisines;
  @JsonKey(name: 'avgPrice', fromJson: _toDouble, toJson: _doubleToJson)
  final double averagePrice;
  @JsonKey(defaultValue: <String>[], fromJson: _stringListFromJson)
  final List<String> photos;
  @JsonKey(fromJson: _toDouble, toJson: _doubleToJson, defaultValue: 0.0)
  final double deliveryFee;
  @JsonKey(readValue: _readDeliveryTime, defaultValue: '')
  final String deliveryTimeMinutes;
  final AddressModel address;
  final String? description;
  @JsonKey(defaultValue: true)
  final bool isOpen;
  @JsonKey(defaultValue: <String, String>{}, fromJson: _stringMapFromJson)
  final Map<String, String> hours;
  @JsonKey(defaultValue: <String, String>{}, fromJson: _stringMapFromJson)
  final Map<String, String> contacts;
  @JsonKey(defaultValue: <ProductModel>[], fromJson: _productListFromJson)
  final List<ProductModel> menu;
  @JsonKey(defaultValue: <ProductModel>[], fromJson: _productListFromJson)
  final List<ProductModel> catalog;

  VenueModel copyWith({
    String? id,
    String? name,
    VenueType? type,
    double? rating,
    List<String>? cuisines,
    double? averagePrice,
    List<String>? photos,
    double? deliveryFee,
    String? deliveryTimeMinutes,
    AddressModel? address,
    String? description,
    bool? isOpen,
    Map<String, String>? hours,
    Map<String, String>? contacts,
    List<ProductModel>? menu,
    List<ProductModel>? catalog,
  }) {
    return VenueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      cuisines: cuisines ?? this.cuisines,
      averagePrice: averagePrice ?? this.averagePrice,
      photos: photos ?? this.photos,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryTimeMinutes: deliveryTimeMinutes ?? this.deliveryTimeMinutes,
      address: address ?? this.address,
      description: description ?? this.description,
      isOpen: isOpen ?? this.isOpen,
      hours: hours ?? this.hours,
      contacts: contacts ?? this.contacts,
      menu: menu ?? this.menu,
      catalog: catalog ?? this.catalog,
    );
  }

  factory VenueModel.fromJson(Map<String, dynamic> json) =>
      _$VenueModelFromJson(json);

  Map<String, dynamic> toJson() => _$VenueModelToJson(this);

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double _doubleToJson(double value) => value;

  static List<String> _stringListFromJson(dynamic value) {
    if (value is List) {
      return value.map((dynamic item) => item.toString()).toList();
    }
    return const <String>[];
  }

  static Map<String, String> _stringMapFromJson(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, dynamic val) => MapEntry(key.toString(), val.toString()),
      );
    }
    return const <String, String>{};
  }

  static Object? _readDeliveryTime(Map<dynamic, dynamic> json, String key) {
    return json['deliveryTimeMinutes'] ??
        json['deliveryTime'] ??
        json['delivery_time'] ??
        '';
  }

  static List<ProductModel> _productListFromJson(dynamic value) {
    if (value is List) {
      return value
          .map(
            (dynamic item) => ProductModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    return const <ProductModel>[];
  }
}
