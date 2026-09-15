import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/models/transaction_model.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _allInventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  
  String _selectedStockFilter = 'Fresh'; 
  String? _selectedCategoryFilter; 
  bool _isStockAscending = true; 

  DateTime? _startDate;
  DateTime? _endDate;

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

        bool matchesCategory = true;
        if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'All') {
          matchesCategory = (item.category ?? 'General') == _selectedCategoryFilter;
        }

        return matchesQuery && matchesStockType && matchesCategory;
      }).toList();

      _filteredItems.sort((a, b) {
        if (_isStockAscending) {
          return a.stockQuantity.compareTo(b.stockQuantity);
        } else {
          return b.stockQuantity.compareTo(a.stockQuantity);
        }
      });
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterItems(_searchController.text);
      });
    }
  }

  void _toggleStockSorting() {
    setState(() {
      _isStockAscending = !_isStockAscending;
      _filterItems(_searchController.text);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isStockAscending ? 'Sorted: Low Stock to High Stock' : 'Sorted: High Stock to Low Stock'),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _showCategoryFilterDialog() {
    Set<String> categories = _allInventoryItems
        .map((item) => item.category ?? 'General')
        .where((cat) => cat.trim().isNotEmpty)
        .toSet();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  setState(() {
                    _selectedCategoryFilter = null;
                    _filterItems(_searchController.text);
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...categories.map((cat) => ListTile(
                    title: Text(cat),
                    trailing: _selectedCategoryFilter == cat ? const Icon(Icons.check, color: Colors.teal) : null,
                    onTap: () {
                      setState(() {
                        _selectedCategoryFilter = cat;
                        _filterItems(_searchController.text);
                      });
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

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
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/orlife_inventory_advanced_template.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Advanced Inventory CSV Template from ORLIFE ERP.');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template generate karne me error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importFileUniversal() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        List<List<dynamic>> rows = [];

        String extension = file.extension?.toLowerCase() ?? '';
        if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls') || extension == 'xlsx' || extension == 'xls') {
          var bytes = file.bytes ?? await File(file.path!).readAsBytes();
          var excelFile = excel_pkg.Excel.decodeBytes(bytes);
          for (var table in excelFile.tables.keys) {
            var sheet = excelFile.tables[table];
            if (sheet != null) {
              for (var row in sheet.rows) {
                rows.add(row.map((cell) => cell?.value ?? '').toList());
              }
            }
            break;
          }
        } else {
          String csvString = '';
          if (file.bytes != null) {
            csvString = utf8.decode(file.bytes!, allowMalformed: true);
          } else if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();
            csvString = utf8.decode(bytes, allowMalformed: true);
          }
          rows = const CsvToListConverter().convert(csvString);
        }

        if (rows.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file is empty or invalid!'), backgroundColor: Colors.orange),
          );
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Processing & Importing Inventory...'),
              ],
            ),
          ),
        );

        int successCount = 0;
        List<List<dynamic>> failedRows = [];
        if (rows.isNotEmpty) {
          List<dynamic> header = List.from(rows[0]);
          header.add('Failure Reason');
          failedRows.add(header);
        }

        await DatabaseHelper.isar.writeTxn(() async {
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length < 2 || row[0].toString().trim().isEmpty) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Insufficient columns or empty Product Name');
              failedRows.add(failedRow);
              continue;
            }

            String name = row[0].toString().trim();
            String sku = row.length > 1 ? row[1].toString().trim() : '';

            if (name.isEmpty || sku.isEmpty) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Product Name or SKU ID is missing');
              failedRows.add(failedRow);
              continue;
            }

            bool exists = _allInventoryItems.any((item) => 
              item.itemName.toLowerCase() == name.toLowerCase() || 
              (sku.isNotEmpty && item.sku != null && item.sku!.toLowerCase() == sku.toLowerCase())
            );

            if (exists) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Duplicate Product Name or SKU already exists');
              failedRows.add(failedRow);
              continue;
            }

            String category = row.length > 2 && row[2].toString().trim().isNotEmpty ? row[2].toString().trim() : 'General';
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
              ..category = category
              ..purchasePrice = purchasePrice
              ..openingStock = openingStock
              ..stockQuantity = closingStock
              ..priceA = priceA
              ..priceCategory = selectedTier
              ..stockType = 'Fresh';

            await DatabaseHelper.isar.inventoryItems.put(item);
            successCount++;
          }
        });

        if (!mounted) return;
        Navigator.pop(context);
        _loadInventory();

        String? errorFilePath;
        if (failedRows.length > 1) {
          String errorCsvData = const ListToCsvConverter().convert(failedRows);
          final output = await getTemporaryDirectory();
          final errFile = File('${output.path}/Failed_Inventory_Report.csv');
          await errFile.writeAsString(errorCsvData);
          errorFilePath = errFile.path;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Import Summary'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successfully Imported: $successCount items', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('❌ Failed / Skipped: ${failedRows.length > 1 ? failedRows.length - 1 : 0} items', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                if (errorFilePath != null) ...[
                  const SizedBox(height: 12),
                  const Text('Kuch records duplicate ya invalid hone ki wajah se fail ho gaye hain. Aap failure report download kar sakte hain.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              if (errorFilePath != null)
                TextButton.icon(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text('Download Error Report'),
                  onPressed: () {
                    Share.shareXFiles([XFile(errorFilePath!)], text: 'Yeh Inventory Bulk Import ki Failed Report hai.');
                  },
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File import karne me error aayi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showProductHistoryDialog(InventoryItem item) async {
    final transactions = await DatabaseHelper.isar.accountingTransactions
        .filter()
        .notesContains(item.itemName, caseSensitive: false)
        .findAll();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
            Text('SKU: ${item.sku ?? "-"} | Category: ${item.category ?? "General"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Opening Stock: ${item.openingStock ?? 0}'),
                          Text('Closing Stock: ${item.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Purchase ₹${item.purchasePrice.toStringAsFixed(0)}'),
                          Text('Selling (Tier ${item.priceCategory ?? "A"}): ₹${item.priceA.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Transaction History (Sales, Purchase & Returns):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                transactions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('Is product ki koi transaction history nahi hai.', style: TextStyle(color: Colors.grey))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final txn = transactions[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text('${txn.voucherType} - ${txn.partyName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Bill No: ${txn.voucherNumber} | Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}'),
                              trailing: Text('₹${txn.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

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
                    const SnackBar(content: Text('Yeh Product Name ya SKU ID pehle se मौजूद है!'), backgroundColor: Colors.red),
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
                  item.stockType = 'Fresh';

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
                  tooltip: 'Download Template',
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload, color: Colors.teal),
                  onPressed: _importFileUniversal,
                  tooltip: 'Upload Excel or CSV File',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: Colors.teal.shade300),
                    ),
                    icon: const Icon(Icons.date_range, size: 16, color: Colors.teal),
                    label: Text(
                      _startDate == null || _endDate == null
                          ? 'Filter by Date Range'
                          : '${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    onPressed: _selectDateRange,
                  ),
                ),
                if (_startDate != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _filterItems(_searchController.text);
                      });
                    },
                    tooltip: 'Clear Date Filter',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'All') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtered by Category: $_selectedCategoryFilter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryFilter = null;
                          _filterItems(_searchController.text);
                        });
                      },
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.shade100,
              child: Row(
                children: [
                  const SizedBox(width: 35, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal))),
                  const Expanded(flex: 3, child: Text('Product Name / SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _showCategoryFilterDialog,
                      child: Row(
                        children: const [
                          Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: _toggleStockSorting,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Cl. Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          Icon(_isStockAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: Colors.teal),
                        ],
                      ),
                    ),
                  ),
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
                          child: InkWell(
                            onTap: () => _showProductHistoryDialog(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 35,
                                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                                        const SizedBox(height: 2),
                                        Text('SKU: ${item.sku ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryFilter = item.category ?? 'General';
                                          _filterItems(_searchController.text);
                                        });
                                      },
                                      child: Text(
                                        item.category ?? "General",
                                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, decoration: TextDecoration.underline),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.stockQuantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
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
