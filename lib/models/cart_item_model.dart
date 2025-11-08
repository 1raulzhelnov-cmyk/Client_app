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
    this.selectedOptions = const <CustomizationOption>[],
    this.note,
  });

  final String? id;
  final ProductModel product;
  final int quantity;
  final List<CustomizationOption> selectedOptions;
  final String? note;

  double get subtotal {
    final optionsTotal = selectedOptions.fold<double>(
      0,
      (prev, item) => prev + item.price,
    );
    return (product.price + optionsTotal) * quantity;
  }

  CartItemModel copyWith({
    String? id,
    ProductModel? product,
    int? quantity,
    List<CustomizationOption>? selectedOptions,
    String? note,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      note: note ?? this.note,
    );
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$CartItemModelToJson(this);
}
