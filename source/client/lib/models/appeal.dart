import 'user.dart';

class Appeal {
  final int id;
  final int userId;
  final int categoryId;
  final int statusId;
  final String address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? filePaths; //  Изменяем тип
  final int? fileSize;
  final String? fileType;
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
    this.fileSize,
    this.fileType,
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
      filePaths: (json['file_paths'] as List<dynamic>?)?.map((e) => e as String).toList(), //  Обрабатываем как список
      fileSize: json['file_size'],
      fileType: json['file_type'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
// Метод toJson() нужен для отправки данных на сервер.
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
      'file_paths': filePaths,
      'file_size': fileSize,
      'file_type': fileType
    };
  }
}