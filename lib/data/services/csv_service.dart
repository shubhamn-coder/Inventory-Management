import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/history_snapshot.dart';

class CsvService {
  static String generateCsv({
    required List<Product> products,
    required List<Inventory> inventories,
    String? currentInventoryName,
  }) {
    final List<List<dynamic>> rows = [];

    rows.add(['ROBOSTOCK — INVENTORY SPREADSHEET EXPORT']);
    rows.add([
      'Inventory:',
      currentInventoryName ?? 'All Inventories',
      'Generated:',
      DateTime.now().toString(),
    ]);
    rows.add([]);

    rows.add([
      'Item ID',
      'Product Name',
      'Total Qty',
      'In Stock',
      'In Use',
      'Custom Location',
      'Custom Qty',
      'Cost (₹)',
      'Total Value (₹)',
      'Subcategory',
      'Location',
      'Company / Manufacturer',
      'Datasheet Link / File',
      'Notes',
      'Inventory Group',
    ]);

    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      final inv = inventories.firstWhere(
        (e) => e.id == p.inventoryId,
        orElse: () => Inventory(id: '', name: 'Unassigned', createdAt: DateTime.now()),
      );
      final cost = p.cost ?? 0.0;
      final totalValue = cost * p.quantity;

      rows.add([
        'PRD-${(i + 1).toString().padLeft(4, '0')}',
        p.name,
        p.quantity,
        p.inStock,
        p.inUse,
        p.customLabel ?? '-',
        p.customQty,
        p.cost != null ? p.cost!.toStringAsFixed(2) : 'N/A',
        p.cost != null ? totalValue.toStringAsFixed(2) : 'N/A',
        p.subcategory ?? '-',
        p.location ?? '-',
        p.company ?? '-',
        p.datasheetUrl ?? '-',
        p.notes ?? '-',
        inv.name,
      ]);
    }

    rows.add([]);
    final totalQuantity = products.fold<int>(0, (sum, p) => sum + p.quantity);
    final totalInventoryValue = products.fold<double>(
      0.0,
      (sum, p) => sum + ((p.cost ?? 0.0) * p.quantity),
    );

    rows.add([
      'TOTALS',
      '${products.length} Products',
      totalQuantity,
      '',
      '',
      '',
      '',
      '',
      '₹${totalInventoryValue.toStringAsFixed(2)}',
    ]);

    return csv.encode(rows);
  }

  /// Export a historical snapshot (not live data) to CSV
  static String generateSnapshotCsv(HistorySnapshot snapshot) {
    final List<List<dynamic>> rows = [];

    rows.add(['ROBOSTOCK — INVENTORY SNAPSHOT REPORT']);
    rows.add(['Inventory:', snapshot.inventoryName]);
    rows.add(['Recorded by:', snapshot.authorName]);
    rows.add([
      'Date:',
      '${snapshot.dayOfWeek}, ${snapshot.formattedDate} at ${snapshot.formattedTime}'
    ]);
    if (snapshot.notes.isNotEmpty) rows.add(['Notes:', snapshot.notes]);
    rows.add([]);

    rows.add([
      'Item',
      'Total Qty',
      'In Stock',
      'In Use',
      'Custom Location',
      'Custom Qty',
      'Cost (₹)',
      'Total Value (₹)',
      'Subcategory',
      'Company',
      'Location',
    ]);

    for (final p in snapshot.products) {
      final cost = p.cost ?? 0.0;
      rows.add([
        p.name,
        p.quantity,
        p.inStock,
        p.inUse,
        p.customLabel ?? '-',
        p.customQty,
        p.cost != null ? p.cost!.toStringAsFixed(2) : 'N/A',
        p.cost != null ? (cost * p.quantity).toStringAsFixed(2) : 'N/A',
        p.subcategory ?? '-',
        p.company ?? '-',
        p.location ?? '-',
      ]);
    }

    rows.add([]);
    rows.add([
      'TOTALS',
      snapshot.totalQuantity,
      '',
      '',
      '',
      '',
      '',
      '₹${snapshot.totalValue.toStringAsFixed(2)}',
    ]);

    return csv.encode(rows);
  }

  static Future<void> downloadOrSaveCsv({
    required String csvContent,
    required String fileName,
  }) async {
    final encoded = Uri.encodeComponent(csvContent);
    final url = 'data:text/csv;charset=utf-8,$encoded';
    await launchUrl(Uri.parse(url));
  }
}

