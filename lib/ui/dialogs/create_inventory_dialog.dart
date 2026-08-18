import 'package:flutter/material.dart';
import '../../domain/models/inventory.dart';

class CreateInventoryDialog extends StatefulWidget {
  final Function(Inventory) onCreated;

  const CreateInventoryDialog({super.key, required this.onCreated});

  @override
  State<CreateInventoryDialog> createState() => _CreateInventoryDialogState();
}

class _CreateInventoryDialogState extends State<CreateInventoryDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    setState(() => _error = null);
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Inventory name is required');
      return;
    }

    final newInv = Inventory(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: desc,
      createdAt: DateTime.now(),
    );

    widget.onCreated(newInv);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      title: Row(
        children: const [
          Icon(Icons.create_new_folder_rounded, color: Colors.cyanAccent, size: 20),
          SizedBox(width: 8),
          Text(
            'Create New Inventory',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Inventory Name *',
                hintText: 'e.g. Drone Team / Robotics Lab',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Purpose of this inventory...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        ElevatedButton.icon(
          onPressed: _handleCreate,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
