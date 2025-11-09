import 'package:firebase_auth/firebase_auth.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable(explicitToJson: true)
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  factory UserModel.fromFirebase(User user) {
    final displayName = user.displayName?.trim();
    final email = user.email?.trim();
    final phone = user.phoneNumber?.trim();
    final fallbackName = email?.split('@').first;

    return UserModel(
      id: user.uid,
      name: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : fallbackName ??
              phone ??
              'User',
      email: email ?? '${user.uid}@placeholder.local',
      phone: phone,
      photoUrl: user.photoURL,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
