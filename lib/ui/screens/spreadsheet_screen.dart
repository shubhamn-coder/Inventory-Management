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

  void _openQuickStatusDialog(Product product) {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    final inUseController = TextEditingController(text: product.inUse.toString());
    final customQtyController = TextEditingController(text: product.customQty.toString());
    final customLabelController = TextEditingController(text: product.customLabel ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final inUse = int.tryParse(inUseController.text.trim()) ?? 0;
          final customQty = int.tryParse(customQtyController.text.trim()) ?? 0;
          final inStock = (product.quantity - inUse - customQty).clamp(0, product.quantity);

          void setInUseValue(int newVal) {
            final clamped = newVal.clamp(0, product.quantity);
            inUseController.text = clamped.toString();
            setDialogState(() {});
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.build_circle_rounded, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Categorize / Deploy: ${product.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live Breakdown Summary Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('${product.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const Text('Total Owned', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white10),
                        Column(
                          children: [
                            Text('$inStock', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                            const Text('In Stock', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white10),
                        Column(
                          children: [
                            Text('$inUse', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                            const Text('In Use', style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // In-Use Field with Quick Steppers (+1 USE / -1 USE)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: inUseController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Quantity In Use / Deployed',
                            labelStyle: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                            prefixIcon: const Icon(Icons.build_circle_outlined, color: Colors.amberAccent, size: 18),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Quick +1 Stepper
                      ElevatedButton(
                        onPressed: inStock > 0 ? () => setInUseValue(inUse + 1) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('+1 USE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      // Quick -1 Stepper
                      OutlinedButton(
                        onPressed: inUse > 0 ? () => setInUseValue(inUse - 1) : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amberAccent,
                          side: const BorderSide(color: Colors.amberAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('-1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Custom Tag & Location Section
                  const Text(
                    'Custom Tag / Location (e.g. Robot 1, Project A)',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: customQtyController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          style: const TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Custom Qty',
                            labelStyle: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
                            prefixIcon: const Icon(Icons.label_outline, color: Colors.purpleAccent, size: 15),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: customLabelController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Tag (e.g. Robot1)',
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick Tag Presets Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['Robot 1', 'Robot 2', 'Test Rig', 'Project Alpha'].map((preset) {
                      return ActionChip(
                        label: Text(preset, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
                        backgroundColor: Colors.purple.withValues(alpha: 0.15),
                        side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          customLabelController.text = preset;
                          if (customQty == 0) {
                            customQtyController.text = '1';
                          }
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newInUse = int.tryParse(inUseController.text.trim()) ?? 0;
                  final newCustomQty = int.tryParse(customQtyController.text.trim()) ?? 0;
                  final newCustomLabel = customLabelController.text.trim();

                  final updated = product.copyWith(
                    inUse: newInUse,
                    customQty: newCustomQty,
                    customLabel: newCustomLabel.isNotEmpty ? newCustomLabel : null,
                    clearCustomLabel: newCustomLabel.isEmpty,
                  );

                  await widget.storageService.updateProduct(updated);
                  Navigator.of(ctx).pop();
                  widget.onDataChanged();
                  setState(() {});
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('SAVE CATEGORIZATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
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

                // 2. QUANTITY (Direct Numeric Typing + Steppers in Edit Mode)
                Expanded(
                  flex: 3,
                  child: _isEditMode && !isViewOnly
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => _updateProductQuantity(product, (product.quantity - 1).clamp(0, 999999)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.remove, size: 13, color: Colors.cyanAccent),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                initialValue: '${product.quantity}',
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: Colors.amberAccent),
                                  ),
                                ),
                                onFieldSubmitted: (val) {
                                  final parsed = int.tryParse(val.trim());
                                  if (parsed != null && parsed >= 0) {
                                    _updateProductQuantity(product, parsed);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: () => _updateProductQuantity(product, product.quantity + 1),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.add, size: 13, color: Colors.cyanAccent),
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
                  // Status Breakdown Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text('✅ ${product.inStock} In Stock', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      if (product.inUse > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text('🔧 ${product.inUse} In Use', style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      if (product.customQty > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '📍 ${product.customQty} ${product.customLabel ?? "Custom"}',
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (product.subcategory != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('📁 ${product.subcategory!}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ),
                      if (product.company != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

                      // Prominent USE Button & Full Edit Modal
                      if (!isViewOnly)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _openQuickStatusDialog(product),
                              icon: const Icon(Icons.build_circle_rounded, size: 13),
                              label: const Text('USE ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amberAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _openFullEditModal(product),
                              icon: const Icon(Icons.edit_note, size: 15, color: Colors.cyanAccent),
                              label: const Text('FULL EDIT', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 17, color: Colors.grey),
                              color: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onSelected: (val) {
                                if (val == 'status') {
                                  _openQuickStatusDialog(product);
                                } else if (val == 'delete') {
                                  _deleteProduct(product);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'status',
                                  child: Row(
                                    children: [
                                      Icon(Icons.build_circle_rounded, color: Colors.amberAccent, size: 16),
                                      SizedBox(width: 8),
                                      Text('Categorize / Use Item', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
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
