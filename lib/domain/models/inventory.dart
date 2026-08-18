class Inventory {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  Inventory({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
