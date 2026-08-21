class Product {
  final String id;
  final String inventoryId;
  final String name;
  final int quantity;
  final double? cost;
  final String? subcategory;
  final String? location;
  final String? company;
  final String? datasheetUrl;
  final String? datasheetType;
  final String? datasheetName;
  final String? notes;
  final DateTime createdAt;

  /// How many are currently deployed / in use
  final int inUse;

  /// How many are at a custom location (e.g. "Robot1")
  final int customQty;

  /// Label for the custom deployment (e.g. "Robot1", "Test Bench")
  final String? customLabel;

  /// Quantity physically available in storage (auto-computed, clamped >= 0)
  int get inStock => (quantity - inUse - customQty).clamp(0, quantity);

  /// True when any status breakdown has been set
  bool get hasStatusBreakdown => inUse > 0 || customQty > 0;

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
    this.inUse = 0,
    this.customQty = 0,
    this.customLabel,
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
        'inUse': inUse,
        'customQty': customQty,
        'customLabel': customLabel,
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
        inUse: (json['inUse'] as num?)?.toInt() ?? 0,
        customQty: (json['customQty'] as num?)?.toInt() ?? 0,
        customLabel: json['customLabel'] as String?,
      );

  Product copyWith({
    String? id,
    String? inventoryId,
    String? name,
    int? quantity,
    double? cost,
    bool clearCost = false,
    String? subcategory,
    String? location,
    String? company,
    String? datasheetUrl,
    String? datasheetType,
    String? datasheetName,
    String? notes,
    DateTime? createdAt,
    int? inUse,
    int? customQty,
    String? customLabel,
    bool clearCustomLabel = false,
  }) {
    return Product(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      cost: clearCost ? null : (cost ?? this.cost),
      subcategory: subcategory ?? this.subcategory,
      location: location ?? this.location,
      company: company ?? this.company,
      datasheetUrl: datasheetUrl ?? this.datasheetUrl,
      datasheetType: datasheetType ?? this.datasheetType,
      datasheetName: datasheetName ?? this.datasheetName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      inUse: inUse ?? this.inUse,
      customQty: customQty ?? this.customQty,
      customLabel: clearCustomLabel ? null : (customLabel ?? this.customLabel),
    );
  }
}

