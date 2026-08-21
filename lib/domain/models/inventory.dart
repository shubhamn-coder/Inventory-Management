class Inventory {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  /// If set, this inventory is a sub-inventory of the given parent ID
  final String? parentInventoryId;

  bool get isSubInventory =>
      parentInventoryId != null && parentInventoryId!.isNotEmpty;

  Inventory({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    this.parentInventoryId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'parentInventoryId': parentInventoryId,
      };

  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        parentInventoryId: json['parentInventoryId'] as String?,
      );
}
