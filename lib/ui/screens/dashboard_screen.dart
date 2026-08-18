import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/product.dart';
import '../dialogs/add_product_dialog.dart';
import '../dialogs/create_inventory_dialog.dart';
import '../dialogs/datasheet_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final StorageService storageService;
  final String? selectedInventoryId;
  final Function(String?) onInventoryChanged;
  final VoidCallback onDataChanged;

  const DashboardScreen({
    super.key,
    required this.storageService,
    required this.selectedInventoryId,
    required this.onInventoryChanged,
    required this.onDataChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  List<Inventory> get _inventories => widget.storageService.getInventories();
  List<Product> get _products => widget.storageService.getProducts();

  List<Product> get _filteredProducts {
    return _products.where((product) {
      if (widget.selectedInventoryId != null && product.inventoryId != widget.selectedInventoryId) {
        return false;
      }
      if (_selectedCategoryFilter != null && product.subcategory != _selectedCategoryFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesName = product.name.toLowerCase().contains(query);
        final matchesCompany = (product.company ?? '').toLowerCase().contains(query);
        final matchesSubcat = (product.subcategory ?? '').toLowerCase().contains(query);
        final matchesLoc = (product.location ?? '').toLowerCase().contains(query);

        return matchesName || matchesCompany || matchesSubcat || matchesLoc;
      }
      return true;
    }).toList();
  }

  void _openCreateInventoryDialog() {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    showDialog(
      context: context,
      builder: (_) => CreateInventoryDialog(
        onCreated: (newInv) async {
          await widget.storageService.addInventory(newInv);
          widget.onInventoryChanged(newInv.id);
          widget.onDataChanged();
          setState(() {});
        },
      ),
    );
  }

  void _openAddProductDialog([Product? existing]) {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    final activeId = widget.selectedInventoryId ?? (_inventories.isNotEmpty ? _inventories.first.id : '');
    if (activeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create an inventory group first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AddProductDialog(
        activeInventoryId: activeId,
        inventories: _inventories,
        existingProduct: existing,
        onSaved: (prod) async {
          if (existing != null) {
            await widget.storageService.updateProduct(prod);
          } else {
            await widget.storageService.addProduct(prod);
          }
          widget.onDataChanged();
          setState(() {});
        },
      ),
    );
  }

  void _deleteProduct(Product product) async {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Product?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${product.name}"?',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('DELETE', style: TextStyle(fontSize: 12)),
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

  void _deleteInventory(String id, String name) async {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Inventory?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete inventory group "$name"?\n\nAll components stored inside this inventory will also be permanently deleted.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('DELETE INVENTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storageService.deleteInventory(id);
      if (widget.selectedInventoryId == id) {
        widget.onInventoryChanged(null);
      }
      widget.onDataChanged();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventory "$name" deleted successfully.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showManageInventoriesModal() {
    final isViewOnly = widget.storageService.isViewOnlyMode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentInventories = widget.storageService.getInventories();
          final allProducts = widget.storageService.getProducts();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.inventory_2_rounded, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Inventories', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (!isViewOnly)
                  IconButton(
                    icon: const Icon(Icons.add_box_rounded, color: Colors.cyanAccent, size: 22),
                    tooltip: 'Create New Inventory',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openCreateInventoryDialog();
                    },
                  ),
              ],
            ),
            content: SizedBox(
              width: 420,
              height: 320,
              child: currentInventories.isEmpty
                  ? const Center(child: Text('No inventories found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: currentInventories.length,
                      itemBuilder: (ctx, index) {
                        final inv = currentInventories[index];
                        final count = allProducts.where((p) => p.inventoryId == inv.id).length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count components • ${inv.description.isNotEmpty ? inv.description : "No description"}',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (!isViewOnly)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete "${inv.name}"',
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    _deleteInventory(inv.id, inv.name);
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CLOSE', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final isViewOnly = widget.storageService.isViewOnlyMode();

    final totalProductsCount = filtered.length;
    final totalUnitsCount = filtered.fold<int>(0, (sum, p) => sum + p.quantity);
    final totalValue = filtered.fold<double>(0.0, (sum, p) => sum + ((p.cost ?? 0.0) * p.quantity));
    final lowStockCount = filtered.where((p) => p.quantity <= 3).length;

    final categoriesList = _products
        .map((p) => p.subcategory)
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final selectedInv = widget.selectedInventoryId != null
        ? _inventories.firstWhere((i) => i.id == widget.selectedInventoryId, orElse: () => Inventory(id: '', name: '', createdAt: DateTime.now()))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: isViewOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddProductDialog(),
              icon: const Icon(Icons.add_rounded, color: Colors.black, size: 20),
              label: const Text(
                'Add Item',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              backgroundColor: Colors.cyanAccent,
              elevation: 4,
            ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Inventory Selector, Delete Active Inventory, & + Inventory Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: widget.selectedInventoryId,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent, size: 20),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Inventories Combined', overflow: TextOverflow.ellipsis),
                                ),
                                ..._inventories.map((inv) => DropdownMenuItem<String?>(
                                      value: inv.id,
                                      child: Text(inv.name, overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (val) {
                                widget.onInventoryChanged(val);
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                      ),
                      // Delete specific selected inventory button
                      if (!isViewOnly && selectedInv != null && selectedInv.id.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _deleteInventory(selectedInv.id, selectedInv.name),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          ),
                        ),
                      ],
                      if (!isViewOnly) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _showManageInventoriesModal,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.settings_suggest_rounded, color: Colors.cyanAccent, size: 18),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _openCreateInventoryDialog,
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('NEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                            foregroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Top Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Company, Location...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Condensed Single Strip Info Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStripBadge(icon: Icons.category_rounded, label: '$totalProductsCount Types', color: Colors.cyanAccent),
                          _buildSeparator(),
                          _buildStripBadge(icon: Icons.numbers_rounded, label: '$totalUnitsCount Units', color: Colors.blueAccent),
                          _buildSeparator(),
                          _buildStripBadge(icon: Icons.currency_rupee_rounded, label: '₹${totalValue.toStringAsFixed(0)}', color: Colors.greenAccent),
                          if (lowStockCount > 0) ...[
                            _buildSeparator(),
                            _buildStripBadge(icon: Icons.warning_amber_rounded, label: '$lowStockCount Low Stock', color: Colors.amberAccent),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips
                  if (categoriesList.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Categories'),
                            selected: _selectedCategoryFilter == null,
                            selectedColor: Colors.cyanAccent,
                            labelStyle: TextStyle(
                              color: _selectedCategoryFilter == null ? Colors.black : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                          ),
                          const SizedBox(width: 6),
                          ...categoriesList.map((cat) => Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: _selectedCategoryFilter == cat,
                                  selectedColor: Colors.cyanAccent,
                                  labelStyle: TextStyle(
                                    color: _selectedCategoryFilter == cat ? Colors.black : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategoryFilter = selected ? cat : null;
                                    });
                                  },
                                ),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2-COLUMN ADJACENT TILES LAYOUT (Requirement: 2 tiles visible adjacent on mobile screen)
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 10),
                        Text(
                          'No components found.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 80),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220, // Forces exactly 2 tiles on mobile width (360-450px)
                      mainAxisExtent: 205, // Compact vertical height
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = filtered[index];
                        return _buildCompactTile(product, isViewOnly);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStripBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // Compact 2-Column Tile Card
  Widget _buildCompactTile(Product product, bool isViewOnly) {
    final hasDatasheet = product.datasheetUrl != null && product.datasheetUrl!.isNotEmpty;
    final isLowStock = product.quantity <= 3;
    final cost = product.cost ?? 0.0;
    final totalVal = cost * product.quantity;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLowStock ? Colors.amber.withValues(alpha: 0.6) : Colors.cyan.withValues(alpha: 0.25),
          width: isLowStock ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Quantity Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLowStock ? Colors.amber.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isLowStock ? Colors.amberAccent : Colors.cyanAccent),
                ),
                child: Text(
                  '${product.quantity}x',
                  style: TextStyle(
                    color: isLowStock ? Colors.amberAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subcategory & Company Micro-badges
          if (product.subcategory != null || product.company != null)
            Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                if (product.subcategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.subcategory!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (product.company != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.company!,
                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          const Spacer(),

          // Cost Info
          if (product.cost != null) ...[
            Text(
              '₹${cost.toStringAsFixed(0)} / unit',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
            Text(
              'Tot: ₹${totalVal.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ] else
            const Text(
              'No cost recorded',
              style: TextStyle(color: Colors.grey, fontSize: 9),
            ),
          const SizedBox(height: 4),

          // Action Buttons Bar
          Row(
            children: [
              // Datasheet Icon/Button
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => DatasheetDialog(product: product),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasDatasheet ? Colors.cyan.withValues(alpha: 0.15) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: hasDatasheet ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasDatasheet ? Icons.picture_as_pdf : Icons.description_outlined,
                        size: 11,
                        color: hasDatasheet ? Colors.cyanAccent : Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: 9,
                          color: hasDatasheet ? Colors.cyanAccent : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Edit & Delete Buttons
              if (!isViewOnly) ...[
                InkWell(
                  onTap: () => _openAddProductDialog(product),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit_outlined, size: 15, color: Colors.cyanAccent),
                  ),
                ),
                InkWell(
                  onTap: () => _deleteProduct(product),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
