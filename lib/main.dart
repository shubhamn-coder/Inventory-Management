import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/services/storage_service.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  runApp(RoboticsInventoryApp(storageService: storageService));
}

class RoboticsInventoryApp extends StatefulWidget {
  final StorageService storageService;

  const RoboticsInventoryApp({super.key, required this.storageService});

  @override
  State<RoboticsInventoryApp> createState() => _RoboticsInventoryAppState();
}

class _RoboticsInventoryAppState extends State<RoboticsInventoryApp> {
  bool _showSplash = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    // Check if user session already exists
    final currentUser = widget.storageService.getCurrentUser();
    if (currentUser != null) {
      _isAuthenticated = true;
    }
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    widget.storageService.logoutUser().then((_) {
      setState(() {
        _isAuthenticated = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robotics Club Inventory Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.cyan,
          surface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: _showSplash
          ? SplashScreen(onSplashComplete: _onSplashComplete)
          : (_isAuthenticated
              ? DashboardScreen(
                  storageService: widget.storageService,
                  onLogout: _onLogout,
                )
              : AuthScreen(
                  storageService: widget.storageService,
                  onAuthenticated: _onAuthenticated,
                )),
    );
  }
}
