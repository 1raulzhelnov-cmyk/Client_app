import 'package:json_annotation/json_annotation.dart';

import 'address_model.dart';
import 'cart_item_model.dart';

part 'order_model.g.dart';

enum OrderStatus {
  placed,
  confirmed,
  preparing,
  transit,
  delivered,
  cancelled,
}

@JsonSerializable(explicitToJson: true)
class OrderModel {
  const OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.address,
    required this.status,
    required this.createdAt,
    this.eta,
    this.updatedAt,
    this.paymentMethod = 'card',
    this.paymentIntentId,
    this.cashInstructions,
    this.deliveryFee = 0,
    this.cashFee = 0,
    this.notes,
  });

  final String id;
  final String userId;
  final List<CartItemModel> items;
  final double total;
  final AddressModel address;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? eta;
  final DateTime? updatedAt;
  final String paymentMethod;
  final String? paymentIntentId;
  final String? cashInstructions;
  final double deliveryFee;
  final double cashFee;
  final String? notes;

  double get grandTotal => total + deliveryFee + cashFee;

  OrderModel copyWith({
    String? id,
    String? userId,
    List<CartItemModel>? items,
    double? total,
    AddressModel? address,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? eta,
    DateTime? updatedAt,
    String? paymentMethod,
    String? paymentIntentId,
    String? cashInstructions,
    double? deliveryFee,
    double? cashFee,
    String? notes,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      total: total ?? this.total,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      eta: eta ?? this.eta,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      cashInstructions: cashInstructions ?? this.cashInstructions,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      cashFee: cashFee ?? this.cashFee,
      notes: notes ?? this.notes,
    );
  }

  factory OrderModel.empty({
    required List<CartItemModel> fromCart,
    required String userId,
  }) {
    final total = fromCart.fold<double>(
      0,
      (prev, item) => prev + item.subtotal,
    );
    return OrderModel(
      id: '',
      userId: userId,
      items: fromCart,
      total: total,
      address: const AddressModel(
        id: '',
        formattedAddress: '',
        latitude: 0,
        longitude: 0,
      ),
      status: OrderStatus.placed,
      createdAt: DateTime.now(),
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);
}
