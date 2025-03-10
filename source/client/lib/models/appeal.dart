import 'package:housing_inspection_client/models/user.dart';

class Appeal {
  final int id;
  final int userId;
  final int categoryId;
  final int statusId;
  final String address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? filePaths;
  final User? user;

  Appeal({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.statusId,
    required this.address,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.filePaths,
    this.user,
  });

  factory Appeal.fromJson(Map<String, dynamic> json) {
    return Appeal(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      statusId: json['status_id'],
      address: json['address'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      filePaths: json['file_paths'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'status_id': statusId,
      'address': address,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'file_paths': filePaths
    };
  }
}