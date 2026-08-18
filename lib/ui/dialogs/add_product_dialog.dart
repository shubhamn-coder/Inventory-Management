import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory.dart';

class AddProductDialog extends StatefulWidget {
  final String activeInventoryId;
  final List<Inventory> inventories;
  final Product? existingProduct;
  final Function(Product) onSaved;

  const AddProductDialog({
    super.key,
    required this.activeInventoryId,
    required this.inventories,
    this.existingProduct,
    required this.onSaved,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  late String _selectedInventoryId;
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _costController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _companyController = TextEditingController();
  final _datasheetUrlController = TextEditingController();
  final _notesController = TextEditingController();

  String _datasheetType = 'link'; // 'link' or 'file'
  String? _selectedFileName;
  String? _nameError;
  String? _qtyError;

  final List<String> _commonCategories = [
    'Microcontrollers',
    'Motors & Actuators',
    'Sensors',
    'Power & Batteries',
    'Motor Drivers',
    'Wireless & RF',
    'Mechanical Parts',
  ];

  @override
  void initState() {
    super.initState();
    _selectedInventoryId = widget.activeInventoryId;

    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _selectedInventoryId = p.inventoryId;
      _nameController.text = p.name;
      _qtyController.text = p.quantity.toString();
      if (p.cost != null) _costController.text = p.cost.toString();
      if (p.subcategory != null) _subcategoryController.text = p.subcategory!;
      if (p.location != null) _locationController.text = p.location!;
      if (p.company != null) _companyController.text = p.company!;
      if (p.datasheetUrl != null) _datasheetUrlController.text = p.datasheetUrl!;
      if (p.datasheetType != null) _datasheetType = p.datasheetType!;
      if (p.datasheetName != null) _selectedFileName = p.datasheetName!;
      if (p.notes != null) _notesController.text = p.notes!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _subcategoryController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _datasheetUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        setState(() {
          _selectedFileName = file.name;
          _datasheetType = 'file';
          _datasheetUrlController.text = file.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  void _handleSave() {
    setState(() {
      _nameError = null;
      _qtyError = null;
    });

    final name = _nameController.text.trim();
    final qtyText = _qtyController.text.trim();

    bool isValid = true;
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is compulsory');
      isValid = false;
    }

    final qty = int.tryParse(qtyText);
    if (qty == null || qty < 0) {
      setState(() => _qtyError = 'Valid quantity is compulsory');
      isValid = false;
    }

    if (!isValid) return;

    final cost = double.tryParse(_costController.text.trim());
    final subcat = _subcategoryController.text.trim();
    final loc = _locationController.text.trim();
    final comp = _companyController.text.trim();
    final datasheet = _datasheetUrlController.text.trim();
    final notes = _notesController.text.trim();

    final product = Product(
      id: widget.existingProduct?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
      inventoryId: _selectedInventoryId,
      name: name,
      quantity: qty!,
      cost: cost,
      subcategory: subcat.isNotEmpty ? subcat : null,
      location: loc.isNotEmpty ? loc : null,
      company: comp.isNotEmpty ? comp : null,
      datasheetUrl: datasheet.isNotEmpty ? datasheet : null,
      datasheetType: datasheet.isNotEmpty ? _datasheetType : null,
      datasheetName: _selectedFileName ?? (datasheet.isNotEmpty ? 'Datasheet.pdf' : null),
      notes: notes.isNotEmpty ? notes : null,
      createdAt: widget.existingProduct?.createdAt ?? DateTime.now(),
    );

    widget.onSaved(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProduct != null;
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: mediaQuery.size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(
                  bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                    color: Colors.cyanAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Component' : 'Add Component',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inventory Selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedInventoryId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Inventory Group',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: widget.inventories
                          .map((inv) => DropdownMenuItem(
                                value: inv.id,
                                child: Text(inv.name, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedInventoryId = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // COMPULSORY: Product Name
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        hintText: 'e.g. Arduino Mega 2560 R3',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        errorText: _nameError,
                        errorStyle: const TextStyle(fontSize: 11),
                        prefixIcon: const Icon(Icons.inventory_2_rounded, color: Colors.cyanAccent, size: 16),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quantity & Cost (₹)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Quantity *',
                              labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              errorText: _qtyError,
                              errorStyle: const TextStyle(fontSize: 11),
                              prefixIcon: const Icon(Icons.numbers_rounded, color: Colors.cyanAccent, size: 16),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Cost / Unit (₹)',
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                              prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.greenAccent, size: 16),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Subcategory
                    TextField(
                      controller: _subcategoryController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Subcategory',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.category_rounded, color: Colors.grey, size: 16),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _commonCategories.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: ActionChip(
                              label: Text(cat, style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              onPressed: () => setState(() => _subcategoryController.text = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Company & Location
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _companyController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Company / Brand',
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                              prefixIcon: const Icon(Icons.business, color: Colors.grey, size: 15),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Location / Bin',
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                              prefixIcon: const Icon(Icons.place, color: Colors.grey, size: 15),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Datasheet (PDF or Link)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Web Link', style: TextStyle(fontSize: 10)),
                                selected: _datasheetType == 'link',
                                selectedColor: Colors.cyanAccent,
                                labelStyle: TextStyle(
                                  color: _datasheetType == 'link' ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                onSelected: (val) {
                                  if (val) setState(() => _datasheetType = 'link');
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('PDF File', style: TextStyle(fontSize: 10)),
                                selected: _datasheetType == 'file',
                                selectedColor: Colors.cyanAccent,
                                labelStyle: TextStyle(
                                  color: _datasheetType == 'file' ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                onSelected: (val) {
                                  if (val) setState(() => _datasheetType = 'file');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_datasheetType == 'link')
                            TextField(
                              controller: _datasheetUrlController,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'https://docs.example.com/datasheet.pdf',
                                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                                prefixIcon: const Icon(Icons.link, color: Colors.cyanAccent, size: 15),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedFileName ?? 'No PDF selected',
                                    style: TextStyle(
                                      color: _selectedFileName != null ? Colors.cyanAccent : Colors.grey,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  onPressed: _pickPdfFile,
                                  icon: const Icon(Icons.picture_as_pdf, size: 12),
                                  label: const Text('BROWSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                                    foregroundColor: Colors.cyanAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Notes / Description',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(
                  top: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.save_rounded, size: 14),
                    label: Text(
                      isEditing ? 'UPDATE' : 'SAVE',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
