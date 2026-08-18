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
    'Mechanical & Hardware',
    'Tools & Accessories',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selection error: $e')),
      );
    }
  }

  void _handleSave() {
    setState(() {
      _nameError = null;
      _qtyError = null;
    });

    // Compulsory field validation: Name and Quantity
    final name = _nameController.text.trim();
    final qtyText = _qtyController.text.trim();

    bool isValid = true;
    if (name.isEmpty) {
      setState(() => _nameError = 'Product name is COMPULSORY');
      isValid = false;
    }

    final qty = int.tryParse(qtyText);
    if (qty == null || qty < 0) {
      setState(() => _qtyError = 'Valid quantity integer is COMPULSORY');
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

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit_note : Icons.add_box_rounded, color: Colors.cyanAccent),
          const SizedBox(width: 10),
          Text(
            isEditing ? 'Edit Component / Product' : 'Add New Component / Product',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: Product Name and Quantity are compulsory fields.',
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Inventory Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedInventoryId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Inventory Group',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: widget.inventories
                    .map((inv) => DropdownMenuItem(
                          value: inv.id,
                          child: Text(inv.name),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedInventoryId = val);
                },
              ),
              const SizedBox(height: 14),

              // COMPULSORY 1: Product Name
              TextField(
                controller: _nameController,
                autofocus: !isEditing,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Product / Component Name * (Compulsory)',
                  labelStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  hintText: 'e.g. ESP32 Module / Stepper Motor / LiPo Battery',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  errorText: _nameError,
                  prefixIcon: const Icon(Icons.inventory_2, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // COMPULSORY 2 & OPTIONAL COST
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Quantity * (Compulsory)',
                        labelStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        errorText: _qtyError,
                        prefixIcon: const Icon(Icons.numbers, color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Cost per Unit (₹) (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // OPTIONAL: Subcategory & Company
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _subcategoryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Subcategory (Optional)',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.category, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _commonCategories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ActionChip(
                                  label: Text(cat, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  backgroundColor: const Color(0xFF0F172A),
                                  onPressed: () {
                                    setState(() => _subcategoryController.text = cat);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // OPTIONAL: Company & Location
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _companyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Company / Manufacturer (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.business, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Location / Bin (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.place, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // DATASHEET SECTION (Requirement #8)
              const Text(
                'Component Datasheet (PDF or Link)',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Web Link / URL'),
                          selected: _datasheetType == 'link',
                          selectedColor: Colors.cyanAccent,
                          labelStyle: TextStyle(
                            color: _datasheetType == 'link' ? Colors.black : Colors.white,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _datasheetType = 'link');
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('PDF Document File'),
                          selected: _datasheetType == 'file',
                          selectedColor: Colors.cyanAccent,
                          labelStyle: TextStyle(
                            color: _datasheetType == 'file' ? Colors.black : Colors.white,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _datasheetType = 'file');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_datasheetType == 'link')
                      TextField(
                        controller: _datasheetUrlController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/datasheet.pdf',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.link, color: Colors.cyanAccent, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedFileName ?? 'No PDF file selected yet',
                              style: TextStyle(
                                color: _selectedFileName != null ? Colors.cyanAccent : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickPdfFile,
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('UPLOAD PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                              foregroundColor: Colors.cyanAccent,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // OPTIONAL: Notes
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notes / Description (Optional)',
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
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.save_rounded),
          label: Text(isEditing ? 'UPDATE PRODUCT' : 'SAVE PRODUCT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
