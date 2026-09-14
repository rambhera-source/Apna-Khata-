import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _allInventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  String _selectedStockFilter = 'All'; // 'All', 'Fresh', 'Replacement'

  // A to Z Price Tiers List
  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    _allInventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _filterItems(_searchController.text);
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _allInventoryItems.where((item) {
        bool matchesQuery = item.itemName.toLowerCase().contains(query.toLowerCase()) ||
                            (item.sku != null && item.sku!.toLowerCase().contains(query.toLowerCase()));
        
        bool matchesStockType = true;
        if (_selectedStockFilter == 'Fresh') {
          matchesStockType = item.stockType == 'Fresh' || item.stockType == null || item.stockType!.isEmpty;
        } else if (_selectedStockFilter == 'Replacement') {
          matchesStockType = item.stockType == 'Replacement';
        }

        return matchesQuery && matchesStockType;
      }).toList();
    });
  }

  // 📥 1. Enhanced Template CSV Generator (With Unique Constraints, Categories & A-Z Tiers)
  Future<void> _downloadTemplateFile() async {
    try {
      List<List<dynamic>> rows = [];
      
      Set<String> uniqueCategories = _allInventoryItems
          .map((item) => item.category ?? '')
          .where((cat) => cat.trim().isNotEmpty)
          .toSet();
      
      String availableCategoriesStr = uniqueCategories.isNotEmpty ? uniqueCategories.join(', ') : 'General, Charger, Power Bank';

      List<dynamic> headers = [
        'Product Name (Mandatory & Unique)',
        'SKU ID (Mandatory & Unique)',
        'Category [Available: $availableCategoriesStr]',
        'Purchase Price (₹)',
        'Opening Stock',
        'Closing Stock'
      ];
      
      for (var tier in _priceCategories) {
        headers.add('Price Tier $tier (₹)');
      }
      
      rows.add(headers);

      if (_allInventoryItems.isNotEmpty) {
        for (var item in _allInventoryItems) {
          List<dynamic> rowData = [
            item.itemName,
            item.sku ?? '',
            item.category ?? 'General',
            item.purchasePrice,
            item.openingStock ?? 0,
            item.stockQuantity,
          ];
          for (var tier in _priceCategories) {
            if (tier == (item.priceCategory ?? 'A')) {
              rowData.add(item.priceA);
            } else {
              rowData.add(0.0);
            }
          }
          rows.add(rowData);
        }
      } else {
        List<dynamic> sample1 = ['ORLIFE 85W Cable', 'CAB-85W', 'Charger', 100, 10, 50];
        for (var tier in _priceCategories) {
          sample1.add(tier == 'A' ? 150 : 0);
        }
        rows.add(sample1);

        List<dynamic> sample2 = ['ORLIFE Power Bank', 'PB-10K', 'Power Bank', 650, 5, 20];
        for (var tier in _priceCategories) {
          sample2.add(tier == 'B' ? 899 : 0);
        }
        rows.add(sample2);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/orlife_inventory_advanced_template.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Advanced Inventory CSV Template with Unique SKU/Name validations & A-Z Tiers from ORLIFE ERP.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template generate karne me error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📂 2. CSV File Import Function with Unique Validation
  Future<void> _importCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final input = File(filePath).openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File खाली है!'), backgroundColor: Colors.red),
          );
          return;
        }

        int successCount = 0;
        int duplicateCount = 0;

        await DatabaseHelper.isar.writeTxn(() async {
          for (int i = 1; i < fields.length; i++) {
            var row = fields[i];
            if (row.isNotEmpty && row[0].toString().trim().isNotEmpty) {
              String name = row[0].toString().trim();
              String sku = row.length > 1 ? row[1].toString().trim() : '';

              bool exists = _allInventoryItems.any((item) => 
                item.itemName.toLowerCase() == name.toLowerCase() || 
                (sku.isNotEmpty && item.sku != null && item.sku!.toLowerCase() == sku.toLowerCase())
              );

              if (exists) {
                duplicateCount++;
                continue;
              }

              String category = row.length > 2 ? row[2].toString().trim() : 'General';
              double purchasePrice = row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0;
              double openingStock = row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0;
              double closingStock = row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0;

              double priceA = row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0;
              String selectedTier = 'A';

              for (int t = 0; t < _priceCategories.length; t++) {
                int colIdx = 6 + t;
                if (row.length > colIdx) {
                  double tierVal = double.tryParse(row[colIdx].toString()) ?? 0.0;
                  if (tierVal > 0) {
                    priceA = tierVal;
                    selectedTier = _priceCategories[t];
                    break;
                  }
                }
              }

              InventoryItem item = InventoryItem()
                ..itemName = name
                ..sku = sku
                ..category = category.isEmpty ? 'General' : category
                ..purchasePrice = purchasePrice
                ..openingStock = openingStock
                ..stockQuantity = closingStock
                ..priceA = priceA
                ..priceCategory = selectedTier
                ..stockType = 'Fresh';

              await DatabaseHelper.isar.inventoryItems.put(item);
              successCount++;
            }
          }
        });

        if (!mounted) return;
        _loadInventory();
        
        String msg = 'सफलतापूर्वक $successCount प्रोडक्ट्स इम्पोर्ट हो गए!';
        if (duplicateCount > 0) {
          msg += ' ($duplicateCount डुप्लीकेट प्रोडक्ट्स छोड़ दिए गए)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: duplicateCount > 0 ? Colors.orange.shade800 : Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('इम्पोर्ट करने में एरर आया: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ➕ Add or Edit Product Dialog (Stock Type selector removed)
  void _showAddEditProductDialog({InventoryItem? itemToEdit}) {
    final TextEditingController nameController = TextEditingController(text: itemToEdit?.itemName ?? '');
    final TextEditingController skuController = TextEditingController(text: itemToEdit?.sku ?? '');
    final TextEditingController openingStockController = TextEditingController(text: itemToEdit?.openingStock?.toString() ?? '0');
    final TextEditingController qtyController = TextEditingController(text: itemToEdit?.stockQuantity.toString() ?? '0');
    final TextEditingController purchasePriceController = TextEditingController(text: itemToEdit?.purchasePrice.toString() ?? '0');
    
    final TextEditingController tierPriceController = TextEditingController(text: itemToEdit?.priceA.toString() ?? '0');
    
    Set<String> uniqueCategories = _allInventoryItems
        .map((item) => item.category ?? '')
        .where((cat) => cat.trim().isNotEmpty)
        .toSet();
    if (uniqueCategories.isEmpty) uniqueCategories = {'General', 'Charger', 'Power Bank'};

    String selectedCategory = itemToEdit?.category ?? uniqueCategories.first;
    if (!uniqueCategories.contains(selectedCategory)) {
      uniqueCategories.add(selectedCategory);
    }

    String priceCategory = itemToEdit?.priceCategory ?? 'A';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(itemToEdit == null ? 'Add New Inventory Item' : 'Edit Item Details'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Product Name (Mandatory & Unique) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: skuController,
                    decoration: const InputDecoration(labelText: 'SKU ID (Mandatory & Unique) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: uniqueCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategory = val ?? 'General'),
                    decoration: const InputDecoration(labelText: 'Product Category', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: openingStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Closing Qty *', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: purchasePriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase Price (₹)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _priceCategories.contains(priceCategory) ? priceCategory : 'A',
                          items: _priceCategories.map((cat) => DropdownMenuItem(value: cat, child: Text('Tier $cat'))).toList(),
                          onChanged: (val) => setDialogState(() => priceCategory = val ?? 'A'),
                          decoration: const InputDecoration(labelText: 'Price Tier', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: tierPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Tier $priceCategory Price (₹) *', border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                String name = nameController.text.trim();
                String sku = skuController.text.trim();

                if (name.isEmpty || sku.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product Name aur SKU ID dono mandatory hain!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                bool isDuplicate = _allInventoryItems.any((item) => 
                  (itemToEdit == null || item.id != itemToEdit.id) && 
                  (item.itemName.toLowerCase() == name.toLowerCase() || 
                   (sku.isNotEmpty && item.sku != null && item.sku!.toLowerCase() == sku.toLowerCase()))
                );

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeh Product Name ya SKU ID pehle से मौजूद है! Unique value bharein.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                await DatabaseHelper.isar.writeTxn(() async {
                  InventoryItem item = itemToEdit ?? InventoryItem();
                  item.itemName = name;
                  item.sku = sku;
                  item.category = selectedCategory;
                  item.openingStock = double.tryParse(openingStockController.text) ?? 0.0;
                  item.stockQuantity = double.tryParse(qtyController.text) ?? 0.0;
                  item.purchasePrice = double.tryParse(purchasePriceController.text) ?? 0.0;
                  item.priceA = double.tryParse(tierPriceController.text) ?? 0.0;
                  item.priceCategory = priceCategory;
                  item.stockType = 'Fresh'; // Default stock type

                  await DatabaseHelper.isar.inventoryItems.put(item);
                });

                if (!mounted) return;
                Navigator.pop(context);
                _loadInventory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventory Successfully Saved!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => _showAddEditProductDialog(),
            tooltip: 'Add New Product',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Product or SKU...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    onChanged: _filterItems,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStockFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Stock')),
                      DropdownMenuItem(value: 'Fresh', child: Text('Fresh Stock')),
                      DropdownMenuItem(value: 'Replacement', child: Text('Replacement')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStockFilter = val!;
                        _filterItems(_searchController.text);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.teal),
                  onPressed: _downloadTemplateFile,
                  tooltip: 'Download Advanced CSV Template',
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload, color: Colors.teal),
                  onPressed: _importCsvFile,
                  tooltip: 'Upload CSV File (Bulk Update)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Item / Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Op / Cl Stock', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Pur / Sell Rate', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No inventory items found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                 flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('${item.category ?? "General"} | SKU: ${item.sku ?? "-"}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Text('Cl: ${item.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                                      Text('Op: ${item.openingStock ?? 0}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Text('P: ₹${item.purchasePrice.toStringAsFixed(0)} | S: ₹${item.priceA.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(3)),
                                        child: Text('Tier: ${item.priceCategory ?? "A"}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                        onPressed: () => _showAddEditProductDialog(itemToEdit: item),
                                        tooltip: 'Edit Item',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () async {
                                          await DatabaseHelper.isar.writeTxn(() async {
                                            await DatabaseHelper.isar.inventoryItems.delete(item.id);
                                          });
                                          _loadInventory();
                                        },
                                        tooltip: 'Delete Item',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
