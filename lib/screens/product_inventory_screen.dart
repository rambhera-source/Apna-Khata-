import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  // 📝 Controllers for Adding Single Product
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController(text: 'Pcs');
  final _priceAController = TextEditingController(); // Purchase / Tier A price
  
  String _selectedStockType = 'Fresh'; // 'Fresh' ya 'Replacement'
  bool _isImporting = false;

  // 🔍 Filters for Inventory List
  String _searchQuery = '';
  final Set<String> _selectedCategories = {};
  String _stockTypeFilter = 'All';

  // 💾 Save Single Product to Isar Database
  Future<void> _saveProduct() async {
    if (_nameController.text.trim().isEmpty || _skuController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product Name aur SKU bharna zaroori hai!')),
      );
      return;
    }

    final newItem = InventoryItem()
      ..itemName = _nameController.text.trim()
      ..sku = _skuController.text.trim()
      ..category = _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim()
      ..stockQuantity = double.tryParse(_stockController.text) ?? 0.0
      ..unit = _unitController.text.trim()
      ..priceA = double.tryParse(_priceAController.text) ?? 0.0
      ..stockType = _selectedStockType;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.inventoryItems.put(newItem);
    });

    _nameController.clear();
    _skuController.clear();
    _categoryController.clear();
    _stockController.clear();
    _priceAController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product successfully add ho gaya!')),
    );
    FocusScope.of(context).unfocus();
  }

  // 📤 Download Sample Excel Template for Bulk Import
  Future<void> _downloadSampleTemplate() async {
    try {
      var excel = excel_lib.Excel.createExcel();
      String sheetName = 'Products_Template';
      excel.rename('Sheet1', sheetName);
      var sheet = excel[sheetName];

      List<String> headers = [
        'ItemName',
        'SKU',
        'Category',
        'OpeningStock',
        'Unit',
        ...List.generate(26, (i) => 'Price${String.fromCharCode(65 + i)}')
      ];
      sheet.appendRow(headers.map((e) => excel_lib.TextCellValue(e)).toList());

      List<String> sampleRow = [
        'ORLIFE 85W Charger',
        'ORG-CHG-85W',
        'Mobile Accessories',
        '100',
        'Pcs',
        ...List.generate(26, (i) => '150.0')
      ];
      sheet.appendRow(sampleRow.map((e) => excel_lib.TextCellValue(e)).toList());

      var fileBytes = excel.encode();
      if (fileBytes == null) return;

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample Template',
        fileName: 'Product_Import_Template.xlsx',
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(fileBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample Template successfully download ho gaya!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating template: $e')),
      );
    }
  }

  // 📥 Pick and Import Excel File directly from Inventory Screen
  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isImporting = true);

    try {
      String filePath = result.files.single.path!;
      var bytes = File(filePath).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);

      int totalRows = 0;
      int successCount = 0;

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]?.rows;
        if (rows == null || rows.length <= 1) continue;

        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty || row[0] == null) continue;
          totalRows++;

          String itemName = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          String sku = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          String category = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          double stock = double.tryParse(row.length > 3 ? row[3]?.value?.toString() ?? '0' : '0') ?? 0.0;
          String unit = row.length > 4 ? row[4]?.value?.toString().trim() ?? 'Pcs' : 'Pcs';

          if (itemName.isEmpty || sku.isEmpty) continue;

          // Check duplicate in DB
          final existingInDb = await DatabaseHelper.isar.inventoryItems
              .filter()
              .skuEqualTo(sku, caseSensitive: false)
              .findFirst();

          if (existingInDb != null) continue;

          double getPrice(int idx) {
            if (row.length > idx && row[idx]?.value != null) {
              return double.tryParse(row[idx]!.value.toString()) ?? 0.0;
            }
            return 0.0;
          }

          final newItem = InventoryItem()
            ..itemName = itemName
            ..sku = sku
            ..category = category.isEmpty ? 'General' : category
            ..stockQuantity = stock
            ..unit = unit
            ..priceA = getPrice(5)
            ..stockType = 'Fresh';

          await DatabaseHelper.isar.writeTxn(() async {
            await DatabaseHelper.isar.inventoryItems.put(newItem);
          });

          successCount++;
        }
      }

      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk Import Complete! Successfully added: $successCount items.')),
      );
    } catch (e) {
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import Failed: $e')),
      );
    }
  }

  // 🗑️ Delete Product from Database
  Future<void> _deleteProduct(InventoryItem item) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Delete Karein?'),
        content: Text('Kya aap "${item.itemName}" ko inventory se permanently delete karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.isar.writeTxn(() async {
        await DatabaseHelper.isar.inventoryItems.delete(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product delete kar diya gaya hai!')),
      );
      setState(() {});
    }
  }

  Future<List<String>> _fetchAllCategories() async {
    final allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    Set<String> categories = allProducts.map((p) => p.category).toSet();
    return categories.toList();
  }

  void _showCategoryMultiSelectDialog(List<String> allCategories) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Product Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: allCategories.isEmpty
                    ? const Text('Koi category available nahi hai.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          String category = allCategories[index];
                          bool isSelected = _selectedCategories.contains(category);
                          return CheckboxListTile(
                            title: Text(category),
                            value: isSelected,
                            activeColor: Colors.teal,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _selectedCategories.clear());
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProductHistoryBottomSheet(InventoryItem product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'History: ${product.itemName}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStockBadge('Live Current Stock', '${product.stockQuantity} ${product.unit}', Colors.teal),
                          const VerticalDivider(color: Colors.grey),
                          _buildStockBadge('Closing Stock', '${product.stockQuantity} ${product.unit}', Colors.indigo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const TabBar(
                      labelColor: Colors.teal,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      tabs: [
                        Tab(text: 'Purchases'),
                        Tab(text: 'Sales'),
                        Tab(text: 'Manufacturing'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: DefaultTabController.of(context),
                        children: [
                          _buildHistoryList(scrollController, 'Purchase', 'Sharma Electronics', 'PUR-1092', '+500 Pcs', Colors.green),
                          _buildHistoryList(scrollController, 'Sale', 'Chamunda Mobile (Jalore)', 'INV-2026-88', '-50 Pcs', Colors.red),
                          _buildHistoryList(scrollController, 'Production', 'Batch #PRD-2026-08', 'PRD-08', '+1000 Pcs', Colors.teal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockBadge(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHistoryList(ScrollController controller, String type, String party, String refNo, String qty, Color qtyColor) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(type == 'Purchase' ? Icons.arrow_downward : (type == 'Sale' ? Icons.arrow_upward : Icons.factory), color: Colors.teal),
            title: Text(party, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Ref: $refNo | Tap to view bill'),
            trailing: Text(qty, style: TextStyle(fontWeight: FontWeight.bold, color: qtyColor, fontSize: 15)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $refNo details...')));
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product & Inventory Management'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            // 📊 Bulk Import Menu Button in AppBar
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'template') _downloadSampleTemplate();
                if (val == 'import') _importExcel();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'template', child: Text('Download Excel Template')),
                const PopupMenuItem(value: 'import', child: Text('Upload & Import Excel')),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.add_box), text: 'Add Single Product'),
              Tab(icon: Icon(Icons.inventory), text: 'Inventory List & Filter'),
            ],
          ),
        ),
        body: _isImporting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 16),
                    Text('Importing Products from Excel...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  // ================= TAB 1: ADD SINGLE PRODUCT =================
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Naya Product Add Karein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU Code', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _categoryController,
                          decoration: const InputDecoration(labelText: 'Category (e.g., Chargers)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _unitController,
                                decoration: const InputDecoration(labelText: 'Unit (Pcs/Box)', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceAController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Purchase / Default Price (₹)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Fresh'),
                              selected: _selectedStockType == 'Fresh',
                              selectedColor: Colors.green.shade100,
                              onSelected: (selected) => setState(() => _selectedStockType = 'Fresh'),
                            ),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Replacement'),
                              selected: _selectedStockType == 'Replacement',
                              selectedColor: Colors.orange.shade100,
                              onSelected: (selected) => setState(() => _selectedStockType = 'Replacement'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text('Save Product', style: TextStyle(fontSize: 16)),
                          onPressed: _saveProduct,
                        ),
                      ],
                    ),
                  ),

                  // ================= TAB 2: INVENTORY LIST & FILTERS =================
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search by Product Name or SKU...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search, color: Colors.teal),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value.trim()),
                        ),
                      ),
                      FutureBuilder<List<String>>(
                        future: _fetchAllCategories(),
                        builder: (context, snapshot) {
                          final categories = snapshot.data ?? [];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: InkWell(
                              onTap: () => _showCategoryMultiSelectDialog(categories),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedCategories.isEmpty
                                            ? 'Filter by Category: All Categories Selected (Tap)'
                                            : 'Selected Categories: ${_selectedCategories.join(', ')}',
                                        style: TextStyle(
                                          color: _selectedCategories.isEmpty ? Colors.grey.shade700 : Colors.teal.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.teal),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          children: [
                            const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _stockTypeFilter == 'All',
                              selectedColor: Colors.teal.shade100,
                              onSelected: (selected) => setState(() => _stockTypeFilter = 'All'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Fresh'),
                              selected: _stockTypeFilter == 'Fresh',
                              selectedColor: Colors.green.shade100,
                              onSelected: (selected) => setState(() => _stockTypeFilter = 'Fresh'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Replacement'),
                              selected: _stockTypeFilter == 'Replacement',
                              selectedColor: Colors.orange.shade100,
                              onSelected: (selected) => setState(() => _stockTypeFilter = 'Replacement'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 10),
                      Expanded(
                        child: StreamBuilder<List<InventoryItem>>(
                          stream: DatabaseHelper.isar.inventoryItems.watch(fireImmediately: true),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text('Koi product nahi mila! Naya product add karein.', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            var products = snapshot.data!.where((item) {
                              bool matchesSearch = _searchQuery.isEmpty ||
                                  item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                  item.sku.toLowerCase().contains(_searchQuery.toLowerCase());

                              bool matchesCategory = _selectedCategories.isEmpty ||
                                  _selectedCategories.contains(item.category);

                              String itemStockType = item.stockType.isEmpty ? 'Fresh' : item.stockType;
                              bool matchesStockType = _stockTypeFilter == 'All' ||
                                  (itemStockType.toLowerCase() == _stockTypeFilter.toLowerCase());

                              return matchesSearch && matchesCategory && matchesStockType;
                            }).toList();

                            if (products.isEmpty) {
                              return const Center(
                                child: Text('Is filter ke anusaar koi product nahi mila!', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            return ListView.builder(
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final item = products[index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () => _showProductHistoryBottomSheet(item),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: item.stockType.toLowerCase() == 'replacement' ? Colors.orange.shade100 : Colors.green.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item.stockType.isEmpty ? 'Fresh' : item.stockType,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: item.stockType.toLowerCase() == 'replacement' ? Colors.orange.shade900 : Colors.green.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text('SKU: ${item.sku} | Category: ${item.category}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                                const SizedBox(height: 4),
                                                Text('Stock: ${item.stockQuantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.teal)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Delete Product',
                                            onPressed: () => _deleteProduct(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
