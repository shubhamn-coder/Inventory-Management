import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/access_code.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/models/user_account.dart';
import '../dialogs/settings_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.storageService,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AccessCode> _accessCodes = [];
  List<UserAccount> _users = [];
  List<AuditLog> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    final isAdmin = widget.storageService.isSuperAdmin();
    _tabController = TabController(length: isAdmin ? 3 : 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _accessCodes = widget.storageService.getAccessCodes();
      _users = widget.storageService.getUsers();
      _auditLogs = widget.storageService.getAuditLogs();
    });
  }

  void _showGenerateCodeDialog() {
    String selectedPermission = 'view';
    final generatedCode = (100000 + Random().nextInt(900000)).toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            title: Row(
              children: const [
                Icon(Icons.vpn_key_rounded, color: Colors.cyanAccent, size: 20),
                SizedBox(width: 8),
                Text('Generate Access Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Generate a 6-digit access code for visitors or members:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Permission Selector
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Permission Level:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('View Only', style: TextStyle(fontSize: 11)),
                                selected: selectedPermission == 'view',
                                selectedColor: Colors.cyanAccent,
                                labelStyle: TextStyle(
                                  color: selectedPermission == 'view' ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onSelected: (val) {
                                  if (val) setDialogState(() => selectedPermission = 'view');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Edit Access', style: TextStyle(fontSize: 11)),
                                selected: selectedPermission == 'edit',
                                selectedColor: Colors.amberAccent,
                                labelStyle: TextStyle(
                                  color: selectedPermission == 'edit' ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onSelected: (val) {
                                  if (val) setDialogState(() => selectedPermission = 'edit');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedPermission == 'view'
                              ? '• View Only: Can search and browse without editing.'
                              : '• Edit: Can add, modify, and delete components. (Admin alerted).',
                          style: TextStyle(
                            color: selectedPermission == 'edit' ? Colors.amberAccent : Colors.cyanAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Code Display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text('Generated Code:', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 2),
                        SelectableText(
                          generatedCode,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newCode = AccessCode(
                    id: 'code_${DateTime.now().millisecondsSinceEpoch}',
                    code: generatedCode,
                    permission: selectedPermission,
                    createdBy: widget.storageService.getCurrentUser(),
                    createdAt: DateTime.now(),
                  );

                  await widget.storageService.addAccessCode(newCode);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadData();
                  if (!mounted) return;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Access Code "$generatedCode" created!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('SAVE CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Remove User Account?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Remove user account "$username"?', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            child: const Text('REMOVE', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storageService.deleteUser(username);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.storageService.getCurrentUser();
    final role = widget.storageService.getCurrentUserRole();
    final isSuperAdmin = widget.storageService.isSuperAdmin();
    final isViewOnly = widget.storageService.isViewOnlyMode();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Re-Organized Clean User Header Card (Zero Overflow on Any Screen)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSuperAdmin ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.cyan.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSuperAdmin ? Colors.amberAccent : Colors.cyanAccent,
                      child: Icon(
                        isSuperAdmin ? Icons.shield_rounded : Icons.person_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentUser,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSuperAdmin
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : (isViewOnly ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.cyan.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSuperAdmin ? Colors.amberAccent : Colors.cyanAccent,
                                  ),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    color: isSuperAdmin ? Colors.amberAccent : Colors.cyanAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSuperAdmin
                                ? 'Super Admin (Audit Logs & Security Enabled)'
                                : (isViewOnly ? 'Guest Mode (Read-Only)' : 'Club Member (Full Edit Access)'),
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Logout',
                      onPressed: widget.onLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clean Modern Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.cyanAccent,
            indicatorWeight: 2.5,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: [
              const Tab(icon: Icon(Icons.vpn_key_rounded, size: 18), text: 'Access Codes'),
              const Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Security'),
              if (isSuperAdmin) const Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 18), text: 'Admin Console'),
            ],
          ),

          // Tab Body Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAccessCodesTab(),
                _buildSecuritySettingsTab(),
                if (isSuperAdmin) _buildAdminConsoleTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Access Codes
  Widget _buildAccessCodesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title & + Button (Wrapped / Fitted to never overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Access Codes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              ElevatedButton.icon(
                onPressed: _showGenerateCodeDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('NEW CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Share "View Only" codes for guests or "Edit" codes for active members.',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 12),

          if (_accessCodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('No custom codes generated yet. Tap "+ NEW CODE" to create one.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ..._accessCodes.map((code) {
              final isEdit = code.isEdit;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isEdit ? Colors.amber.withValues(alpha: 0.4) : Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code.code,
                        style: TextStyle(
                          color: isEdit ? Colors.amberAccent : Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isEdit ? Colors.amber.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEdit ? 'EDIT ACCESS' : 'VIEW ONLY',
                              style: TextStyle(
                                color: isEdit ? Colors.amberAccent : Colors.cyanAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('By ${code.createdBy}', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // TAB 2: Security & Inventory Management
  Widget _buildSecuritySettingsTab() {
    final inventories = widget.storageService.getInventories();
    final allProducts = widget.storageService.getProducts();
    final isViewOnly = widget.storageService.isViewOnlyMode();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Master Passcode
          const Text('Master Passcode & Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Update the primary shared lab passcode for the robotics club.',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SettingsDialog(storageService: widget.storageService),
              );
            },
            icon: const Icon(Icons.lock_reset_rounded, size: 16),
            label: const Text('CHANGE MASTER PASSCODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          // Section 2: Manage Inventory Collections (Delete / Inspect)
          Row(
            children: const [
              Icon(Icons.inventory_2_rounded, color: Colors.cyanAccent, size: 18),
              SizedBox(width: 6),
              Text('Inventory Groups Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Manage and delete inventory repositories and their associated components.',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 12),

          if (inventories.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: const Text('No inventory collections created yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...inventories.map((inv) {
              final count = allProducts.where((p) => p.inventoryId == inv.id).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
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
                            '$count items • ${inv.description.isNotEmpty ? inv.description : "No description"}',
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text('Delete Inventory Group?', style: TextStyle(color: Colors.white, fontSize: 16)),
                              content: Text(
                                'Are you sure you want to delete "${inv.name}" and all its $count components?',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  child: const Text('DELETE'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await widget.storageService.deleteInventory(inv.id);
                            _loadData();
                          }
                        },
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // TAB 3: Admin Console (For Super Admin)
  Widget _buildAdminConsoleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: User Management
          Row(
            children: const [
              Icon(Icons.manage_accounts_rounded, color: Colors.amberAccent, size: 18),
              SizedBox(width: 6),
              Text('User Accounts Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text('View and remove registered user accounts.', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          const SizedBox(height: 10),

          if (_users.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: const Text('No registered member accounts yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ..._users.map((u) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${u.username} (${u.role})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(u.email, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                      tooltip: 'Remove User',
                      onPressed: () => _deleteUser(u.username),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          // Section 2: Audit Logs
          Row(
            children: const [
              Icon(Icons.history_toggle_off_rounded, color: Colors.amberAccent, size: 18),
              SizedBox(width: 6),
              Text('Security & Activity Audit Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Live audit recording of password updates, edit-code creations, and item edits.',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 10),

          if (_auditLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: const Text('No activity logged yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ..._auditLogs.map((log) {
              final isAlert = log.isAlert;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isAlert ? Colors.amberAccent.withValues(alpha: 0.6) : Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isAlert ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      color: isAlert ? Colors.amberAccent : Colors.cyanAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(log.action, style: TextStyle(color: isAlert ? Colors.amberAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(
                                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(log.details, style: TextStyle(color: Colors.grey[300], fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('Actor: ${log.actor}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
