import 'package:flutter/material.dart';
import '../../data/services/csv_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory.dart';
import '../dialogs/add_product_dialog.dart';
import '../dialogs/datasheet_dialog.dart';

class SpreadsheetScreen extends StatefulWidget {
  final StorageService storageService;
  final List<Product> products;
  final List<Inventory> inventories;
  final Inventory? activeInventory;
  final VoidCallback onDataChanged;

  const SpreadsheetScreen({
    super.key,
    required this.storageService,
    required this.products,
    required this.inventories,
    this.activeInventory,
    required this.onDataChanged,
  });

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  String _searchQuery = '';
  bool _isEditMode = false;
  final Set<String> _expandedRowIds = {};

  List<Product> get _filteredProducts {
    return widget.products.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();
      final matchesName = p.name.toLowerCase().contains(query);
      final matchesCompany = (p.company ?? '').toLowerCase().contains(query);
      final matchesSubcat = (p.subcategory ?? '').toLowerCase().contains(query);
      final matchesLoc = (p.location ?? '').toLowerCase().contains(query);
      return matchesName || matchesCompany || matchesSubcat || matchesLoc;
    }).toList();
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

  void _updateProductName(Product product, String newName) async {
    if (newName.trim().isEmpty || newName.trim() == product.name) return;
    final updated = product.copyWith(name: newName.trim());
    await widget.storageService.updateProduct(updated);
    widget.onDataChanged();
  }

  void _updateProductQuantity(Product product, int newQty) async {
    if (newQty < 0 || newQty == product.quantity) return;
    final updated = product.copyWith(quantity: newQty);
    await widget.storageService.updateProduct(updated);
    widget.onDataChanged();
    setState(() {});
  }

  void _updateProductCost(Product product, String costText) async {
    final cost = double.tryParse(costText.trim());
    final updated = product.copyWith(cost: cost);
    await widget.storageService.updateProduct(updated);
    widget.onDataChanged();
    setState(() {});
  }

  void _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Product?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${product.name}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storageService.deleteProduct(product.id);
      widget.onDataChanged();
      setState(() {});
    }
  }

  void _openFullEditModal(Product product) {
    showDialog(
      context: context,
      builder: (_) => AddProductDialog(
        activeInventoryId: product.inventoryId,
        inventories: widget.inventories,
        existingProduct: product,
        onSaved: (updated) async {
          await widget.storageService.updateProduct(updated);
          widget.onDataChanged();
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final totalQty = products.fold<int>(0, (sum, p) => sum + p.quantity);
    final totalVal = products.fold<double>(0.0, (sum, p) => sum + ((p.cost ?? 0.0) * p.quantity));
    final isViewOnly = widget.storageService.isViewOnlyMode();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Top Control Header: Search Bar + Edit Mode Switch + Export Button
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search spreadsheet items...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Export CSV Button
                    ElevatedButton.icon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: const Text('EXPORT', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Edit Mode Toggle Switch Banner
                if (!isViewOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isEditMode ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isEditMode ? Colors.amberAccent : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isEditMode ? Icons.edit_note_rounded : Icons.table_view_rounded,
                          color: _isEditMode ? Colors.amberAccent : Colors.cyanAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isEditMode
                                ? 'Direct In-Table Edit Mode ON (Tap cells to edit directly)'
                                : 'Table View Mode (Turn on Edit Mode to edit inline)',
                            style: TextStyle(
                              color: _isEditMode ? Colors.amberAccent : Colors.grey[300],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isEditMode,
                          activeThumbColor: Colors.amberAccent,
                          activeTrackColor: Colors.amber.withValues(alpha: 0.4),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: const Color(0xFF1E293B),
                          onChanged: (val) {
                            setState(() {
                              _isEditMode = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Condensed Totals Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.activeInventory != null ? widget.activeInventory!.name : 'All Club Inventories',
                  style: TextStyle(color: Colors.cyanAccent.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${products.length} Items  •  $totalQty Units  •  Total: ₹${totalVal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),

          // Table Header Row: Perfectly Fitted for Mobile Screen (NO horizontal scroll required!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                top: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
                bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Product Name *',
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Qty *',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Cost (₹)',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                SizedBox(width: 24), // Space for expand chevron
              ],
            ),
          ),

          // Interactive Spreadsheet Rows (Mobile-Optimized & In-Table Editable)
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text('No components matching search query.', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isExpanded = _expandedRowIds.contains(product.id);
                      return _buildSpreadsheetRow(product, index, isExpanded, isViewOnly);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetRow(Product product, int index, bool isExpanded, bool isViewOnly) {
    final cost = product.cost ?? 0.0;
    final totalRowVal = cost * product.quantity;
    final isLowStock = product.quantity <= 3;

    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? const Color(0xFF0F172A) : const Color(0xFF131F33),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Primary Row: Product Name, Quantity, Cost (₹)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. PRODUCT NAME (Direct In-Table Edit in Edit Mode)
                Expanded(
                  flex: 5,
                  child: _isEditMode && !isViewOnly
                      ? TextFormField(
                          initialValue: product.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.amberAccent),
                            ),
                          ),
                          onFieldSubmitted: (val) => _updateProductName(product, val),
                        )
                      : Text(
                          product.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 6),

                // 2. QUANTITY (Direct Stepper in Edit Mode)
                Expanded(
                  flex: 3,
                  child: _isEditMode && !isViewOnly
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => _updateProductQuantity(product, product.quantity - 1),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.remove, size: 14, color: Colors.cyanAccent),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${product.quantity}',
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            InkWell(
                              onTap: () => _updateProductQuantity(product, product.quantity + 1),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.add, size: 14, color: Colors.cyanAccent),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLowStock ? Colors.amber.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${product.quantity}x',
                              style: TextStyle(
                                color: isLowStock ? Colors.amberAccent : Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 6),

                // 3. COST (₹) (Direct In-Table Edit in Edit Mode)
                Expanded(
                  flex: 4,
                  child: _isEditMode && !isViewOnly
                      ? TextFormField(
                          initialValue: product.cost != null ? product.cost!.toStringAsFixed(0) : '',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: '₹',
                            prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.amberAccent),
                            ),
                          ),
                          onFieldSubmitted: (val) => _updateProductCost(product, val),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              product.cost != null ? '₹${product.cost!.toStringAsFixed(2)}' : 'N/A',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (product.cost != null)
                              Text(
                                'Tot: ₹${totalRowVal.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                              ),
                          ],
                        ),
                ),

                // Expand/Details Chevron
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedRowIds.remove(product.id);
                      } else {
                        _expandedRowIds.add(product.id);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Secondary Expandable Detail Box (Subcategory, Location, Company, Datasheet, Edit & Delete)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              color: const Color(0xFF16233B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (product.subcategory != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('📁 ${product.subcategory!}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ),
                      if (product.company != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('🏢 ${product.company!}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                        ),
                      if (product.location != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('📍 ${product.location!}', style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
                        ),
                    ],
                  ),
                  if (product.notes != null && product.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Notes: ${product.notes!}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Datasheet Button
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => DatasheetDialog(product: product),
                          );
                        },
                        icon: Icon(
                          product.datasheetUrl != null ? Icons.picture_as_pdf : Icons.description_outlined,
                          size: 13,
                          color: product.datasheetUrl != null ? Colors.cyanAccent : Colors.grey,
                        ),
                        label: Text(
                          product.datasheetUrl != null ? 'VIEW DATASHEET' : 'NO DATASHEET',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.datasheetUrl != null ? Colors.cyanAccent : Colors.grey,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),

                      // Full Edit Modal & Delete
                      if (!isViewOnly)
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _openFullEditModal(product),
                              icon: const Icon(Icons.edit_note, size: 15, color: Colors.cyanAccent),
                              label: const Text('FULL EDIT', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 17),
                              onPressed: () => _deleteProduct(product),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
