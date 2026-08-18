import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/product.dart';
import '../../domain/models/user_account.dart';

class StorageService {
  static const String _passcodeKey = 'access_passcode';
  static const String _inventoriesKey = 'inventories_list';
  static const String _productsKey = 'products_list';
  static const String _usersKey = 'users_list';
  static const String _currentUserKey = 'current_user';
  static const String _initialSeedKey = 'initial_seed_done_v2';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedSampleDataIfNeeded();
    return service;
  }

  // --- ACCESS CODE ---
  String getPasscode() {
    return _prefs.getString(_passcodeKey) ?? '123456';
  }

  Future<bool> setPasscode(String newCode) async {
    return await _prefs.setString(_passcodeKey, newCode);
  }

  bool verifyPasscode(String inputCode) {
    return getPasscode().trim() == inputCode.trim();
  }

  // --- USERS ---
  List<UserAccount> getUsers() {
    final raw = _prefs.getStringList(_usersKey) ?? [];
    return raw.map((str) => UserAccount.fromJson(jsonDecode(str))).toList();
  }

  Future<bool> registerUser(UserAccount user) async {
    final users = getUsers();
    if (users.any((u) => u.username.toLowerCase() == user.username.toLowerCase())) {
      return false; // Username exists
    }
    users.add(user);
    final raw = users.map((u) => jsonEncode(u.toJson())).toList();
    await _prefs.setStringList(_usersKey, raw);
    await setCurrentUser(user.username);
    return true;
  }

  UserAccount? authenticateUser(String usernameOrEmail, String password) {
    final users = getUsers();
    final query = usernameOrEmail.trim().toLowerCase();
    try {
      final user = users.firstWhere(
        (u) =>
            (u.username.toLowerCase() == query || u.email.toLowerCase() == query) &&
            u.password == password,
      );
      setCurrentUser(user.username);
      return user;
    } catch (_) {
      return null;
    }
  }

  String? getCurrentUser() {
    return _prefs.getString(_currentUserKey);
  }

  Future<void> setCurrentUser(String username) async {
    await _prefs.setString(_currentUserKey, username);
  }

  Future<void> logoutUser() async {
    await _prefs.remove(_currentUserKey);
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
  }

  Future<void> deleteInventory(String id) async {
    final list = getInventories();
    list.removeWhere((i) => i.id == id);
    await saveInventories(list);

    // Remove products in this inventory
    final products = getProducts();
    products.removeWhere((p) => p.inventoryId == id);
    await saveProducts(products);
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
  }

  Future<void> updateProduct(Product product) async {
    final list = getProducts();
    final index = list.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      list[index] = product;
      await saveProducts(list);
    }
  }

  Future<void> deleteProduct(String id) async {
    final list = getProducts();
    list.removeWhere((p) => p.id == id);
    await saveProducts(list);
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
        cost: 450.0, // ₹450
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
        cost: 950.0, // ₹950
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
        cost: 180.0, // ₹180
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
        cost: 320.0, // ₹320
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
        cost: 2400.0, // ₹2400
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
        cost: 7800.0, // ₹7800
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
        quantity: 3, // Low stock warning!
        cost: 1650.0, // ₹1650
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
