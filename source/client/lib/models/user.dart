class User {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'full_name': fullName,
    'role': role,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };
}