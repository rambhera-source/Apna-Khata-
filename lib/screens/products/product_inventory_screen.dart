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
import 'add_product_screen.dart';

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

  final Set<int> _selectedItemIds = {};
  bool _isSelectAll = false;

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

      _selectedItemIds.clear();
      _isSelectAll = false;
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

  Future<bool> _hasTransactions(String itemName) async {
    final txns = await DatabaseHelper.isar.accountingTransactions
        .filter()
        .notesContains(itemName, caseSensitive: false)
        .findAll();
    return txns.isNotEmpty;
  }

  void _confirmBulkDelete() async {
    if (_selectedItemIds.isEmpty) return;

    List<InventoryItem> deletableItems = [];
    List<String> skippedItems = [];

    for (int id in _selectedItemIds) {
      final item = _allInventoryItems.firstWhere((p) => p.id == id);
      bool hasTxn = await _hasTransactions(item.itemName);
      if (hasTxn) {
        skippedItems.add(item.itemName);
      } else {
        deletableItems.add(item);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Products?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete ${deletableItems.length} selected products?', style: const TextStyle(fontSize: 13)),
            if (skippedItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Skipped: ${skippedItems.length} product(s) have existing transactions and cannot be deleted.',
                style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (deletableItems.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseHelper.isar.writeTxn(() async {
                  for (var item in deletableItems) {
                    await DatabaseHelper.isar.inventoryItems.delete(item.id);
                  }
                });
                _loadInventory();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected safe products deleted successfully!'), backgroundColor: Colors.red),
                );
              },
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(InventoryItem item) async {
    bool hasTxn = await _hasTransactions(item.itemName);

    if (!mounted) return;

    if (hasTxn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Cannot Delete Product', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text('Transaction available! "${item.itemName}" ke naam par transactions maujood hain. Aap is product को delete nahi kar sakte.', style: const TextStyle(fontSize: 13)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Product?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Delete "${item.itemName}"?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.isar.writeTxn(() async {
                await DatabaseHelper.isar.inventoryItems.delete(item.id);
              });
              _loadInventory();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedInventory() async {
    try {
      List<List<dynamic>> rows = [
        ['Product Name', 'SKU ID', 'Category', 'Purchase Price', 'Opening Stock', 'Closing Stock', 'Selling Price']
      ];

      for (var item in _filteredItems) {
        if (_selectedItemIds.isEmpty || _selectedItemIds.contains(item.id)) {
          rows.add([
            item.itemName,
            item.sku ?? '',
            item.category ?? 'General',
            item.purchasePrice,
            item.openingStock ?? 0,
            item.stockQuantity,
            item.priceA,
          ]);
        }
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Inventory_Export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Exported Inventory from ORLIFE ERP.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
      );
    }
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
        'Print Name',
        'Category [Available: $availableCategoriesStr]',
        'HSN Code',
        'Tax Rate (%)',
        'Barcode',
        'Opening Stock',
        'Closing Stock',
        'Purchase Price (₹)'
      ];
      
      for (var tier in _priceCategories) {
        headers.add('Price Tier $tier (₹)');
      }
      rows.add(headers);

      List<dynamic> sample1 = [
        'ORLIFE 85W Cable', 
        'CAB-85W', 
        'ORLIFE Cable 85W', 
        'Charger', 
        '8504', 
        18, 
        '8901234567890', 
        10, 
        50, 
        100
      ];
      for (var tier in _priceCategories) {
        sample1.add(tier == 'A' ? 150 : 0);
      }
      rows.add(sample1);

      String csvData = const ListToCsvConverter().convert(rows);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/orlife_inventory_custom_template.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Inventory CSV Template from ORLIFE ERP.');
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

            String printName = row.length > 2 ? row[2].toString().trim() : '';
            String category = row.length > 3 && row[3].toString().trim().isNotEmpty ? row[3].toString().trim() : 'General';
            String hsnCode = row.length > 4 ? row[4].toString().trim() : '';
            double taxRate = row.length > 5 ? double.tryParse(row[5].toString()) ?? 18.0 : 18.0;
            String barcode = row.length > 6 ? row[6].toString().trim() : '';
            double openingStock = row.length > 7 ? double.tryParse(row[7].toString()) ?? 0.0 : 0.0;
            double closingStock = row.length > 8 ? double.tryParse(row[8].toString()) ?? 0.0 : 0.0;
            double purchasePrice = row.length > 9 ? double.tryParse(row[9].toString()) ?? 0.0 : 0.0;

            double priceA = row.length > 10 ? double.tryParse(row[10].toString()) ?? 0.0 : 0.0;
            String selectedTier = 'A';

            for (int t = 0; t < _priceCategories.length; t++) {
              int colIdx = 10 + t;
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
              ..printName = printName.isEmpty ? null : printName
              ..category = category
              ..hsnCode = hsnCode.isEmpty ? null : hsnCode
              ..taxRate = taxRate
              ..barcode = barcode.isEmpty ? null : barcode
              ..openingStock = openingStock
              ..stockQuantity = closingStock
              ..purchasePrice = purchasePrice
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
            Text(item.itemName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            Text('SKU: ${item.sku ?? "-"} | Category: ${item.category ?? "General"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                          Text('Opening Stock: ${item.openingStock ?? 0}', style: const TextStyle(fontSize: 12)),
                          Text('Closing Stock: ${item.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Purchase ₹${item.purchasePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                          Text('Selling (Tier ${item.priceCategory ?? "A"}): ₹${item.priceA.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Transaction History (Sales, Purchase & Returns):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                transactions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('Is product ki koi transaction history nahi hai.', style: TextStyle(color: Colors.grey, fontSize: 12))),
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
                              title: Text('${txn.voucherType} - ${txn.partyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text('Bill No: ${txn.voucherNumber} | Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}', style: const TextStyle(fontSize: 10)),
                              trailing: Text('₹${txn.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
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
          if (_selectedItemIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              tooltip: 'Export Selected',
              onPressed: _exportSelectedInventory,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Delete Selected',
              onPressed: _confirmBulkDelete,
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'template') {
                _downloadTemplateFile();
              } else if (value == 'import') {
                _importFileUniversal();
              } else if (value == 'export') {
                _exportSelectedInventory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'template',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Download Template', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Import Inventory', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Export Inventory', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Search Product Name or SKU...',
                        prefixIcon: Icon(Icons.search, size: 18, color: Colors.teal),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                      onChanged: _filterItems,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: DropdownButtonFormField<String>(
                      value: _selectedStockFilter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Stock', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'Fresh', child: Text('Fresh Stock', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'Replacement', child: Text('Replacement', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedStockFilter = val!;
                          _filterItems(_searchController.text);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(color: Colors.teal.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.date_range, size: 14, color: Colors.teal),
                      label: Text(
                        _startDate == null || _endDate == null
                            ? 'Filter by Date Range'
                            : '${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}',
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                      onPressed: _selectDateRange,
                    ),
                  ),
                ),
                if (_startDate != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _filterItems(_searchController.text);
                      });
                    },
                    tooltip: 'Clear Date Filter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'All') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtered by Category: $_selectedCategoryFilter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryFilter = null;
                          _filterItems(_searchController.text);
                        });
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Checkbox(
                    value: _isSelectAll,
                    activeColor: Colors.teal,
                    visualDensity: VisualDensity.compact,
                    onChanged: (bool? value) {
                      setState(() {
                        _isSelectAll = value ?? false;
                        if (_isSelectAll) {
                          _selectedItemIds.addAll(_filteredItems.map((item) => item.id));
                        } else {
                          _selectedItemIds.clear();
                        }
                      });
                    },
                  ),
                  const Text('All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                  const SizedBox(width: 10),
                  const Expanded(flex: 3, child: Text('Product Name / SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () {
                        Set<String> categories = _allInventoryItems
                            .map((item) => item.category ?? 'General')
                            .where((cat) => cat.trim().isNotEmpty)
                            .toSet();
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Filter by Category', style: TextStyle(fontSize: 15)),
                            content: SizedBox(
                              width: 280,
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  ListTile(
                                    title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                        title: Text(cat, style: const TextStyle(fontSize: 12)),
                                        trailing: _selectedCategoryFilter == cat ? const Icon(Icons.check, color: Colors.teal, size: 16) : null,
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
                          ),
                        );
                      },
                      child: Row(
                        children: const [
                          Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                          Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
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
                          const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                          Icon(_isStockAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: Colors.teal),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No inventory items found.', style: TextStyle(color: Colors.grey, fontSize: 13)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        bool isSelected = _selectedItemIds.contains(item.id);

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddProductScreen(itemToEdit: item),
                                ),
                              );
                              _loadInventory();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.teal,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItemIds.add(item.id);
                                        } else {
                                          _selectedItemIds.remove(item.id);
                                          _isSelectAll = false;
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'SKU: ${item.sku ?? "-"}',
                                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.category ?? "General",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.stockQuantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                    tooltip: 'Delete Product',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () => _confirmDelete(item),
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
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
          _loadInventory();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
