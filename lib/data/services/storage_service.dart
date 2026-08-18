import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/access_code.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/models/history_snapshot.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/product.dart';
import '../../domain/models/user_account.dart';

class StorageService {
  static const String supabaseUrl = 'https://tufwrobqtidnteapaunv.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ZbOUXXtpQ-iCa_0UOMGFVw_NkJXvq3v';

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
  static const String _initialSeedKey = 'initial_seed_done_v4';

  // Confidential Super Admin Credentials
  static const String _superAdminEmail = 'shubhamn5488@gmail.com';
  static const String _superAdminPassword = 'roboiswild';

  final SharedPreferences _prefs;
  final SupabaseClient? _supabase;

  StorageService(this._prefs, [this._supabase]);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    SupabaseClient? client;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      client = Supabase.instance.client;
      if (kDebugMode) print('Connected to Supabase Cloud PostgreSQL successfully!');
    } catch (e) {
      if (kDebugMode) print('Supabase initialization fallback: $e');
    }

    final service = StorageService(prefs, client);
    await service._syncFromSupabase();
    await service._seedSampleDataIfNeeded();
    return service;
  }

  // --- CLOUD SYNC ENGINE ---
  Future<void> _syncFromSupabase() async {
    if (_supabase == null) return;
    try {
      // 1. Fetch Inventories
      final invRows = await _supabase.from('inventories').select().order('created_at', ascending: true);
      if (invRows.isNotEmpty) {
        final inventories = invRows.map((r) => Inventory(
          id: r['id'] as String,
          name: r['name'] as String,
          description: (r['description'] as String?) ?? '',
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        )).toList();
        final raw = inventories.map((i) => jsonEncode(i.toJson())).toList();
        await _prefs.setStringList(_inventoriesKey, raw);
      }

      // 2. Fetch Products
      final prodRows = await _supabase.from('products').select().order('created_at', ascending: true);
      if (prodRows.isNotEmpty) {
        final products = prodRows.map((r) => Product(
          id: r['id'] as String,
          inventoryId: r['inventory_id'] as String,
          name: r['name'] as String,
          quantity: (r['quantity'] as num).toInt(),
          cost: r['cost'] != null ? (r['cost'] as num).toDouble() : null,
          subcategory: r['subcategory'] as String?,
          location: r['location'] as String?,
          company: r['company'] as String?,
          datasheetUrl: r['datasheet_url'] as String?,
          datasheetType: r['datasheet_type'] as String?,
          datasheetName: r['datasheet_name'] as String?,
          notes: r['notes'] as String?,
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        )).toList();
        final raw = products.map((p) => jsonEncode(p.toJson())).toList();
        await _prefs.setStringList(_productsKey, raw);
      }

      // 3. Fetch Access Codes
      final codeRows = await _supabase.from('access_codes').select().order('created_at', ascending: true);
      if (codeRows.isNotEmpty) {
        final codes = codeRows.map((r) => AccessCode(
          id: r['id'] as String,
          code: r['code'] as String,
          permission: (r['permission'] as String?) ?? 'view',
          createdBy: (r['created_by'] as String?) ?? 'Admin',
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        )).toList();
        final raw = codes.map((c) => jsonEncode(c.toJson())).toList();
        await _prefs.setStringList(_accessCodesKey, raw);
      }

      // 4. Fetch History Snapshots
      final snapRows = await _supabase.from('history_snapshots').select().order('timestamp', ascending: false);
      if (snapRows.isNotEmpty) {
        final snaps = snapRows.map((r) {
          List<Product> productsList = [];
          if (r['products'] != null) {
            final rawList = r['products'] is String ? jsonDecode(r['products']) as List : r['products'] as List;
            productsList = rawList.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
          }

          return HistorySnapshot(
            id: r['id'] as String,
            inventoryId: (r['inventory_id'] as String?) ?? '',
            inventoryName: r['inventory_name'] as String,
            authorName: r['author_name'] as String,
            timestamp: DateTime.tryParse(r['timestamp']?.toString() ?? '') ?? DateTime.now(),
            dayOfWeek: (r['day_of_week'] as String?) ?? '',
            formattedDate: (r['formatted_date'] as String?) ?? '',
            formattedTime: (r['formatted_time'] as String?) ?? '',
            totalProducts: (r['total_products'] as num?)?.toInt() ?? 0,
            totalQuantity: (r['total_quantity'] as num?)?.toInt() ?? 0,
            totalValue: (r['total_value'] as num?)?.toDouble() ?? 0.0,
            products: productsList,
            notes: (r['notes'] as String?) ?? '',
          );
        }).toList();
        final raw = snaps.map((s) => jsonEncode(s.toJson())).toList();
        await _prefs.setStringList(_historyKey, raw);
      }

      // 5. Fetch Audit Logs
      final logRows = await _supabase.from('audit_logs').select().order('timestamp', ascending: false).limit(100);
      if (logRows.isNotEmpty) {
        final logs = logRows.map((r) => AuditLog(
          id: r['id'] as String,
          action: r['action'] as String,
          actor: r['actor'] as String,
          details: (r['details'] as String?) ?? '',
          timestamp: DateTime.tryParse(r['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isAlert: (r['is_alert'] as bool?) ?? false,
        )).toList();
        final raw = logs.map((l) => jsonEncode(l.toJson())).toList();
        await _prefs.setStringList(_auditLogsKey, raw);
      }

      // 6. Fetch App Settings (Passcode)
      final settingRows = await _supabase.from('app_settings').select().eq('key', _passcodeKey);
      if (settingRows.isNotEmpty) {
        final pass = settingRows.first['value'] as String?;
        if (pass != null && pass.isNotEmpty) {
          await _prefs.setString(_passcodeKey, pass);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Supabase sync notice: $e');
    }
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
      _pushSettingToSupabase(_passcodeKey, newCode);
      await logAuditEvent(
        'Passcode Changed',
        'Primary access passcode updated from "$oldCode" to "$newCode"',
        isAlert: true,
      );
    }
    return res;
  }

  void _pushSettingToSupabase(String key, String value) {
    if (_supabase == null) return;
    _supabase.from('app_settings').upsert({'key': key, 'value': value}).catchError((e) {
      if (kDebugMode) print('Supabase settings push error: $e');
    });
  }

  Map<String, dynamic> verifyAccessCode(String inputCode) {
    final trimmed = inputCode.trim();

    if (getPasscode().trim() == trimmed) {
      return {'valid': true, 'isViewOnly': false, 'role': 'Member'};
    }

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

  // --- ACCESS CODES GENERATOR ---
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

    if (_supabase != null) {
      _supabase.from('access_codes').upsert({
        'id': accessCode.id,
        'code': accessCode.code,
        'permission': accessCode.permission,
        'created_by': accessCode.createdBy,
        'created_at': accessCode.createdAt.toIso8601String(),
      }).catchError((e) {
        if (kDebugMode) print('Supabase access code push error: $e');
      });
    }

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
    // Block registration with Super Admin email or username
    if (user.email.trim().toLowerCase() == _superAdminEmail.toLowerCase() ||
        user.username.trim().toLowerCase() == 'super admin') {
      return false;
    }

    final users = getUsers();
    if (users.any((u) => u.username.toLowerCase() == user.username.toLowerCase() ||
                         u.email.toLowerCase() == user.email.toLowerCase())) {
      return false;
    }

    // Strictly enforce Member role - no registration as Admin allowed
    final sanitizedUser = UserAccount(
      username: user.username.trim(),
      email: user.email.trim(),
      password: user.password,
      role: 'Member',
      createdAt: DateTime.now(),
    );

    users.add(sanitizedUser);
    final raw = users.map((u) => jsonEncode(u.toJson())).toList();
    await _prefs.setStringList(_usersKey, raw);
    await setCurrentUser(sanitizedUser.username, role: 'Member', isViewOnly: false);
    await logAuditEvent('User Registered', 'New member account created: ${sanitizedUser.username}');
    return true;
  }

  UserAccount? authenticateUser(String usernameOrEmail, String password) {
    final query = usernameOrEmail.trim().toLowerCase();

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

  // --- AUDIT LOGS ---
  List<AuditLog> getAuditLogs() {
    final raw = _prefs.getStringList(_auditLogsKey) ?? [];
    final list = raw.map((str) => AuditLog.fromJson(jsonDecode(str))).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
    if (list.length > 200) list.removeLast();
    final raw = list.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList(_auditLogsKey, raw);

    if (_supabase != null) {
      _supabase.from('audit_logs').upsert({
        'id': log.id,
        'action': log.action,
        'actor': log.actor,
        'details': log.details,
        'timestamp': log.timestamp.toIso8601String(),
        'is_alert': log.isAlert,
      }).catchError((e) {
        if (kDebugMode) print('Supabase audit log error: $e');
      });
    }
  }

  // --- INVENTORY HISTORY SNAPSHOTS ---
  List<HistorySnapshot> getHistorySnapshots() {
    final raw = _prefs.getStringList(_historyKey) ?? [];
    final list = raw.map((str) => HistorySnapshot.fromJson(jsonDecode(str))).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> saveHistorySnapshot({
    required Inventory inventory,
    required List<Product> products,
    required String authorName,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final dayOfWeek = DateFormat('EEEE').format(now);
    final formattedDate = DateFormat('dd MMM yyyy').format(now);
    final formattedTime = DateFormat('hh:mm:ss a').format(now);

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

    if (_supabase != null) {
      _supabase.from('history_snapshots').upsert({
        'id': snapshot.id,
        'inventory_id': snapshot.inventoryId,
        'inventory_name': snapshot.inventoryName,
        'author_name': snapshot.authorName,
        'timestamp': snapshot.timestamp.toIso8601String(),
        'day_of_week': snapshot.dayOfWeek,
        'formatted_date': snapshot.formattedDate,
        'formatted_time': snapshot.formattedTime,
        'total_products': snapshot.totalProducts,
        'total_quantity': snapshot.totalQuantity,
        'total_value': snapshot.totalValue,
        'products': snapshot.products.map((p) => p.toJson()).toList(),
        'notes': snapshot.notes,
      }).catchError((e) {
        if (kDebugMode) print('Supabase history push error: $e');
      });
    }

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

    if (_supabase != null) {
      _supabase.from('history_snapshots').delete().eq('id', id).catchError((e) {
        if (kDebugMode) print('Supabase delete error: $e');
      });
    }
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

    if (_supabase != null) {
      _supabase.from('inventories').upsert({
        'id': inventory.id,
        'name': inventory.name,
        'description': inventory.description,
        'created_at': inventory.createdAt.toIso8601String(),
      }).catchError((e) {
        if (kDebugMode) print('Supabase add inventory error: $e');
      });
    }

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

    if (_supabase != null) {
      _supabase.from('inventories').delete().eq('id', id).catchError((e) {
        if (kDebugMode) print('Supabase delete inventory error: $e');
      });
      _supabase.from('products').delete().eq('inventory_id', id).catchError((e) {
        if (kDebugMode) print('Supabase delete products error: $e');
      });
    }

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

    if (_supabase != null) {
      _supabase.from('products').upsert({
        'id': product.id,
        'inventory_id': product.inventoryId,
        'name': product.name,
        'quantity': product.quantity,
        'cost': product.cost,
        'subcategory': product.subcategory,
        'location': product.location,
        'company': product.company,
        'datasheet_url': product.datasheetUrl,
        'datasheet_type': product.datasheetType,
        'datasheet_name': product.datasheetName,
        'notes': product.notes,
        'created_at': product.createdAt.toIso8601String(),
      }).catchError((e) {
        if (kDebugMode) print('Supabase add product error: $e');
      });
    }

    await logAuditEvent('Product Added', 'Added "${product.name}" (${product.quantity}x) to inventory');
  }

  Future<void> updateProduct(Product product) async {
    final list = getProducts();
    final index = list.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      list[index] = product;
      await saveProducts(list);

      if (_supabase != null) {
        _supabase.from('products').upsert({
          'id': product.id,
          'inventory_id': product.inventoryId,
          'name': product.name,
          'quantity': product.quantity,
          'cost': product.cost,
          'subcategory': product.subcategory,
          'location': product.location,
          'company': product.company,
          'datasheet_url': product.datasheetUrl,
          'datasheet_type': product.datasheetType,
          'datasheet_name': product.datasheetName,
          'notes': product.notes,
          'created_at': product.createdAt.toIso8601String(),
        }).catchError((e) {
          if (kDebugMode) print('Supabase update product error: $e');
        });
      }

      await logAuditEvent('Product Updated', 'Updated "${product.name}" (Qty: ${product.quantity}, Cost: ₹${product.cost ?? 0})');
    }
  }

  Future<void> deleteProduct(String id) async {
    final list = getProducts();
    final deleted = list.firstWhere((p) => p.id == id, orElse: () => Product(id: '', inventoryId: '', name: 'Unknown', quantity: 0, createdAt: DateTime.now()));
    list.removeWhere((p) => p.id == id);
    await saveProducts(list);

    if (_supabase != null) {
      _supabase.from('products').delete().eq('id', id).catchError((e) {
        if (kDebugMode) print('Supabase delete product error: $e');
      });
    }

    await logAuditEvent('Product Deleted', 'Deleted "${deleted.name}" from inventory');
  }

  // --- SEED SAMPLE DATA TO LOCAL AND CLOUD ---
  Future<void> _seedSampleDataIfNeeded() async {
    final inventories = getInventories();
    if (inventories.isNotEmpty) return;

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

    for (final inv in defaultInventories) {
      await addInventory(inv);
    }
    for (final prod in defaultProducts) {
      await addProduct(prod);
    }
    await _prefs.setBool(_initialSeedKey, true);
  }
}
