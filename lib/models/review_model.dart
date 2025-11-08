import 'package:json_annotation/json_annotation.dart';

part 'review_model.g.dart';

@JsonSerializable()
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.venueId,
    required this.userId,
    required this.stars,
    this.text,
    this.photoUrls = const <String>[],
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String venueId;
  final String userId;
  final int stars;
  final String? text;
  final List<String> photoUrls;
  final DateTime createdAt;

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? venueId,
    String? userId,
    int? stars,
    String? text,
    List<String>? photoUrls,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      venueId: venueId ?? this.venueId,
      userId: userId ?? this.userId,
      stars: stars ?? this.stars,
      text: text ?? this.text,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewModelToJson(this);
}
