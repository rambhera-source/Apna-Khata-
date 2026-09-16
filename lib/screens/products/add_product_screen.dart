import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/models/settings_model.dart';

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

  List<String> _flattenedCategories = [];
  String? _selectedCategory;

  List<double> _availableTaxSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];
  double _selectedTaxRate = 18.0;

  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));
  String _selectedPriceTier = 'A';

  @override
  void initState() {
    super.initState();
    _loadMastersAndEditData();
  }

  // 🔥 Database से Categories और Tax Slabs को लोड करना
  Future<void> _loadMastersAndEditData() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    List<String> loadedFlatCats = [];
    List<double> loadedTaxes = [0.0, 5.0, 12.0, 18.0, 28.0];

    if (settings != null) {
      if (settings.productCategories.isNotEmpty) {
        for (var catStr in settings.productCategories) {
          try {
            var decoded = jsonDecode(catStr);
            if (decoded is Map) {
              String mainCat = decoded['main'] ?? 'General';
              List<String> subs = List<String>.from(decoded['subs'] ?? []);
              if (subs.isEmpty) {
                loadedFlatCats.add(mainCat);
              } else {
                for (var sub in subs) {
                  loadedFlatCats.add('$mainCat > $sub');
                }
              }
            }
          } catch (_) {
            if (!loadedFlatCats.contains(catStr)) {
              loadedFlatCats.add(catStr);
            }
          }
        }
      }
      if (settings.taxSlabs.isNotEmpty) {
        loadedTaxes = List<double>.from(settings.taxSlabs);
      }
    }

    if (loadedFlatCats.isEmpty) {
      loadedFlatCats = [
        'Accessories > Chargers',
        'Accessories > Cables',
        'Accessories > Power Banks',
        'Spare Parts > Batteries',
        'Spare Parts > Displays',
      ];
    }

    setState(() {
      _flattenedCategories = loadedFlatCats;
      _availableTaxSlabs = loadedTaxes;

      if (widget.itemToEdit != null) {
        final item = widget.itemToEdit!;
        _nameController.text = item.itemName;
        _skuController.text = item.sku ?? '';
        _hsnController.text = item.hsnCode ?? '';
        _taxController.text = (item.taxRate ?? 18.0).toString();
        _selectedTaxRate = item.taxRate ?? 18.0;
        _barcodeController.text = item.barcode ?? '';
        _printNameController.text = item.printName ?? '';
        _openingStockController.text = (item.openingStock ?? 0).toString();
        _closingStockController.text = item.stockQuantity.toString();
        _purchasePriceController.text = item.purchasePrice.toString();
        _selectedPriceTier = item.priceCategory ?? 'A';
        _tierPriceController.text = item.priceA.toString();

        String itemCat = item.category ?? 'Accessories > Chargers';
        if (_flattenedCategories.contains(itemCat)) {
          _selectedCategory = itemCat;
        } else {
          _flattenedCategories.add(itemCat);
          _selectedCategory = itemCat;
        }
      } else {
        _selectedCategory = _flattenedCategories.isNotEmpty ? _flattenedCategories.first : null;
      }
    });
  }

  Future<void> _saveMasterSettingsToDb() async {
    Map<String, List<String>> tempMap = {};
    for (var cat in _flattenedCategories) {
      if (cat.contains(' > ')) {
        var parts = cat.split(' > ');
        String main = parts[0];
        String sub = parts[1];
        if (!tempMap.containsKey(main)) tempMap[main] = [];
        if (!tempMap[main]!.contains(sub)) tempMap[main]!.add(sub);
      } else {
        if (!tempMap.containsKey(cat)) tempMap[cat] = [];
      }
    }

    List<String> encodedCategories = tempMap.entries.map((entry) {
      return jsonEncode({'main': entry.key, 'subs': entry.value});
    }).toList();

    final settings = await DatabaseHelper.isar.companySettings.where().findFirst() ?? CompanySettings();
    await DatabaseHelper.isar.writeTxn(() async {
      settings.productCategories = encodedCategories;
      settings.taxSlabs = _availableTaxSlabs;
      await DatabaseHelper.isar.companySettings.put(settings);
    });
  }

  // Quick Add Category Dialog inside Product Screen
  void _showQuickAddCategoryDialog() {
    final mainController = TextEditingController();
    final subController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mainController,
              decoration: const InputDecoration(labelText: 'Main Category (e.g. Accessories)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subController,
              decoration: const InputDecoration(labelText: 'Sub-Category (e.g. Chargers)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              String main = mainController.text.trim();
              String sub = subController.text.trim();
              if (main.isNotEmpty) {
                String fullCategory = sub.isNotEmpty ? '$main > $sub' : main;
                setState(() {
                  if (!_flattenedCategories.contains(fullCategory)) {
                    _flattenedCategories.add(fullCategory);
                    _flattenedCategories.sort();
                  }
                  _selectedCategory = fullCategory;
                });
                _saveMasterSettingsToDb();
              }
              Navigator.pop(context);
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddTaxDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tax Slab (%)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tax Percentage e.g. 12', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              double? val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                setState(() {
                  if (!_availableTaxSlabs.contains(val)) {
                    _availableTaxSlabs.add(val);
                    _availableTaxSlabs.sort();
                  }
                  _selectedTaxRate = val;
                  _taxController.text = val.toString();
                });
                _saveMasterSettingsToDb();
              }
              Navigator.pop(context);
            },
            child: const Text('Save & Select'),
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
        const SnackBar(content: Text('Yeh Product Name ya SKU ID pehle से मौजूद है!'), backgroundColor: Colors.red),
      );
      return;
    }

    String finalCategory = _selectedCategory ?? 'General > General';

    await DatabaseHelper.isar.writeTxn(() async {
      InventoryItem item = widget.itemToEdit ?? InventoryItem();
      item.itemName = name;
      item.sku = sku;
      item.hsnCode = _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim();
      item.taxRate = double.tryParse(_taxController.text) ?? _selectedTaxRate;
      item.barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
      item.printName = _printNameController.text.trim().isEmpty ? null : _printNameController.text.trim();
      item.category = finalCategory;
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
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _flattenedCategories;
                        }
                        return _flattenedCategories.where((cat) =>
                          cat.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      displayStringForOption: (String option) => option,
                      onSelected: (String selection) {
                        setState(() {
                          _selectedCategory = selection;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (_selectedCategory != null && controller.text.isEmpty) {
                          controller.text = _selectedCategory!;
                        }
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category (Search or Select)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.teal, size: 32),
                    onPressed: _showQuickAddCategoryDialog,
                    tooltip: 'Add New Category',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      value: _availableTaxSlabs.contains(_selectedTaxRate) ? _selectedTaxRate : 18.0,
                      items: _availableTaxSlabs.map((tax) => DropdownMenuItem(value: tax, child: Text('$tax% GST', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTaxRate = val ?? 18.0;
                          _taxController.text = _selectedTaxRate.toString();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Tax Rate (%)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 28),
                    onPressed: _showQuickAddTaxDialog,
                    tooltip: 'Add Tax Slab',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
