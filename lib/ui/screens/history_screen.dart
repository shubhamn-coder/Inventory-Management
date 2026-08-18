import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/history_snapshot.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final String? activeInventoryId;

  const HistoryScreen({
    super.key,
    required this.storageService,
    this.activeInventoryId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistorySnapshot> _snapshots = [];

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  void _loadSnapshots() {
    setState(() {
      _snapshots = widget.storageService.getHistorySnapshots();
    });
  }

  void _showSaveSnapshotDialog() {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('View-only users cannot save snapshots.')),
      );
      return;
    }

    final inventories = widget.storageService.getInventories();
    final allProducts = widget.storageService.getProducts();

    if (inventories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventories available to snapshot.')),
      );
      return;
    }

    String selectedInvId = widget.activeInventoryId ?? inventories.first.id;
    final authorController = TextEditingController(text: widget.storageService.getCurrentUser());
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final targetInv = inventories.firstWhere(
            (i) => i.id == selectedInvId,
            orElse: () => inventories.first,
          );
          final invProducts = allProducts.where((p) => p.inventoryId == targetInv.id).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            title: Row(
              children: const [
                Icon(Icons.camera_alt_rounded, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text('Save Inventory Snapshot', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Record a permanent history snapshot of the inventory with author name, day, date, and exact timing.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // Inventory Selection
                  DropdownButtonFormField<String>(
                    value: selectedInvId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Select Inventory to Snapshot',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: inventories
                        .map((inv) => DropdownMenuItem(value: inv.id, child: Text(inv.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedInvId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Author Name
                  TextField(
                    controller: authorController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Author Name / Recorded By *',
                      labelStyle: const TextStyle(color: Colors.cyanAccent),
                      prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Snapshot Notes (e.g. Pre-Competition Audit)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Includes ${invProducts.length} items (${invProducts.fold<int>(0, (s, p) => s + p.quantity)} total units).',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
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
                  final author = authorController.text.trim();
                  if (author.isEmpty) return;

                  await widget.storageService.saveHistorySnapshot(
                    inventory: targetInv,
                    products: invProducts,
                    authorName: author,
                    notes: notesController.text.trim(),
                  );
                  Navigator.of(ctx).pop();
                  _loadSnapshots();
                  if (!mounted) return;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inventory snapshot saved to history!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('SAVE SNAPSHOT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewSnapshotDetails(HistorySnapshot snapshot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: Colors.cyanAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot.inventoryName,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Recorded on ${snapshot.dayOfWeek}, ${snapshot.formattedDate} at ${snapshot.formattedTime}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            Text(
              'Author: ${snapshot.authorName}',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.notes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Notes: ${snapshot.notes}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              Text(
                'Total: ${snapshot.totalProducts} Items • ${snapshot.totalQuantity} Units • ₹${snapshot.totalValue.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: snapshot.products.isEmpty
                    ? const Center(child: Text('No components were present in this inventory snapshot.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: snapshot.products.length,
                        itemBuilder: (ctx, i) {
                          final p = snapshot.products[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(
                                        '${p.company ?? "Unspecified"} • ${p.subcategory ?? "General"} • ${p.location ?? "No Location"}',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${p.quantity}x', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                                ),
                                if (p.cost != null) ...[
                                  const SizedBox(width: 8),
                                  Text('₹${(p.cost! * p.quantity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                ],
                              ],
                            ),
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
            child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _deleteSnapshot(String id) async {
    final isViewOnly = widget.storageService.isViewOnlyMode();
    if (isViewOnly) return;

    await widget.storageService.deleteHistorySnapshot(id);
    _loadSnapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isViewOnly = widget.storageService.isViewOnlyMode();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // Header Action Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: Colors.cyanAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Inventory History',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (!isViewOnly)
                          ElevatedButton.icon(
                            onPressed: _showSaveSnapshotDialog,
                            icon: const Icon(Icons.camera_alt_rounded, size: 14),
                            label: const Text('SAVE SNAPSHOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record and review historical states with author name, day, date, and exact timestamps.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Snapshots List
          _snapshots.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_outlined, size: 56, color: Colors.grey[600]),
                        const SizedBox(height: 14),
                        Text(
                          'No historical snapshots saved yet.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        if (!isViewOnly)
                          ElevatedButton.icon(
                            onPressed: _showSaveSnapshotDialog,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Record First Snapshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final snap = _snapshots[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      snap.inventoryName,
                                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _viewSnapshotDetails(snap),
                                        icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.cyanAccent),
                                        label: const Text('VIEW ITEMS', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                                      ),
                                      if (!isViewOnly)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () => _deleteSnapshot(snap.id),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Author, Day, Date, Time Information (Requirement #8)
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Saved by: ${snap.authorName}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${snap.dayOfWeek}, ${snap.formattedDate}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    snap.formattedTime,
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 4),

                              // Summary Strip
                              Row(
                                children: [
                                  Text(
                                    '${snap.totalProducts} Component Types (${snap.totalQuantity} Total Units)',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Total: ₹${snap.totalValue.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _snapshots.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
