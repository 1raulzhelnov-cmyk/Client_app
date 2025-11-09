import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';

@JsonSerializable(includeIfNull: false)
class AddressModel {
  const AddressModel({
    this.id,
    required this.formatted,
    required this.lat,
    required this.lng,
    this.instructions,
    this.isDefault = false,
  });

  final String? id;
  @JsonKey(name: 'formatted')
  final String formatted;
  @JsonKey(name: 'lat')
  final double lat;
  @JsonKey(name: 'lng')
  final double lng;
  final String? instructions;
  @JsonKey(name: 'isDefault', defaultValue: false)
  final bool isDefault;

  static const Object _sentinel = Object();

  AddressModel copyWith({
    String? id,
    String? formatted,
    double? lat,
    double? lng,
    Object? instructions = _sentinel,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      formatted: formatted ?? this.formatted,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      instructions: instructions == _sentinel
          ? this.instructions
          : instructions as String?,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);

  Map<String, dynamic> toJson() => _$AddressModelToJson(this);
}
