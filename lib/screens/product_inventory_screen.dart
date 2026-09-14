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

  // 📥 1. Template CSV Generator (With A-Z Price Tier & Opening/Closing Stock)
  Future<void> _downloadTemplateFile() async {
    try {
      List<List<dynamic>> rows = [];
      
      // CSV Headers
      rows.add(['Name', 'Category', 'Opening Stock', 'Closing Stock', 'Price', 'Price Tier (A-Z)', 'SKU']);

      if (_allInventoryItems.isNotEmpty) {
        for (var item in _allInventoryItems) {
          rows.add([
            item.itemName,
            item.category ?? '',
            item.openingStock ?? 0,
            item.stockQuantity,
            item.priceA,
            item.priceCategory ?? 'A',
            item.sku ?? ''
          ]);
        }
      } else {
        rows.add(['ORLIFE 85W Cable', 'Charger', 10, 50, 150, 'A', 'CAB-85W']);
        rows.add(['ORLIFE Power Bank', 'Power Bank', 5, 20, 899, 'B', 'PB-10K']);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/inventory_template_with_tier.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Inventory CSV Template with A-Z Price Tier & Stock details from ORLIFE ERP.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template generate karne me error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📂 2. CSV File Import Function
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
        await DatabaseHelper.isar.writeTxn(() async {
          for (int i = 1; i < fields.length; i++) {
            var row = fields[i];
            if (row.isNotEmpty && row[0].toString().trim().isNotEmpty) {
              String name = row[0].toString().trim();
              String category = row.length > 1 ? row[1].toString().trim() : '';
              double openingStock = row.length > 2 ? double.tryParse(row[2].toString()) ?? 0.0 : 0.0;
              double closingStock = row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0;
              double price = row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0;
              String priceCategory = row.length > 5 ? row[5].toString().trim().toUpperCase() : 'A';
              String sku = row.length > 6 ? row[6].toString().trim() : '';

              if (!_priceCategories.contains(priceCategory)) {
                priceCategory = 'A';
              }

              InventoryItem item = InventoryItem()
                ..itemName = name
                ..category = category
                ..openingStock = openingStock
                ..stockQuantity = closingStock
                ..priceA = price
                ..priceCategory = priceCategory
                ..sku = sku
                ..stockType = 'Fresh';

              await DatabaseHelper.isar.inventoryItems.put(item);
              successCount++;
            }
          }
        });

        if (!mounted) return;
        _loadInventory();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('सफलतापूर्वक $successCount प्रोडक्ट्स इम्पोर्ट हो गए!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('इम्पोर्ट करने में एरर आया: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ➕ Add or Edit Product Dialog
  void _showAddEditProductDialog({InventoryItem? itemToEdit}) {
    final TextEditingController nameController = TextEditingController(text: itemToEdit?.itemName ?? '');
    final TextEditingController skuController = TextEditingController(text: itemToEdit?.sku ?? '');
    final TextEditingController categoryController = TextEditingController(text: itemToEdit?.category ?? '');
    final TextEditingController openingStockController = TextEditingController(text: itemToEdit?.openingStock?.toString() ?? '0');
    final TextEditingController qtyController = TextEditingController(text: itemToEdit?.stockQuantity.toString() ?? '0');
    final TextEditingController priceController = TextEditingController(text: itemToEdit?.priceA.toString() ?? '0');
    
    String stockType = itemToEdit?.stockType ?? 'Fresh';
    String priceCategory = itemToEdit?.priceCategory ?? 'A';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(itemToEdit == null ? 'Add New Inventory Item' : 'Edit Item Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU / Model Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category (Manual type or select)', border: OutlineInputBorder()),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (₹) *', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priceCategories.contains(priceCategory) ? priceCategory : 'A',
                        items: _priceCategories.map((cat) => DropdownMenuItem(value: cat, child: Text('Tier $cat'))).toList(),
                        onChanged: (val) => setDialogState(() => priceCategory = val!),
                        decoration: const InputDecoration(labelText: 'Price Tier (A-Z)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Fresh'),
                      selected: stockType == 'Fresh',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) => setDialogState(() => stockType = 'Fresh'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Replacement'),
                      selected: stockType == 'Replacement',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (val) => setDialogState(() => stockType = 'Replacement'),
                    ),
                  ],
                ),
              ],
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
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kripya Item ka Naam bharein!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                await DatabaseHelper.isar.writeTxn(() async {
                  InventoryItem item = itemToEdit ?? InventoryItem();
                  item.itemName = name;
                  item.sku = skuController.text.trim();
                  item.category = categoryController.text.trim();
                  item.openingStock = double.tryParse(openingStockController.text) ?? 0.0;
                  item.stockQuantity = double.tryParse(qtyController.text) ?? 0.0;
                  item.priceA = double.tryParse(priceController.text) ?? 0.0;
                  item.stockType = stockType;
                  item.priceCategory = priceCategory;

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

  // 📦 Bulk Entry Dialog Feature (Manual entry option)
  void _showBulkEntryDialog() {
    final List<Map<String, dynamic>> bulkRows = [
      {'name': TextEditingController(), 'category': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController(text: '0')}
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Product Entry'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ek sath kai products add karein:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bulkRows.length,
                    itemBuilder: (context, index) {
                      final row = bulkRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row['name'],
                                decoration: InputDecoration(labelText: 'Item ${index + 1} Name', border: const OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row['category'],
                                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: row['qty'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: row['price'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  bulkRows.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Row'),
                    onPressed: () {
                      setDialogState(() {
                        bulkRows.add({
                          'name': TextEditingController(),
                          'category': TextEditingController(),
                          'qty': TextEditingController(text: '1'),
                          'price': TextEditingController(text: '0'),
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                await DatabaseHelper.isar.writeTxn(() async {
                  for (var row in bulkRows) {
                    String name = (row['name'] as TextEditingController).text.trim();
                    if (name.isNotEmpty) {
                      InventoryItem item = InventoryItem()
                        ..itemName = name
                        ..category = (row['category'] as TextEditingController).text.trim()
                        ..stockQuantity = double.tryParse((row['qty'] as TextEditingController).text) ?? 0.0
                        ..priceA = double.tryParse((row['price'] as TextEditingController).text) ?? 0.0
                        ..stockType = 'Fresh'
                        ..priceCategory = 'A';
                      await DatabaseHelper.isar.inventoryItems.put(item);
                    }
                  }
                });

                if (!mounted) return;
                Navigator.pop(context);
                _loadInventory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bulk Inventory Successfully Saved!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save All'),
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
            icon: const Icon(Icons.download),
            onPressed: _downloadTemplateFile,
            tooltip: 'Download CSV Template',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importCsvFile,
            tooltip: 'Upload CSV File (Bulk Update)',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _showBulkEntryDialog,
            tooltip: 'Bulk Manual Entry',
          ),
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
            // Search Bar & Filter Row
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
              ],
            ),
            const SizedBox(height: 12),

            // Inventory List Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Item / Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Op / Cl Stock', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Rate / Tier', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
            ),

            // Inventory Items List
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No inventory items found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        bool isReplacement = item.stockType == 'Replacement';

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
                                      Text('₹${item.priceA.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
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
