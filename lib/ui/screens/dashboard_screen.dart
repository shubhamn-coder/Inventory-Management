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

  /// Returns list of matching inventory IDs (including sub-inventories if parent is selected)
  Set<String>? get _activeInventoryScopeIds {
    if (widget.selectedInventoryId == null) return null; // All inventories
    final selectedId = widget.selectedInventoryId!;
    final matchingIds = <String>{selectedId};

    // Include all direct sub-inventories of the selected parent
    for (final inv in _inventories) {
      if (inv.parentInventoryId == selectedId) {
        matchingIds.add(inv.id);
      }
    }
    return matchingIds;
  }

  List<Product> get _filteredProducts {
    final scopeIds = _activeInventoryScopeIds;

    return _products.where((product) {
      if (scopeIds != null && !scopeIds.contains(product.inventoryId)) {
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
        final matchesTag = (product.customLabel ?? '').toLowerCase().contains(query);

        return matchesName || matchesCompany || matchesSubcat || matchesLoc || matchesTag;
      }
      return true;
    }).toList();
  }

  void _openCreateInventoryDialog({String? parentId}) {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    showDialog(
      context: context,
      builder: (_) => CreateInventoryDialog(
        existingInventories: _inventories,
        initialParentId: parentId,
        onCreated: (newInv) async {
          await widget.storageService.addInventory(newInv);
          widget.onInventoryChanged(newInv.id);
          widget.onDataChanged();
          setState(() {});
        },
      ),
    );
  }

  /// Quick bottom modal to update in-use and custom tags without full dialog
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

  /// Dialog to merge source inventory into another target inventory
  void _openMergeInventoryDialog(Inventory sourceInv) {
    final candidateTargets = _inventories.where((i) => i.id != sourceInv.id).toList();
    if (candidateTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 inventories are required to merge.')),
      );
      return;
    }

    String selectedTargetId = candidateTargets.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: const [
              Icon(Icons.merge_type_rounded, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Text('Merge Inventory', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merge "${sourceInv.name}" into another inventory. All its components will be moved into the target inventory, and "${sourceInv.name}" will be deleted.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedTargetId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Select Destination Inventory',
                  labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: candidateTargets
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedTargetId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.storageService.mergeInventories(sourceInv.id, selectedTargetId);
                if (widget.selectedInventoryId == sourceInv.id) {
                  widget.onInventoryChanged(selectedTargetId);
                }
                widget.onDataChanged();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully merged "${sourceInv.name}".'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.merge_type_rounded, size: 16),
              label: const Text('CONFIRM MERGE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to select components in source inventory to split off into a new inventory
  void _openSplitInventoryDialog(Inventory sourceInv) {
    final invProducts = _products.where((p) => p.inventoryId == sourceInv.id).toList();
    if (invProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No components in this inventory to split.')),
      );
      return;
    }

    final selectedProductIds = <String>{};
    final newNameController = TextEditingController(text: '${sourceInv.name} Sub-Group');
    bool makeAsSubInventory = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.cyan.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: const [
              Icon(Icons.call_split_rounded, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text('Split Inventory', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: newNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'New Inventory Name *',
                    labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: makeAsSubInventory,
                  activeColor: Colors.cyanAccent,
                  checkColor: Colors.black,
                  title: Text(
                    'Make as sub-inventory of "${sourceInv.name}"',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onChanged: (val) => setDialogState(() => makeAsSubInventory = val ?? true),
                ),
                const Divider(color: Colors.white10),
                Text(
                  'Select items to move to the new inventory (${selectedProductIds.length}/${invProducts.length} selected):',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: invProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = invProducts[i];
                      final isSelected = selectedProductIds.contains(p.id);

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: Colors.cyanAccent,
                        checkColor: Colors.black,
                        dense: true,
                        title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.quantity}x • ${p.subcategory ?? "General"}', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedProductIds.add(p.id);
                            } else {
                              selectedProductIds.remove(p.id);
                            }
                          });
                        },
                      );
                    },
                  ),
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
                final newName = newNameController.text.trim();
                if (newName.isEmpty || selectedProductIds.isEmpty) return;

                Navigator.of(ctx).pop();
                final created = await widget.storageService.splitInventory(
                  sourceInventoryId: sourceInv.id,
                  productIdsToMove: selectedProductIds.toList(),
                  newInventoryName: newName,
                  parentInventoryId: makeAsSubInventory ? sourceInv.id : null,
                );

                widget.onInventoryChanged(created.id);
                widget.onDataChanged();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Split ${selectedProductIds.length} items into "${created.name}".'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.call_split_rounded, size: 16),
              label: const Text('CONFIRM SPLIT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
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
              width: 480,
              height: 380,
              child: currentInventories.isEmpty
                  ? const Center(child: Text('No inventories found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: currentInventories.length,
                      itemBuilder: (ctx, index) {
                        final inv = currentInventories[index];
                        final count = allProducts.where((p) => p.inventoryId == inv.id).length;
                        final isSub = inv.isSubInventory;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSub ? Colors.cyan.withValues(alpha: 0.2) : Colors.white10,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isSub)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Colors.cyanAccent),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.name,
                                      style: TextStyle(
                                        color: isSub ? Colors.cyanAccent : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count components • ${isSub ? "Sub-inventory" : "Main inventory"}',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (!isViewOnly) ...[
                                // Sub-Inventory Add Button
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 18),
                                  tooltip: 'Add sub-inventory under "${inv.name}"',
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openCreateInventoryDialog(parentId: inv.id);
                                  },
                                ),
                                // Merge Button
                                IconButton(
                                  icon: const Icon(Icons.merge_type_rounded, color: Colors.amberAccent, size: 18),
                                  tooltip: 'Merge "${inv.name}" into another',
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openMergeInventoryDialog(inv);
                                  },
                                ),
                                // Split Button
                                IconButton(
                                  icon: const Icon(Icons.call_split_rounded, color: Colors.purpleAccent, size: 18),
                                  tooltip: 'Split components out of "${inv.name}"',
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openSplitInventoryDialog(inv);
                                  },
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  tooltip: 'Delete "${inv.name}"',
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    _deleteInventory(inv.id, inv.name);
                                  },
                                ),
                              ],
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
                                      child: Text(
                                        inv.isSubInventory ? '   ↳ ${inv.name}' : inv.name,
                                        style: TextStyle(
                                          color: inv.isSubInventory ? Colors.cyanAccent : Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                          onPressed: () => _openCreateInventoryDialog(),
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
                      hintText: 'Search by Name, Tag (Robot1), Company...',
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

                  // High Density Stats Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStripBadge('Types', '$totalProductsCount', Colors.white),
                        _buildSeparator(),
                        _buildStripBadge('Units', '$totalUnitsCount', Colors.cyanAccent),
                        _buildSeparator(),
                        _buildStripBadge('Total Value', '₹${totalValue.toStringAsFixed(0)}', Colors.greenAccent),
                        _buildSeparator(),
                        _buildStripBadge('Low Stock', '$lowStockCount', lowStockCount > 0 ? Colors.amberAccent : Colors.grey),
                      ],
                    ),
                  ),

                  // Filter Categories Horizontal Scroll Chips
                  if (categoriesList.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              label: const Text('All Categories', style: TextStyle(fontSize: 11)),
                              selected: _selectedCategoryFilter == null,
                              selectedColor: Colors.cyanAccent,
                              labelStyle: TextStyle(
                                color: _selectedCategoryFilter == null ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              onSelected: (_) {
                                setState(() => _selectedCategoryFilter = null);
                              },
                            ),
                          ),
                          ...categoriesList.map((cat) => Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: FilterChip(
                                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                                  selected: _selectedCategoryFilter == cat,
                                  selectedColor: Colors.cyanAccent,
                                  labelStyle: TextStyle(
                                    color: _selectedCategoryFilter == cat ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  backgroundColor: const Color(0xFF1E293B),
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
                      mainAxisExtent: 215, // Comfortable compact vertical height
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

  Widget _buildStripBadge(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
      ],
    );
  }

  Widget _buildSeparator() {
    return Container(
      height: 18,
      width: 1,
      color: Colors.white10,
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
          const SizedBox(height: 4),

          // Tappable Status breakdown visible directly under item name
          InkWell(
            onTap: () => _openQuickStatusDialog(product),
            borderRadius: BorderRadius.circular(4),
            child: Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                // In Stock badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✓ ${product.inStock} stock',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ),
                // In Use badge (if any)
                if (product.inUse > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🔧 ${product.inUse} in use',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                // Custom Tag badge (e.g. Robot 1)
                if (product.customQty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '📍 ${product.customQty} ${product.customLabel ?? "Custom"}',
                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),

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
          const SizedBox(height: 2),

          // Cost Info
          if (product.cost != null) ...[
            Text(
              '₹${cost.toStringAsFixed(0)} / unit • Tot: ₹${totalVal.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ] else
            const Text(
              'No cost recorded',
              style: TextStyle(color: Colors.grey, fontSize: 9),
            ),
          const SizedBox(height: 4),

          // Action Buttons Bar with PROMINENT 'USE' BUTTON
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
              const SizedBox(width: 4),

              // PROMINENT 'USE' BUTTON
              if (!isViewOnly)
                InkWell(
                  onTap: () => _openQuickStatusDialog(product),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.build_circle_rounded, size: 11, color: Colors.black),
                        SizedBox(width: 3),
                        Text(
                          'USE',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),

              // Edit (visible handy) + 3-Dot Menu
              if (!isViewOnly) ...[
                InkWell(
                  onTap: () => _openAddProductDialog(product),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit_outlined, size: 15, color: Colors.cyanAccent),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 15, color: Colors.grey),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val == 'status') {
                      _openQuickStatusDialog(product);
                    } else if (val == 'edit') {
                      _openAddProductDialog(product);
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
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.cyanAccent, size: 16),
                          SizedBox(width: 8),
                          Text('Full Edit', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
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
            ],
          ),
        ],
      ),
    );
  }
}

