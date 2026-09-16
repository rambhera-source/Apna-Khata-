import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';

class AddProductScreen extends StatefulWidget {
  final InventoryItem? itemToEdit;

  const AddProductScreen({super.key, this.itemToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _hsnController = TextEditingController();
  final _taxController = TextEditingController(text: '18');
  final _barcodeController = TextEditingController();
  final _printNameController = TextEditingController();
  final _openingStockController = TextEditingController(text: '0');
  final _closingStockController = TextEditingController(text: '0');
  final _purchasePriceController = TextEditingController(text: '0');
  final _tierPriceController = TextEditingController(text: '0');

  String _selectedCategory = 'General';
  List<String> _availableCategories = ['General', 'Charger', 'Power Bank', 'Cable', 'Neckband', 'Speaker'];

  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));
  String _selectedPriceTier = 'A';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeEditData();
  }

  Future<void> _loadCategories() async {
    final items = await DatabaseHelper.isar.inventoryItems.where().findAll();
    Set<String> cats = items.map((e) => e.category ?? 'General').where((c) => c.trim().isNotEmpty).toSet();
    setState(() {
      for (var c in cats) {
        if (!_availableCategories.contains(c)) {
          _availableCategories.add(c);
        }
      }
      if (widget.itemToEdit != null && widget.itemToEdit!.category != null) {
        _selectedCategory = widget.itemToEdit!.category!;
        if (!_availableCategories.contains(_selectedCategory)) {
          _availableCategories.add(_selectedCategory);
        }
      }
    });
  }

  void _initializeEditData() {
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _nameController.text = item.itemName;
      _skuController.text = item.sku ?? '';
      _hsnController.text = item.hsnCode ?? '';
      _taxController.text = (item.taxRate ?? 18.0).toString();
      _barcodeController.text = item.barcode ?? '';
      _printNameController.text = item.printName ?? '';
      _openingStockController.text = (item.openingStock ?? 0).toString();
      _closingStockController.text = item.stockQuantity.toString();
      _purchasePriceController.text = item.purchasePrice.toString();
      _selectedPriceTier = item.priceCategory ?? 'A';
      _tierPriceController.text = item.priceA.toString();
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              String newCat = controller.text.trim();
              if (newCat.isNotEmpty) {
                setState(() {
                  if (!_availableCategories.contains(newCat)) {
                    _availableCategories.add(newCat);
                  }
                  _selectedCategory = newCat;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    String name = _nameController.text.trim();
    String sku = _skuController.text.trim();

    if (name.isEmpty || sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product Name aur SKU ID dono mandatory hain!'), backgroundColor: Colors.red),
      );
      return;
    }

    final allItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
    bool isDuplicate = allItems.any((item) =>
      (widget.itemToEdit == null || item.id != widget.itemToEdit!.id) &&
      (item.itemName.toLowerCase() == name.toLowerCase() ||
       (sku.isNotEmpty && item.sku != null && item.sku!.toLowerCase() == sku.toLowerCase()))
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeh Product Name ya SKU ID pehle se मौजूद है!'), backgroundColor: Colors.red),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      InventoryItem item = widget.itemToEdit ?? InventoryItem();
      item.itemName = name;
      item.sku = sku;
      item.hsnCode = _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim();
      item.taxRate = double.tryParse(_taxController.text) ?? 18.0;
      item.barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
      item.printName = _printNameController.text.trim().isEmpty ? null : _printNameController.text.trim();
      item.category = _selectedCategory;
      item.openingStock = double.tryParse(_openingStockController.text) ?? 0.0;
      item.stockQuantity = double.tryParse(_closingStockController.text) ?? 0.0;
      item.purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
      item.priceCategory = _selectedPriceTier;
      item.priceA = double.tryParse(_tierPriceController.text) ?? 0.0;
      item.stockType = 'Fresh';

      await DatabaseHelper.isar.inventoryItems.put(item);
    });

    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product Successfully Saved!'), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _hsnController.dispose();
    _taxController.dispose();
    _barcodeController.dispose();
    _printNameController.dispose();
    _openingStockController.dispose();
    _closingStockController.dispose();
    _purchasePriceController.dispose();
    _tierPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.itemToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skuController,
                      decoration: const InputDecoration(labelText: 'SKU ID *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(labelText: 'Barcode', border: OutlineInputBorder(), prefixIcon: Icon(Icons.code)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _printNameController,
                      decoration: const InputDecoration(labelText: 'Print Name (Optional)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _hsnController,
                      decoration: const InputDecoration(labelText: 'HSN Code', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _availableCategories.contains(_selectedCategory) ? _selectedCategory : 'General',
                            items: _availableCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val ?? 'General'),
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.teal, size: 30),
                          onPressed: _showAddCategoryDialog,
                          tooltip: 'Add Category',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _taxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tax (%)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _openingStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _closingStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Closing Qty *', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _purchasePriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Purchase Price (₹)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _priceCategories.contains(_selectedPriceTier) ? _selectedPriceTier : 'A',
                      items: _priceCategories.map((cat) => DropdownMenuItem(value: cat, child: Text('Tier $cat'))).toList(),
                      onChanged: (val) => setState(() => _selectedPriceTier = val ?? 'A'),
                      decoration: const InputDecoration(labelText: 'Price Tier', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _tierPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Tier $_selectedPriceTier Price (₹) *', border: const OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saveProduct,
                  child: Text(isEditing ? 'Update Product' : 'Save Product', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
