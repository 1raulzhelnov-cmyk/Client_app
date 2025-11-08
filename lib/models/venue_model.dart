import 'package:json_annotation/json_annotation.dart';

import 'address_model.dart';

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
    this.hours = const {},
  });

  final String id;
  final String name;
  final VenueType type;
  final double rating;
  final List<String> cuisines;
  final double averagePrice;
  final List<String> photos;
  final double deliveryFee;
  final String deliveryTimeMinutes;
  final AddressModel address;
  final String? description;
  final bool isOpen;
  final Map<String, String> hours;

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
    );
  }

  factory VenueModel.fromJson(Map<String, dynamic> json) =>
      _$VenueModelFromJson(json);

  Map<String, dynamic> toJson() => _$VenueModelToJson(this);
}
