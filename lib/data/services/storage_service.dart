import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/access_code.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/models/history_snapshot.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/product.dart';
import '../../domain/models/user_account.dart';

class StorageService {
  static const String _passcodeKey = 'access_passcode';
  static const String _inventoriesKey = 'inventories_list';
  static const String _productsKey = 'products_list';
  static const String _usersKey = 'users_list';
  static const String _currentUserKey = 'current_user';
  static const String _currentUserRoleKey = 'current_user_role';
  static const String _isViewOnlyKey = 'is_view_only_mode';
  static const String _accessCodesKey = 'generated_access_codes';
  static const String _auditLogsKey = 'security_audit_logs';
  static const String _historyKey = 'inventory_history_snapshots';
  static const String _initialSeedKey = 'initial_seed_done_v3';

  // Confidential Super Admin Credentials (Not visible anywhere in public UI)
  static const String _superAdminEmail = 'shubhamn5488@gmail.com';
  static const String _superAdminPassword = 'roboiswild';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedSampleDataIfNeeded();
    return service;
  }

  // --- ACCESS CODE & PASSCODE ---
  String getPasscode() {
    return _prefs.getString(_passcodeKey) ?? '123456';
  }

  bool verifyPasscode(String inputCode) {
    return getPasscode().trim() == inputCode.trim();
  }

  Future<bool> setPasscode(String newCode) async {
    final oldCode = getPasscode();
    final res = await _prefs.setString(_passcodeKey, newCode);
    if (res) {
      await logAuditEvent(
        'Passcode Changed',
        'Primary access passcode updated from "$oldCode" to "$newCode"',
        isAlert: true,
      );
    }
    return res;
  }

  /// Verifies a passcode or custom generated access code.
  /// Returns a map with {'valid': bool, 'isViewOnly': bool, 'role': String}
  Map<String, dynamic> verifyAccessCode(String inputCode) {
    final trimmed = inputCode.trim();

    // 1. Check primary master passcode (Default edit access)
    if (getPasscode().trim() == trimmed) {
      return {'valid': true, 'isViewOnly': false, 'role': 'Member'};
    }

    // 2. Check generated custom access codes
    final customCodes = getAccessCodes();
    for (final ac in customCodes) {
      if (ac.code.trim() == trimmed) {
        return {
          'valid': true,
          'isViewOnly': ac.isViewOnly,
          'role': ac.isViewOnly ? 'Guest (View Only)' : 'Member (Edit Access)',
        };
      }
    }

    return {'valid': false, 'isViewOnly': false, 'role': 'None'};
  }

  // --- ACCESS CODES GENERATOR (Requirement #11) ---
  List<AccessCode> getAccessCodes() {
    final raw = _prefs.getStringList(_accessCodesKey) ?? [];
    return raw.map((str) => AccessCode.fromJson(jsonDecode(str))).toList();
  }

  Future<void> saveAccessCodes(List<AccessCode> codes) async {
    final raw = codes.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_accessCodesKey, raw);
  }

  Future<void> addAccessCode(AccessCode accessCode) async {
    final codes = getAccessCodes();
    codes.add(accessCode);
    await saveAccessCodes(codes);

    // If Edit code is generated, log an alert event so Super Admin is notified!
    await logAuditEvent(
      accessCode.isEdit ? 'Edit Access Code Generated' : 'View-Only Code Generated',
      'Code "${accessCode.code}" (${accessCode.permission.toUpperCase()}) created by ${getCurrentUser()}',
      isAlert: accessCode.isEdit,
    );
  }

  // --- USERS & AUTH ---
  List<UserAccount> getUsers() {
    final raw = _prefs.getStringList(_usersKey) ?? [];
    return raw.map((str) => UserAccount.fromJson(jsonDecode(str))).toList();
  }

  Future<bool> registerUser(UserAccount user) async {
    final users = getUsers();
    if (users.any((u) => u.username.toLowerCase() == user.username.toLowerCase())) {
      return false;
    }
    users.add(user);
    final raw = users.map((u) => jsonEncode(u.toJson())).toList();
    await _prefs.setStringList(_usersKey, raw);
    await setCurrentUser(user.username, role: user.role, isViewOnly: false);
    await logAuditEvent('User Registered', 'New user account created: ${user.username} (${user.role})');
    return true;
  }

  UserAccount? authenticateUser(String usernameOrEmail, String password) {
    final query = usernameOrEmail.trim().toLowerCase();

    // 1. Direct Super Admin Login (Requirement #9)
    if (query == _superAdminEmail.toLowerCase() && password == _superAdminPassword) {
      setCurrentUser('Super Admin', role: 'Super Admin', isViewOnly: false);
      logAuditEvent('Admin Login', 'Super Admin logged in successfully');
      return UserAccount(
        username: 'Super Admin',
        email: _superAdminEmail,
        password: '',
        role: 'Super Admin',
        createdAt: DateTime.now(),
      );
    }

    // 2. Standard Registered Users
    final users = getUsers();
    try {
      final user = users.firstWhere(
        (u) =>
            (u.username.toLowerCase() == query || u.email.toLowerCase() == query) &&
            u.password == password,
      );
      setCurrentUser(user.username, role: user.role, isViewOnly: false);
      logAuditEvent('User Login', 'User logged in: ${user.username}');
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser(String username) async {
    final users = getUsers();
    users.removeWhere((u) => u.username == username);
    final raw = users.map((u) => jsonEncode(u.toJson())).toList();
    await _prefs.setStringList(_usersKey, raw);
    await logAuditEvent('User Removed', 'User account "$username" removed by ${getCurrentUser()}');
  }

  String getCurrentUser() {
    return _prefs.getString(_currentUserKey) ?? 'Member';
  }

  String getCurrentUserRole() {
    return _prefs.getString(_currentUserRoleKey) ?? 'Member';
  }

  bool isViewOnlyMode() {
    return _prefs.getBool(_isViewOnlyKey) ?? false;
  }

  bool isSuperAdmin() {
    return getCurrentUserRole() == 'Super Admin';
  }

  Future<void> setCurrentUser(
    String username, {
    String role = 'Member',
    bool isViewOnly = false,
  }) async {
    await _prefs.setString(_currentUserKey, username);
    await _prefs.setString(_currentUserRoleKey, role);
    await _prefs.setBool(_isViewOnlyKey, isViewOnly);
  }

  Future<void> logoutUser() async {
    await _prefs.remove(_currentUserKey);
    await _prefs.remove(_currentUserRoleKey);
    await _prefs.remove(_isViewOnlyKey);
  }

  // --- AUDIT LOGS (Requirement #9 & #11) ---
  List<AuditLog> getAuditLogs() {
    final raw = _prefs.getStringList(_auditLogsKey) ?? [];
    final list = raw.map((str) => AuditLog.fromJson(jsonDecode(str))).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
    return list;
  }

  Future<void> logAuditEvent(String action, String details, {bool isAlert = false}) async {
    final log = AuditLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      action: action,
      actor: getCurrentUser(),
      details: details,
      timestamp: DateTime.now(),
      isAlert: isAlert,
    );
    final list = getAuditLogs();
    list.insert(0, log);
    if (list.length > 200) list.removeLast(); // Cap at 200 events
    final raw = list.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList(_auditLogsKey, raw);
  }

  // --- INVENTORY HISTORY SNAPSHOTS (Requirement #8) ---
  List<HistorySnapshot> getHistorySnapshots() {
    final raw = _prefs.getStringList(_historyKey) ?? [];
    final list = raw.map((str) => HistorySnapshot.fromJson(jsonDecode(str))).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
    return list;
  }

  Future<void> saveHistorySnapshot({
    required Inventory inventory,
    required List<Product> products,
    required String authorName,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final dayOfWeek = DateFormat('EEEE').format(now); // e.g. "Tuesday"
    final formattedDate = DateFormat('dd MMM yyyy').format(now); // e.g. "18 Aug 2026"
    final formattedTime = DateFormat('hh:mm:ss a').format(now); // e.g. "06:24:12 PM"

    final totalQuantity = products.fold<int>(0, (sum, p) => sum + p.quantity);
    final totalVal = products.fold<double>(0.0, (sum, p) => sum + ((p.cost ?? 0.0) * p.quantity));

    final snapshot = HistorySnapshot(
      id: 'snap_${now.millisecondsSinceEpoch}',
      inventoryId: inventory.id,
      inventoryName: inventory.name,
      authorName: authorName,
      timestamp: now,
      dayOfWeek: dayOfWeek,
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      totalProducts: products.length,
      totalQuantity: totalQuantity,
      totalValue: totalVal,
      products: products,
      notes: notes,
    );

    final list = getHistorySnapshots();
    list.insert(0, snapshot);
    final raw = list.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_historyKey, raw);

    await logAuditEvent(
      'Snapshot Saved',
      'Inventory "${inventory.name}" snapshot saved by $authorName ($formattedDate at $formattedTime)',
    );
  }

  Future<void> deleteHistorySnapshot(String id) async {
    final list = getHistorySnapshots();
    list.removeWhere((s) => s.id == id);
    final raw = list.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_historyKey, raw);
  }

  // --- INVENTORIES ---
  List<Inventory> getInventories() {
    final raw = _prefs.getStringList(_inventoriesKey) ?? [];
    return raw.map((str) => Inventory.fromJson(jsonDecode(str))).toList();
  }

  Future<void> saveInventories(List<Inventory> inventories) async {
    final raw = inventories.map((i) => jsonEncode(i.toJson())).toList();
    await _prefs.setStringList(_inventoriesKey, raw);
  }

  Future<void> addInventory(Inventory inventory) async {
    final list = getInventories();
    list.add(inventory);
    await saveInventories(list);
    await logAuditEvent('Inventory Created', 'Created inventory group: "${inventory.name}"');
  }

  Future<void> deleteInventory(String id) async {
    final list = getInventories();
    final deleted = list.firstWhere((i) => i.id == id, orElse: () => Inventory(id: '', name: 'Unknown', createdAt: DateTime.now()));
    list.removeWhere((i) => i.id == id);
    await saveInventories(list);

    final products = getProducts();
    products.removeWhere((p) => p.inventoryId == id);
    await saveProducts(products);
    await logAuditEvent('Inventory Deleted', 'Deleted inventory group: "${deleted.name}"');
  }

  // --- PRODUCTS ---
  List<Product> getProducts() {
    final raw = _prefs.getStringList(_productsKey) ?? [];
    return raw.map((str) => Product.fromJson(jsonDecode(str))).toList();
  }

  Future<void> saveProducts(List<Product> products) async {
    final raw = products.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_productsKey, raw);
  }

  Future<void> addProduct(Product product) async {
    final list = getProducts();
    list.add(product);
    await saveProducts(list);
    await logAuditEvent('Product Added', 'Added "${product.name}" (${product.quantity}x) to inventory');
  }

  Future<void> updateProduct(Product product) async {
    final list = getProducts();
    final index = list.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      list[index] = product;
      await saveProducts(list);
      await logAuditEvent('Product Updated', 'Updated "${product.name}" (Qty: ${product.quantity}, Cost: ₹${product.cost ?? 0})');
    }
  }

  Future<void> deleteProduct(String id) async {
    final list = getProducts();
    final deleted = list.firstWhere((p) => p.id == id, orElse: () => Product(id: '', inventoryId: '', name: 'Unknown', quantity: 0, createdAt: DateTime.now()));
    list.removeWhere((p) => p.id == id);
    await saveProducts(list);
    await logAuditEvent('Product Deleted', 'Deleted "${deleted.name}" from inventory');
  }

  // --- SAMPLE DATA SEEDING ---
  Future<void> _seedSampleDataIfNeeded() async {
    final seeded = _prefs.getBool(_initialSeedKey) ?? false;
    if (seeded) return;

    final now = DateTime.now();
    final defaultInventories = [
      Inventory(
        id: 'inv_1',
        name: 'Main Robotics Lab',
        description: 'Primary component repository for general electronics and hardware',
        createdAt: now,
      ),
      Inventory(
        id: 'inv_2',
        name: 'Autonomous Rover Team',
        description: 'Parts specifically assigned for the outdoor rover project',
        createdAt: now,
      ),
      Inventory(
        id: 'inv_3',
        name: 'Drone & Aerial Robotics',
        description: 'Motors, ESCs, Flight Controllers, and LiPo batteries',
        createdAt: now,
      ),
    ];

    final defaultProducts = [
      Product(
        id: 'prod_1',
        inventoryId: 'inv_1',
        name: 'ESP32 NodeMCU Wi-Fi + BT Module',
        quantity: 15,
        cost: 450.0,
        subcategory: 'Microcontrollers',
        location: 'Shelf A - Bin 04',
        company: 'Espressif Systems',
        datasheetUrl: 'https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf',
        datasheetType: 'link',
        datasheetName: 'ESP32_Datasheet.pdf',
        notes: 'Dual-core 240MHz microcontroller for IoT communication',
        createdAt: now,
      ),
      Product(
        id: 'prod_2',
        inventoryId: 'inv_1',
        name: 'NEMA 17 Stepper Motor 1.7A',
        quantity: 8,
        cost: 950.0,
        subcategory: 'Motors & Actuators',
        location: 'Cabinet 2 - Drawer 1',
        company: 'StepperOnline',
        datasheetUrl: 'https://www.omc-stepperonline.com/download/17HS19-2004S1.pdf',
        datasheetType: 'link',
        datasheetName: 'NEMA17_SpecSheet.pdf',
        notes: 'High torque 59Ncm stepper motor for 3D printers and CNC arms',
        createdAt: now,
      ),
      Product(
        id: 'prod_3',
        inventoryId: 'inv_1',
        name: 'HC-SR04 Ultrasonic Distance Sensor',
        quantity: 24,
        cost: 180.0,
        subcategory: 'Sensors',
        location: 'Bin 12 - Sensors',
        company: 'SparkFun Electronics',
        datasheetUrl: 'https://cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf',
        datasheetType: 'link',
        datasheetName: 'HCSR04_Datasheet.pdf',
        notes: 'Detects range from 2cm to 400cm with non-contact sonar',
        createdAt: now,
      ),
      Product(
        id: 'prod_4',
        inventoryId: 'inv_1',
        name: 'L298N Dual H-Bridge Motor Driver',
        quantity: 6,
        cost: 320.0,
        subcategory: 'Motor Drivers',
        location: 'Shelf B - Box 3',
        company: 'STMicroelectronics',
        datasheetUrl: 'https://www.st.com/resource/en/datasheet/l298.pdf',
        datasheetType: 'link',
        datasheetName: 'L298N_DataSheet.pdf',
        notes: 'Drives DC motors up to 2A peak per channel',
        createdAt: now,
      ),
      Product(
        id: 'prod_5',
        inventoryId: 'inv_2',
        name: 'Arduino Mega 2560 R3',
        quantity: 4,
        cost: 2400.0,
        subcategory: 'Microcontrollers',
        location: 'Rover Lab - Kit Box A',
        company: 'Arduino',
        datasheetUrl: 'https://docs.arduino.cc/resources/datasheets/A000067-datasheet.pdf',
        datasheetType: 'link',
        datasheetName: 'Arduino_Mega2560_Datasheet.pdf',
        notes: 'ATmega2560 processor with 54 digital IO pins',
        createdAt: now,
      ),
      Product(
        id: 'prod_6',
        inventoryId: 'inv_2',
        name: 'RPi LiDAR A1M8 360 Degree Scanner',
        quantity: 2,
        cost: 7800.0,
        subcategory: 'Sensors',
        location: 'Rover Lab - Safe Locker',
        company: 'Slamtec',
        datasheetUrl: 'https://download.slamtec.com/data/filters/20210609/rplidar_A1M8_datasheet.pdf',
        datasheetType: 'link',
        datasheetName: 'RPLiDAR_A1M8_Datasheet.pdf',
        notes: '360 degree laser distance range scanner up to 12 meters',
        createdAt: now,
      ),
      Product(
        id: 'prod_7',
        inventoryId: 'inv_3',
        name: '3S LiPo Battery 11.1V 2200mAh 35C',
        quantity: 3,
        cost: 1650.0,
        subcategory: 'Power & Batteries',
        location: 'Battery Fireproof Safe',
        company: 'Tattu Electronics',
        datasheetUrl: 'https://www.genstattu.com/tattu-2200mah-11-1v-35c-3s1p-lipo-battery-pack.html',
        datasheetType: 'link',
        datasheetName: 'Tattu_3S_Battery_Specs.pdf',
        notes: 'High discharge battery pack with XT60 connector',
        createdAt: now,
      ),
    ];

    await saveInventories(defaultInventories);
    await saveProducts(defaultProducts);
    await _prefs.setBool(_initialSeedKey, true);
  }
}
