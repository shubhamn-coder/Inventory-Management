import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory.dart';

class CsvService {
  static String generateCsv({
    required List<Product> products,
    required List<Inventory> inventories,
    String? currentInventoryName,
  }) {
    final List<List<dynamic>> rows = [];

    // Header metadata row
    rows.add([
      'ROBOTICS CLUB INVENTORY MANAGER - AUTOMATIC SPREADSHEET REPORT',
    ]);
    rows.add([
      'Inventory:',
      currentInventoryName ?? 'All Inventories',
      'Generated:',
      DateTime.now().toString(),
    ]);
    rows.add([]); // Empty row space

    // Table Column Headers
    rows.add([
      'Item ID',
      'Product Name', // Compulsory
      'Quantity', // Compulsory
      'Cost (₹)',
      'Total Value (₹)',
      'Subcategory',
      'Location',
      'Company / Manufacturer',
      'Datasheet Link / File',
      'Notes',
      'Inventory Group',
    ]);

    // Data rows
    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      final inv = inventories.firstWhere(
        (element) => element.id == p.inventoryId,
        orElse: () => Inventory(id: '', name: 'Unassigned', createdAt: DateTime.now()),
      );
      final cost = p.cost ?? 0.0;
      final totalValue = cost * p.quantity;

      rows.add([
        'PRD-${(i + 1).toString().padLeft(4, '0')}',
        p.name,
        p.quantity,
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

    // Summary Totals
    rows.add([]);
    final totalQuantity = products.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalInventoryValue = products.fold<double>(
      0.0,
      (sum, item) => sum + ((item.cost ?? 0.0) * item.quantity),
    );

    rows.add([
      'TOTALS',
      '${products.length} Products',
      totalQuantity,
      '',
      '₹${totalInventoryValue.toStringAsFixed(2)}',
      '',
      '',
      '',
      '',
      '',
      '',
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
