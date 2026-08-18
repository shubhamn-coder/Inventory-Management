import 'package:flutter/material.dart';
import '../../data/services/csv_service.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory.dart';

class SpreadsheetScreen extends StatefulWidget {
  final List<Product> products;
  final List<Inventory> inventories;
  final Inventory? activeInventory;

  const SpreadsheetScreen({
    super.key,
    required this.products,
    required this.inventories,
    this.activeInventory,
  });

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  String _searchQuery = '';
  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  List<Product> get _filteredProducts {
    return widget.products.where((p) {
      final query = _searchQuery.toLowerCase();
      final matchesName = p.name.toLowerCase().contains(query);
      final matchesCompany = (p.company ?? '').toLowerCase().contains(query);
      final matchesSubcat = (p.subcategory ?? '').toLowerCase().contains(query);
      final matchesLoc = (p.location ?? '').toLowerCase().contains(query);
      return matchesName || matchesCompany || matchesSubcat || matchesLoc;
    }).toList()
      ..sort((a, b) {
        int comp = 0;
        switch (_sortColumnIndex) {
          case 1:
            comp = a.name.compareTo(b.name);
            break;
          case 2:
            comp = a.quantity.compareTo(b.quantity);
            break;
          case 3:
            comp = (a.cost ?? 0.0).compareTo(b.cost ?? 0.0);
            break;
          case 4:
            final valA = (a.cost ?? 0.0) * a.quantity;
            final valB = (b.cost ?? 0.0) * b.quantity;
            comp = valA.compareTo(valB);
            break;
          case 7:
            comp = (a.company ?? '').compareTo(b.company ?? '');
            break;
          default:
            comp = a.name.compareTo(b.name);
        }
        return _sortAscending ? comp : -comp;
      });
  }

  void _exportCsv() {
    final csvData = CsvService.generateCsv(
      products: widget.products,
      inventories: widget.inventories,
      currentInventoryName: widget.activeInventory?.name,
    );
    final fileName = 'Robotics_Inventory_${DateTime.now().millisecondsSinceEpoch}.csv';
    CsvService.downloadOrSaveCsv(csvContent: csvData, fileName: fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Spreadsheet exported: $fileName'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final totalQty = products.fold<int>(0, (sum, p) => sum + p.quantity);
    final totalVal = products.fold<double>(0.0, (sum, p) => sum + ((p.cost ?? 0.0) * p.quantity));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automatic Spreadsheet & Print View',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.activeInventory != null
                  ? 'Group: ${widget.activeInventory!.name}'
                  : 'Group: All Club Inventories (${products.length} items)',
              style: TextStyle(color: Colors.cyanAccent.withValues(alpha: 0.8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('EXPORT SPREADSHEET (.CSV)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search bar inside spreadsheet screen
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search spreadsheet by Name, Company, Subcategory, Location...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_rounded, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Total Items: $totalQty  |  Total Value: ₹${totalVal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Interactive Data Table View
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                  dataRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                  border: TableBorder.all(color: Colors.cyan.withValues(alpha: 0.15)),
                  columns: [
                    const DataColumn(
                      label: Text('# ID', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: const Text('Product Name *', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      onSort: (index, asc) => setState(() {
                        _sortColumnIndex = index;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Quantity *', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      numeric: true,
                      onSort: (index, asc) => setState(() {
                        _sortColumnIndex = index;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Cost (₹)', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      numeric: true,
                      onSort: (index, asc) => setState(() {
                        _sortColumnIndex = index;
                        _sortAscending = asc;
                      }),
                    ),
                    DataColumn(
                      label: const Text('Total Value (₹)', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      numeric: true,
                      onSort: (index, asc) => setState(() {
                        _sortColumnIndex = index;
                        _sortAscending = asc;
                      }),
                    ),
                    const DataColumn(
                      label: Text('Subcategory', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                    const DataColumn(
                      label: Text('Location', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: const Text('Company', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      onSort: (index, asc) => setState(() {
                        _sortColumnIndex = index;
                        _sortAscending = asc;
                      }),
                    ),
                    const DataColumn(
                      label: Text('Datasheet', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                    const DataColumn(
                      label: Text('Inventory Group', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  rows: products.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    final inv = widget.inventories.firstWhere(
                      (i) => i.id == p.inventoryId,
                      orElse: () => Inventory(id: '', name: 'General', createdAt: DateTime.now()),
                    );
                    final cost = p.cost ?? 0.0;
                    final totalVal = cost * p.quantity;

                    return DataRow(
                      cells: [
                        DataCell(Text('PRD-${(index + 1).toString().padLeft(4, '0')}', style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.quantity <= 3
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${p.quantity}',
                              style: TextStyle(
                                color: p.quantity <= 3 ? Colors.amberAccent : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(p.cost != null ? '₹${p.cost!.toStringAsFixed(2)}' : '-', style: const TextStyle(color: Colors.white))),
                        DataCell(Text(p.cost != null ? '₹${totalVal.toStringAsFixed(2)}' : '-', style: const TextStyle(color: Colors.white))),
                        DataCell(Text(p.subcategory ?? '-', style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(p.location ?? '-', style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(p.company ?? '-', style: const TextStyle(color: Colors.grey))),
                        DataCell(
                          p.datasheetUrl != null
                              ? const Icon(Icons.picture_as_pdf, color: Colors.cyanAccent, size: 18)
                              : const Text('-', style: TextStyle(color: Colors.grey)),
                        ),
                        DataCell(Text(inv.name, style: const TextStyle(color: Colors.cyanAccent))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
