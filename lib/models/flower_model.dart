import 'package:json_annotation/json_annotation.dart';

import 'customization_option.dart';
import 'product_model.dart';

part 'flower_model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class FlowerModel extends ProductModel {
  const FlowerModel({
    required super.id,
    required super.venueId,
    required super.name,
    required super.description,
    required super.price,
    required super.imageUrl,
    super.available,
    super.category,
    super.customizations = const [],
    @JsonKey(readValue: _readOccasion)
    this.occasion,
    @JsonKey(readValue: _readSeason)
    this.season,
    @JsonKey(readValue: _readCareInstructions)
    this.careInstructions,
  }) : super(type: ProductType.flower);

  final String? occasion;
  final String? season;
  final String? careInstructions;

  @override
  FlowerModel copyWith({
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
    String? occasion,
    String? season,
    String? careInstructions,
  }) {
    return FlowerModel(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      available: available ?? this.available,
      category: category ?? this.category,
      customizations: customizations ?? this.customizations,
      occasion: occasion ?? this.occasion,
      season: season ?? this.season,
      careInstructions: careInstructions ?? this.careInstructions,
    );
  }

  factory FlowerModel.fromJson(Map<String, dynamic> json) =>
      _$FlowerModelFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$FlowerModelToJson(this);

  static Object? _readOccasion(Map<dynamic, dynamic> json, String key) {
    return json['occasion'] ??
        json['occasionType'] ??
        json['occasion_name'] ??
        json['event'] ??
        json['category'];
  }

  static Object? _readSeason(Map<dynamic, dynamic> json, String key) {
    return json['season'] ??
        json['seasonName'] ??
        json['seasonal'] ??
        json['collection'];
  }

  static Object? _readCareInstructions(Map<dynamic, dynamic> json, String key) {
    return json['careInstructions'] ??
        json['care'] ??
        json['care_notes'] ??
        json['instructions'];
  }
}
