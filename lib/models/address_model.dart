import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';

@JsonSerializable()
class AddressModel {
  const AddressModel({
    required this.id,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.instructions,
    this.isDefault = false,
  });

  final String id;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? instructions;
  final bool isDefault;

  AddressModel copyWith({
    String? id,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? instructions,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      instructions: instructions ?? this.instructions,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);

  Map<String, dynamic> toJson() => _$AddressModelToJson(this);
}
