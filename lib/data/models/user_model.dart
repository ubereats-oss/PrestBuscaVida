import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? phone;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final String? gleba;

  const UserModel({
    required this.uid,
    this.email,
    this.phone,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.gleba,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(
    Map<String, dynamic> map, {
    required String uid,
  }) {
    return UserModel(
      uid: uid,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      displayName: (map['displayName'] ?? '').toString(),
      role: (map['role'] ?? 'user').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gleba: map['gleba'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'gleba': gleba,
    };
  }
}
