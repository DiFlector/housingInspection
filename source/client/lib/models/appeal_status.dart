class AppealStatus {
  final int id;
  final String name;

  AppealStatus({required this.id, required this.name});

  factory AppealStatus.fromJson(Map<String, dynamic> json) {
    return AppealStatus(
      id: json['id'],
      name: json['name'],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}