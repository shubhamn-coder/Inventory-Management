import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/product.dart';
import '../dialogs/add_product_dialog.dart';
import '../dialogs/create_inventory_dialog.dart';
import '../dialogs/datasheet_dialog.dart';
import '../dialogs/settings_dialog.dart';
import 'spreadsheet_screen.dart';

class DashboardScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.storageService,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Inventory> _inventories = [];
  List<Product> _products = [];

  String? _selectedInventoryId; // null = All Inventories
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _inventories = widget.storageService.getInventories();
      _products = widget.storageService.getProducts();
      if (_inventories.isNotEmpty && _selectedInventoryId == null) {
        _selectedInventoryId = _inventories.first.id;
      }
    });
  }

  // REQUIREMENT #6: Search products based on Name and Company
  List<Product> get _filteredProducts {
    return _products.where((product) {
      // 1. Inventory filter
      if (_selectedInventoryId != null && product.inventoryId != _selectedInventoryId) {
        return false;
      }

      // 2. Subcategory filter
      if (_selectedCategoryFilter != null && product.subcategory != _selectedCategoryFilter) {
        return false;
      }

      // 3. Search query filter: Name and Company
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
    showDialog(
      context: context,
      builder: (_) => CreateInventoryDialog(
        onCreated: (newInv) async {
          await widget.storageService.addInventory(newInv);
          setState(() {
            _selectedInventoryId = newInv.id;
          });
          _loadData();
        },
      ),
    );
  }

  void _openAddProductDialog([Product? existing]) {
    final activeId = _selectedInventoryId ?? (_inventories.isNotEmpty ? _inventories.first.id : '');
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
          _loadData();
        },
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(storageService: widget.storageService),
    );
  }

  void _openSpreadsheetScreen() {
    final activeInv = _inventories.firstWhere(
      (i) => i.id == _selectedInventoryId,
      orElse: () => Inventory(id: '', name: 'All Inventories', createdAt: DateTime.now()),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpreadsheetScreen(
          products: _filteredProducts,
          inventories: _inventories,
          activeInventory: _selectedInventoryId != null ? activeInv : null,
        ),
      ),
    );
  }

  void _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Product?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${product.name}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final currentUser = widget.storageService.getCurrentUser() ?? 'Member';

    // Summary Metrics
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.precision_manufacturing, color: Colors.cyanAccent, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'ROBO-STOCK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Inventory Group Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedInventoryId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('🌐 All Inventories Combined'),
                  ),
                  ..._inventories.map((inv) => DropdownMenuItem<String?>(
                        value: inv.id,
                        child: Text('📦 ${inv.name}'),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedInventoryId = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // REQUIREMENT #4: Create Inventory Option
          ElevatedButton.icon(
            onPressed: _openCreateInventoryDialog,
            icon: const Icon(Icons.create_new_folder, size: 16),
            label: const Text('+ INVENTORY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.withValues(alpha: 0.2),
              foregroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),

          // REQUIREMENT #7: Spreadsheet Option
          ElevatedButton.icon(
            onPressed: _openSpreadsheetScreen,
            icon: const Icon(Icons.table_chart, size: 16),
            label: const Text('SPREADSHEET'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.withValues(alpha: 0.2),
              foregroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),

          // Settings Button (Change Passcode)
          IconButton(
            tooltip: 'Security Settings & Passcode',
            icon: const Icon(Icons.settings, color: Colors.cyanAccent),
            onPressed: _openSettingsDialog,
          ),

          // Logout Button
          IconButton(
            tooltip: 'Sign Out ($currentUser)',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Metrics Summary Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row of Summary Metrics
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatCard(
                            title: 'Total Components',
                            value: '$totalProductsCount Types',
                            subtitle: '$totalUnitsCount total units in stock',
                            icon: Icons.category_rounded,
                            color: Colors.cyanAccent,
                            width: isMobile ? (constraints.maxWidth - 12) / 2 : 210,
                          ),
                          _buildStatCard(
                            title: 'Total Stock Quantity',
                            value: '$totalUnitsCount Units',
                            subtitle: 'Available for robotics builds',
                            icon: Icons.numbers_rounded,
                            color: Colors.blueAccent,
                            width: isMobile ? (constraints.maxWidth - 12) / 2 : 210,
                          ),
                          _buildStatCard(
                            title: 'Inventory Value',
                            value: '₹${totalValue.toStringAsFixed(2)}',
                            subtitle: 'Estimated equipment value',
                            icon: Icons.currency_rupee_rounded,
                            color: Colors.greenAccent,
                            width: isMobile ? (constraints.maxWidth - 12) / 2 : 210,
                          ),
                          _buildStatCard(
                            title: 'Low Stock Alert',
                            value: '$lowStockCount Items',
                            subtitle: 'Units count ≤ 3 requiring reorder',
                            icon: Icons.warning_amber_rounded,
                            color: lowStockCount > 0 ? Colors.amberAccent : Colors.grey,
                            width: isMobile ? (constraints.maxWidth - 12) / 2 : 210,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // REQUIREMENT #6: Search bar based on Name and Company
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '🔍 Search by Product Name, Company (e.g. Adafruit), Subcategory...',
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // REQUIREMENT #5: Add Product Button
                      ElevatedButton.icon(
                        onPressed: () => _openAddProductDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('+ ADD PRODUCT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
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
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                          ),
                          const SizedBox(width: 8),
                          ...categoriesList.map((cat) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: _selectedCategoryFilter == cat,
                                  selectedColor: Colors.cyanAccent,
                                  labelStyle: TextStyle(
                                    color: _selectedCategoryFilter == cat ? Colors.black : Colors.white,
                                    fontSize: 12,
                                  ),
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

          // Products Component Grid
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No components found matching search or filter.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openAddProductDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Component to Inventory'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = filtered[index];
                        return _buildProductCard(product);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final hasDatasheet = product.datasheetUrl != null && product.datasheetUrl!.isNotEmpty;
    final isLowStock = product.quantity <= 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock ? Colors.amber.withValues(alpha: 0.6) : Colors.cyan.withValues(alpha: 0.2),
          width: isLowStock ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Quantity Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Quantity Badge (Compulsory field)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLowStock ? Colors.amber.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLowStock ? Colors.amberAccent : Colors.cyanAccent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLowStock ? Icons.warning_amber : Icons.inventory_2,
                      size: 12,
                      color: isLowStock ? Colors.amberAccent : Colors.cyanAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${product.quantity}x',
                      style: TextStyle(
                        color: isLowStock ? Colors.amberAccent : Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subcategory & Location tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (product.subcategory != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.subcategory!,
                    style: TextStyle(color: Colors.grey[300], fontSize: 11),
                  ),
                ),
              if (product.company != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🏢 ${product.company!}',
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
                  ),
                ),
              if (product.location != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📍 ${product.location!}',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                  ),
                ),
            ],
          ),
          const Spacer(),

          // Cost per unit (in Indian Rupees)
          if (product.cost != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Cost: ₹${product.cost!.toStringAsFixed(2)} / unit (Total: ₹${(product.cost! * product.quantity).toStringAsFixed(2)})',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

          // Action Buttons: Datasheet (Requirement #8), Edit, Delete
          Row(
            children: [
              // Datasheet button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => DatasheetDialog(product: product),
                    );
                  },
                  icon: Icon(
                    hasDatasheet ? Icons.picture_as_pdf : Icons.description_outlined,
                    size: 14,
                    color: hasDatasheet ? Colors.cyanAccent : Colors.grey,
                  ),
                  label: Text(
                    hasDatasheet ? 'DATASHEET' : 'NO PDF',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasDatasheet ? Colors.cyanAccent : Colors.grey,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    side: BorderSide(
                      color: hasDatasheet ? Colors.cyan.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.cyanAccent),
                onPressed: () => _openAddProductDialog(product),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => _deleteProduct(product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
