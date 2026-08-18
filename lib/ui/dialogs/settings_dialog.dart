import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';

class SettingsDialog extends StatefulWidget {
  final StorageService storageService;

  const SettingsDialog({super.key, required this.storageService});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _oldCodeController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _confirmCodeController = TextEditingController();

  String? _error;
  String? _success;

  @override
  void dispose() {
    _oldCodeController.dispose();
    _newCodeController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  void _handleChangePasscode() {
    setState(() {
      _error = null;
      _success = null;
    });

    final oldCode = _oldCodeController.text.trim();
    final newCode = _newCodeController.text.trim();
    final confirmCode = _confirmCodeController.text.trim();

    if (oldCode.isEmpty || newCode.isEmpty || confirmCode.isEmpty) {
      setState(() => _error = 'Please fill in all passcode fields.');
      return;
    }

    if (!widget.storageService.verifyPasscode(oldCode)) {
      setState(() => _error = 'Current passcode is incorrect.');
      return;
    }

    if (newCode.length < 4) {
      setState(() => _error = 'New passcode must be at least 4 characters/digits.');
      return;
    }

    if (newCode != confirmCode) {
      setState(() => _error = 'New passcode and confirmation do not match.');
      return;
    }

    widget.storageService.setPasscode(newCode).then((_) {
      setState(() {
        _success = 'Passcode updated successfully to "$newCode"!';
        _oldCodeController.clear();
        _newCodeController.clear();
        _confirmCodeController.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPasscode = widget.storageService.getPasscode();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      title: Row(
        children: const [
          Icon(Icons.security, color: Colors.cyanAccent),
          SizedBox(width: 10),
          Text(
            'Security & Passcode Settings',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Code Settings',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current active access passcode: "$currentPasscode"',
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),

              if (_success != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: Text(_success!, style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                ),

              TextField(
                controller: _oldCodeController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Passcode',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _newCodeController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Passcode',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmCodeController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm New Passcode',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        ElevatedButton.icon(
          onPressed: _handleChangePasscode,
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('UPDATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }
}
