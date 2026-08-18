import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/inventory.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'spreadsheet_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onLogout;

  const MainNavigationScreen({
    super.key,
    required this.storageService,
    required this.onLogout,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _selectedInventoryId;

  @override
  void initState() {
    super.initState();
    final inventories = widget.storageService.getInventories();
    if (inventories.isNotEmpty) {
      _selectedInventoryId = inventories.first.id;
    }
  }

  void _onDataChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.storageService.getCurrentUser();
    final isSuperAdmin = widget.storageService.isSuperAdmin();
    final isViewOnly = widget.storageService.isViewOnlyMode();

    final inventories = widget.storageService.getInventories();
    final allProducts = widget.storageService.getProducts();

    final activeInv = inventories.firstWhere(
      (i) => i.id == _selectedInventoryId,
      orElse: () => Inventory(id: '', name: 'All Inventories', createdAt: DateTime.now()),
    );

    final filteredProducts = _selectedInventoryId == null
        ? allProducts
        : allProducts.where((p) => p.inventoryId == _selectedInventoryId).toList();

    // 4 Main Tabs (Requirement #4)
    final List<Widget> screens = [
      // TAB 0: INVENTORY
      DashboardScreen(
        storageService: widget.storageService,
        selectedInventoryId: _selectedInventoryId,
        onInventoryChanged: (newId) => setState(() => _selectedInventoryId = newId),
        onDataChanged: _onDataChanged,
      ),

      // TAB 1: SPREADSHEET (with Edit option)
      SpreadsheetScreen(
        storageService: widget.storageService,
        products: filteredProducts,
        inventories: inventories,
        activeInventory: _selectedInventoryId != null ? activeInv : null,
        onDataChanged: _onDataChanged,
      ),

      // TAB 2: HISTORY (with Author, Day, Date, Time)
      HistoryScreen(
        storageService: widget.storageService,
        activeInventoryId: _selectedInventoryId,
      ),

      // TAB 3: PROFILE & SETTINGS (with Code generator & Admin console)
      ProfileScreen(
        storageService: widget.storageService,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 3,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.precision_manufacturing, color: Colors.cyanAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'ROBO-STOCK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          // Current User / Permission Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSuperAdmin
                  ? Colors.amber.withValues(alpha: 0.2)
                  : (isViewOnly ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.cyan.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSuperAdmin ? Colors.amberAccent : (isViewOnly ? Colors.grey : Colors.cyanAccent),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuperAdmin ? Icons.shield : (isViewOnly ? Icons.visibility : Icons.person),
                  size: 13,
                  color: isSuperAdmin ? Colors.amberAccent : (isViewOnly ? Colors.grey : Colors.cyanAccent),
                ),
                const SizedBox(width: 4),
                Text(
                  currentUser,
                  style: TextStyle(
                    color: isSuperAdmin ? Colors.amberAccent : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      // IndexedStack preserves tab scroll states
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),

      // REQUIREMENT #4: Bottom Navigation Bar with Inventory, Spreadsheet, History, Profile
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: Colors.cyanAccent,
        surfaceTintColor: Colors.transparent,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: Colors.black),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.table_chart_rounded, color: Colors.black),
            label: 'Spreadsheet',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.history_rounded, color: Colors.black),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Colors.grey),
            selectedIcon: Icon(Icons.person_rounded, color: Colors.black),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
