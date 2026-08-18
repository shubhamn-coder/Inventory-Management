class Product {
  final String id;
  final String inventoryId;
  final String name; // Compulsory
  final int quantity; // Compulsory
  final double? cost; // Optional
  final String? subcategory; // Optional
  final String? location; // Optional
  final String? company; // Optional
  final String? datasheetUrl; // Optional
  final String? datasheetType; // 'link' or 'file'
  final String? datasheetName; // Display name
  final String? notes; // Optional
  final DateTime createdAt;

  Product({
    required this.id,
    required this.inventoryId,
    required this.name,
    required this.quantity,
    this.cost,
    this.subcategory,
    this.location,
    this.company,
    this.datasheetUrl,
    this.datasheetType,
    this.datasheetName,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'inventoryId': inventoryId,
        'name': name,
        'quantity': quantity,
        'cost': cost,
        'subcategory': subcategory,
        'location': location,
        'company': company,
        'datasheetUrl': datasheetUrl,
        'datasheetType': datasheetType,
        'datasheetName': datasheetName,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        inventoryId: json['inventoryId'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        cost: (json['cost'] as num?)?.toDouble(),
        subcategory: json['subcategory'] as String?,
        location: json['location'] as String?,
        company: json['company'] as String?,
        datasheetUrl: json['datasheetUrl'] as String?,
        datasheetType: json['datasheetType'] as String?,
        datasheetName: json['datasheetName'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Product copyWith({
    String? id,
    String? inventoryId,
    String? name,
    int? quantity,
    double? cost,
    String? subcategory,
    String? location,
    String? company,
    String? datasheetUrl,
    String? datasheetType,
    String? datasheetName,
    String? notes,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      subcategory: subcategory ?? this.subcategory,
      location: location ?? this.location,
      company: company ?? this.company,
      datasheetUrl: datasheetUrl ?? this.datasheetUrl,
      datasheetType: datasheetType ?? this.datasheetType,
      datasheetName: datasheetName ?? this.datasheetName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
