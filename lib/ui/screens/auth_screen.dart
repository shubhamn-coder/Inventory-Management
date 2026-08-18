import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/user_account.dart';

class AuthScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onAuthenticated;

  const AuthScreen({
    super.key,
    required this.storageService,
    required this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Code Access Form
  final _codeController = TextEditingController();
  String? _codeError;

  // Login Form
  final _loginUserController = TextEditingController();
  final _loginPassController = TextEditingController();
  String? _loginError;

  // Register Form
  final _regUserController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPassController = TextEditingController();
  String _selectedRole = 'Member';
  String? _regError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _loginUserController.dispose();
    _loginPassController.dispose();
    _regUserController.dispose();
    _regEmailController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  void _handleCodeSubmit() {
    setState(() => _codeError = null);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter an access code');
      return;
    }

    final result = widget.storageService.verifyAccessCode(code);
    if (result['valid'] == true) {
      final isViewOnly = result['isViewOnly'] as bool;
      final role = result['role'] as String;
      widget.storageService.setCurrentUser(
        isViewOnly ? 'Guest (View Only)' : 'Passcode User',
        role: role,
        isViewOnly: isViewOnly,
      );
      widget.storageService.logAuditEvent(
        'Code Login',
        'Entered via access code ($role)',
      );
      widget.onAuthenticated();
    } else {
      setState(() => _codeError = 'Invalid Access Code. Please check and try again.');
    }
  }

  void _handleLoginSubmit() {
    setState(() => _loginError = null);
    final user = _loginUserController.text.trim();
    final pass = _loginPassController.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _loginError = 'Please fill in all fields');
      return;
    }

    final authenticated = widget.storageService.authenticateUser(user, pass);
    if (authenticated != null) {
      widget.onAuthenticated();
    } else {
      setState(() => _loginError = 'Invalid credentials. User not found.');
    }
  }

  void _handleRegisterSubmit() {
    setState(() => _regError = null);
    final user = _regUserController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPassController.text;

    if (user.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _regError = 'All fields are required');
      return;
    }

    final newAccount = UserAccount(
      username: user,
      email: email,
      password: pass,
      role: _selectedRole,
      createdAt: DateTime.now(),
    );

    widget.storageService.registerUser(newAccount).then((success) {
      if (success) {
        widget.onAuthenticated();
      } else {
        setState(() => _regError = 'Username already exists. Try another.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(
                      bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.precision_manufacturing, color: Colors.cyanAccent, size: 32),
                          SizedBox(width: 12),
                          Text(
                            'ROBO-STOCK',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Robotics Club Inventory Portal',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.cyanAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.cyanAccent,
                  indicatorWeight: 3,
                  labelColor: Colors.cyanAccent,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.pin_rounded), text: 'Passcode'),
                    Tab(icon: Icon(Icons.login_rounded), text: 'Login'),
                    Tab(icon: Icon(Icons.person_add_rounded), text: 'Register'),
                  ],
                ),

                // Tab Views Content
                SizedBox(
                  height: 350,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: PASSCODE ACCESS
                      _buildPasscodeTab(),

                      // TAB 2: LOGIN FORM
                      _buildLoginTab(),

                      // TAB 3: REGISTER FORM
                      _buildRegisterTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter Access Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your team access code or guest code to enter the inventory portal.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            obscureText: true,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 20),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 6),
              prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              errorText: _codeError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
              ),
            ),
            onSubmitted: (_) => _handleCodeSubmit(),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _handleCodeSubmit,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('ENTER INVENTORY PORTAL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loginError != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                _loginError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          TextField(
            controller: _loginUserController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username or Email',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPassController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyanAccent),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _handleLoginSubmit(),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _handleLoginSubmit,
            icon: const Icon(Icons.login),
            label: const Text('SIGN IN TO ACCOUNT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_regError != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                _regError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _regUserController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Member', child: Text('Member')),
                    DropdownMenuItem(value: 'Lab Lead', child: Text('Lab Lead')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regEmailController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.email, color: Colors.cyanAccent, size: 18),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regPassController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent, size: 18),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _handleRegisterSubmit,
            icon: const Icon(Icons.person_add),
            label: const Text('CREATE NEW ACCOUNT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
