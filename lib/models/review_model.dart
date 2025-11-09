import 'package:json_annotation/json_annotation.dart';

part 'review_model.g.dart';

@JsonSerializable()
class ReviewModel {
  const ReviewModel({
    this.id,
    required this.orderId,
    this.venueId,
    this.userId,
    required this.stars,
    this.text,
    this.photoUrls = const <String>[],
    this.createdAt,
    this.userName,
    this.userAvatarUrl,
  });

  @JsonKey(includeIfNull: false)
  final String? id;
  final String orderId;
  @JsonKey(includeIfNull: false)
  final String? venueId;
  @JsonKey(includeIfNull: false)
  final String? userId;
  final int stars;
  @JsonKey(includeIfNull: false)
  final String? text;
  @JsonKey(defaultValue: <String>[])
  final List<String> photoUrls;
  @JsonKey(
    includeIfNull: false,
    fromJson: _dateTimeFromJson,
    toJson: _dateTimeToJson,
  )
  final DateTime? createdAt;
  @JsonKey(includeIfNull: false)
  final String? userName;
  @JsonKey(includeIfNull: false)
  final String? userAvatarUrl;

  bool get hasText => (text ?? '').trim().isNotEmpty;
  bool get hasPhotos => photoUrls.isNotEmpty;

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? venueId,
    String? userId,
    int? stars,
    String? text,
    List<String>? photoUrls,
    DateTime? createdAt,
    String? userName,
    String? userAvatarUrl,
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
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
    );
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewModelToJson(this);

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      // Assume timestamp in milliseconds.
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static dynamic _dateTimeToJson(DateTime? dateTime) {
    return dateTime?.toIso8601String();
  }
}
