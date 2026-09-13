import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  // 1. Download Sample Excel Template
  Future<void> _downloadSampleTemplate() async {
    try {
      var excel = excel_lib.Excel.createExcel();
      String sheetName = 'Products_Template';
      excel.rename('Sheet1', sheetName);
      var sheet = excel[sheetName];

      // Header Row
      List<String> headers = [
        'ItemName',
        'SKU',
        'Category',
        'OpeningStock',
        'Unit',
        ...List.generate(26, (i) => 'Price${String.fromCharCode(65 + i)}')
      ];
      sheet.appendRow(headers.map((e) => excel_lib.TextCellValue(e)).toList());

      // Sample Row
      List<String> sampleRow = [
        'ORLIFE 85W Charger',
        'ORG-CHG-85W',
        'Mobile Accessories',
        '100',
        'Pcs',
        ...List.generate(26, (i) => '150.0') // Sample prices for A-Z
      ];
      sheet.appendRow(sampleRow.map((e) => excel_lib.TextCellValue(e)).toList());

      var fileBytes = excel.encode();
      if (fileBytes == null) return;

      // Save File dialog
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

  // 2. Pick and Process Excel File for Import
  Future<void> _importAndValidateExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading Excel file...';
    });

    try {
      String filePath = result.files.single.path!;
      var bytes = File(filePath).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);

      int totalRows = 0;
      int successCount = 0;
      List<Map<String, dynamic>> failedRows = [];
      Set<String> excelSkus = {};
      Set<String> excelNames = {};

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]?.rows;
        if (rows == null || rows.length <= 1) continue; // Skip header or empty

        // Header mapping
        var headerRow = rows[0].map((e) => e?.value?.toString().trim() ?? '').toList();
        
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty || row[0] == null) continue;
          totalRows++;

          // Extract values safely based on headers or indices
          String itemName = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          String sku = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          String category = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          double stock = double.tryParse(row.length > 3 ? row[3]?.value?.toString() ?? '0' : '0') ?? 0.0;
          String unit = row.length > 4 ? row[4]?.value?.toString().trim() ?? 'Pcs' : 'Pcs';

          // Validation 1: Blank checks
          if (itemName.isEmpty || sku.isEmpty) {
            failedRows.add({
              'Row': i + 1,
              'ItemName': itemName,
              'SKU': sku,
              'Error': 'ItemName ya SKU khali nahi ho sakta!'
            });
            continue;
          }

          // Validation 2: Same Name and SKU check
          if (itemName.toLowerCase() == sku.toLowerCase()) {
            failedRows.add({
              'Row': i + 1,
              'ItemName': itemName,
              'SKU': sku,
              'Error': 'Product Name aur SKU same nahi ho sakte!'
            });
            continue;
          }

          // Validation 3: Duplicate within Excel file
          if (excelSkus.contains(sku) || excelNames.contains(itemName.toLowerCase())) {
            failedRows.add({
              'Row': i + 1,
              'ItemName': itemName,
              'SKU': sku,
              'Error': 'Duplicate SKU ya Name is Excel file ke andar hi maujood hai!'
            });
            continue;
          }

          // Validation 4: Duplicate in Isar Database
          final existingInDb = await DatabaseHelper.isar.inventoryItems
              .filter()
              .skuEqualTo(sku, caseSensitive: false)
              .or()
              .itemNameEqualTo(itemName, caseSensitive: false)
              .findFirst();

            if (existingInDb != null) {
            failedRows.add({
              'Row': i + 1,
              'ItemName': itemName,
              'SKU': sku,
              'Error': 'Database mein yeh SKU ya Product Name pehle se bana hua hai!'
            });
            continue;
          }

          // Prices A-Z mapping (Columns index 5 to 30)
          double getPrice(int idx) {
            if (row.length > idx && row[idx]?.value != null) {
              return double.tryParse(row[idx]!.value.toString()) ?? 0.0;
            }
            return 0.0;
          }

          // Create Inventory Item
          final newItem = InventoryItem()
            ..itemName = itemName
            ..sku = sku
            ..category = category.isEmpty ? 'General' : category
            ..stockQuantity = stock
            ..unit = unit
            ..priceA = getPrice(5)
            ..priceB = getPrice(6)
            ..priceC = getPrice(7)
            ..priceD = getPrice(8)
            ..priceE = getPrice(9)
            ..priceF = getPrice(10)
            ..priceG = getPrice(11)
            ..priceH = getPrice(12)
            ..priceI = getPrice(13)
            ..priceJ = getPrice(14)
            ..priceK = getPrice(15)
            ..priceL = getPrice(16)
            ..priceM = getPrice(17)
            ..priceN = getPrice(18)
            ..priceO = getPrice(19)
            ..priceP = getPrice(20)
            ..priceQ = getPrice(21)
            ..priceR = getPrice(22)
            ..priceS = getPrice(23)
            ..priceT = getPrice(24)
            ..priceU = getPrice(25)
            ..priceV = getPrice(26)
            ..priceW = getPrice(27)
            ..priceX = getPrice(28)
            ..priceY = getPrice(29)
            ..priceZ = getPrice(30);

          await DatabaseHelper.isar.writeTxn(() async {
            await DatabaseHelper.isar.inventoryItems.put(newItem);
          });

          excelSkus.add(sku);
          excelNames.add(itemName.toLowerCase());
          successCount++;
        }
      }

      setState(() => _isLoading = false);

      // Show Summary Popup
      _showImportSummaryDialog(totalRows, successCount, failedRows);

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import Failed: $e')),
      );
    }
  }

  // 3. Show Summary & Error Report Download Dialog
  void _showImportSummaryDialog(int total, int success, List<Map<String, dynamic>> failedRows) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Import Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 Total Rows Processed: $total'),
            Text('✅ Successfully Imported: $success', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            Text('❌ Failed / Skipped: ${failedRows.length}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (failedRows.isNotEmpty)
              const Text('Kuch rows mein SKU ya Name duplicate hone ki wajah se error aayi hai. Aap error report download kar sakte hain.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          if (failedRows.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.download),
              label: const Text('Download Error Report'),
              onPressed: () => _downloadErrorReport(failedRows),
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

  // 4. Generate & Download Error Report Excel File
  Future<void> _downloadErrorReport(List<Map<String, dynamic>> failedRows) async {
    try {
      var excel = excel_lib.Excel.createExcel();
      String sheetName = 'Import_Errors';
      excel.rename('Sheet1', sheetName);
      var sheet = excel[sheetName];

      sheet.appendRow([
        excel_lib.TextCellValue('RowNumber'),
        excel_lib.TextCellValue('ItemName'),
        excel_lib.TextCellValue('SKU'),
        excel_lib.TextCellValue('ErrorMessage'),
      ]);

      for (var err in failedRows) {
        sheet.appendRow([
          excel_lib.TextCellValue(err['Row'].toString()),
          excel_lib.TextCellValue(err['ItemName'].toString()),
          excel_lib.TextCellValue(err['SKU'].toString()),
          excel_lib.TextCellValue(err['Error'].toString()),
        ]);
      }

      var fileBytes = excel.encode();
      if (fileBytes == null) return;

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Error Report',
        fileName: 'Product_Import_Errors.xlsx',
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(fileBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error Report file download ho gayi!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Product Import / Update'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 16),
                    Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Card(
                    color: Colors.teal50,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('1. Pehle "Download Sample Template" par click karke Excel format download karein.'),
                          Text('2. Excel file mein apne products ka Naam, SKU, Category, Stock aur A-Z Prices bharein.'),
                          Text('3. Dhyan rahe: Product Name aur SKU kabhi bhi same nahi hone chahiye.'),
                          Text('4. Bhari hui file ko "Upload & Import Products" se upload karein.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Download Sample Template', style: TextStyle(fontSize: 16)),
                    onPressed: _downloadSampleTemplate,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload & Import Products', style: TextStyle(fontSize: 16)),
                    onPressed: _importAndValidateExcel,
                  ),
                ],
              ),
      ),
    );
  }
}
