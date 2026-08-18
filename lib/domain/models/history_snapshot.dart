import 'product.dart';

class HistorySnapshot {
  final String id;
  final String inventoryId;
  final String inventoryName;
  final String authorName;
  final DateTime timestamp;
  final String dayOfWeek;
  final String formattedDate;
  final String formattedTime;
  final int totalProducts;
  final int totalQuantity;
  final double totalValue;
  final List<Product> products;
  final String notes;

  HistorySnapshot({
    required this.id,
    required this.inventoryId,
    required this.inventoryName,
    required this.authorName,
    required this.timestamp,
    required this.dayOfWeek,
    required this.formattedDate,
    required this.formattedTime,
    required this.totalProducts,
    required this.totalQuantity,
    required this.totalValue,
    required this.products,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'inventoryId': inventoryId,
        'inventoryName': inventoryName,
        'authorName': authorName,
        'timestamp': timestamp.toIso8601String(),
        'dayOfWeek': dayOfWeek,
        'formattedDate': formattedDate,
        'formattedTime': formattedTime,
        'totalProducts': totalProducts,
        'totalQuantity': totalQuantity,
        'totalValue': totalValue,
        'products': products.map((p) => p.toJson()).toList(),
        'notes': notes,
      };

  factory HistorySnapshot.fromJson(Map<String, dynamic> json) => HistorySnapshot(
        id: json['id'] as String,
        inventoryId: json['inventoryId'] as String,
        inventoryName: json['inventoryName'] as String,
        authorName: (json['authorName'] as String?) ?? 'Club Member',
        timestamp: DateTime.parse(json['timestamp'] as String),
        dayOfWeek: json['dayOfWeek'] as String,
        formattedDate: json['formattedDate'] as String,
        formattedTime: json['formattedTime'] as String,
        totalProducts: (json['totalProducts'] as num).toInt(),
        totalQuantity: (json['totalQuantity'] as num).toInt(),
        totalValue: (json['totalValue'] as num).toDouble(),
        products: (json['products'] as List<dynamic>?)
                ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        notes: (json['notes'] as String?) ?? '',
      );
}
