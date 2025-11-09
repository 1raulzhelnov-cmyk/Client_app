import 'package:json_annotation/json_annotation.dart';

import 'customization_option.dart';
import 'product_model.dart';

part 'cart_item_model.g.dart';

@JsonSerializable(explicitToJson: true)
class CartItemModel {
  const CartItemModel({
    required this.product,
    required this.quantity,
    this.id,
    this.selectedCustomizations = const <CustomizationOption>[],
    this.note,
  });

  final String? id;
  final ProductModel product;
  final int quantity;
  @JsonKey(
    name: 'selectedCustom',
    defaultValue: <CustomizationOption>[],
    fromJson: _readSelectedCustomizations,
  )
  final List<CustomizationOption> selectedCustomizations;
  final String? note;

  double get subtotal {
    final optionsTotal = selectedCustomizations.fold<double>(
      0,
      (prev, item) => prev + item.price,
    );
    return (product.price + optionsTotal) * quantity;
  }

  String get itemKey {
    final ids = selectedCustomizations.map((option) => option.id).toList()
      ..sort();
    if (ids.isEmpty) {
      return product.id;
    }
    return '${product.id}::${ids.join('|')}';
  }

  CartItemModel copyWith({
    String? id,
    ProductModel? product,
    int? quantity,
    List<CustomizationOption>? selectedCustomizations,
    String? note,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedCustomizations:
          selectedCustomizations ?? this.selectedCustomizations,
      note: note ?? this.note,
    );
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$CartItemModelToJson(this);

  Map<String, dynamic> toFirestoreJson() {
    final json = toJson();
    json['itemKey'] = itemKey;
    return json;
  }

  static List<CustomizationOption> _readSelectedCustomizations(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((raw) => CustomizationOption.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList();
    }
    return const <CustomizationOption>[];
  }
}
