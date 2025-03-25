import 'package:housing_inspection_client/models/user.dart';

class Message {
  final int id;
  final int appealId;
  final int senderId;
  final String content;
  final DateTime createdAt;
  final List<String>? filePaths;
  final int? fileSize;
  final String? fileType;
  final User? sender;

  Message({
    required this.id,
    required this.appealId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.filePaths,
    this.fileSize,
    this.fileType,
    this.sender
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      appealId: json['appeal_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      filePaths: (json['file_paths'] as List<dynamic>?)?.map((e) => e as String).toList(),
      fileSize: json['file_size'],
      fileType: json['file_type'],
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }
}