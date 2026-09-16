  Future<void> _downloadTemplateFile() async {
    try {
      List<List<dynamic>> rows = [];
      Set<String> uniqueCategories = _allInventoryItems
          .map((item) => item.category ?? '')
          .where((cat) => cat.trim().isNotEmpty)
          .toSet();
      
      String availableCategoriesStr = uniqueCategories.isNotEmpty ? uniqueCategories.join(', ') : 'General, Charger, Power Bank';

      // 🔥 आपके बताए गए सटीक सीक्वेंस के अनुसार हेडर्स
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

      // नमूना डेटा (Sample Row)
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

            // 🔥 आपके बताए गए नए सीक्वेंस के अनुसार कॉलम मैपिंग
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
