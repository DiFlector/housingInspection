class AppealCategory {
  final int id;
  final String name;

  AppealCategory({required this.id, required this.name});

  factory AppealCategory.fromJson(Map<String, dynamic> json) {
    return AppealCategory(
      id: json['id'],
      name: json['name'],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}