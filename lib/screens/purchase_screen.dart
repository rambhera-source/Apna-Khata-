import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart'; 
import '../models/inventory_model.dart'; // 🔥 Inventory Model
import 'searchable_field.dart';
import 'add_account_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  // 📅 Selected Bill Date Variable
  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = []; // 🔥 Using InventoryItem model directly
  
  // Cart items list: { 'name': String, 'qty': int, 'price': double, 'stockType': String }
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  // 🔥 Default Global Stock Type for Purchase ('Fresh' default)
  String _globalStockType = 'Fresh';

  // 🔥 GST Settings State Variables
  bool _isGstActive = false;
  String _companyGstin = '';

  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));

  @override
  void initState() {
    super.initState();
    _loadDropdownDataAndSettings();
  }

  // 📂 Load Accounts, Inventory and Company GST Settings
  Future<void> _loadDropdownDataAndSettings() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();

    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allInventoryItems = inventoryItems;
      if (settings != null) {
        _isGstActive = settings.isGstEnabled;
        _companyGstin = settings.gstin ?? '';
      }
    });
  }

  // 👤 Open Full AddAccountScreen for new Supplier
  void _navigateToAddNewParty() async {
    final String? newPartyName = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
    );

    await _loadDropdownDataAndSettings();

    if (newPartyName != null && newPartyName.isNotEmpty) {
      setState(() {
        _partyController.text = newPartyName;
      });
    }
  }

  // 🔥 ➕ Add Item to Purchase Cart / Advanced Add New Inventory Item Popup
  void _addItemToCart() {
    if (_allInventoryItems.isEmpty) {
      _showAddEditProductDialogForPurchase();
      return;
    }

    InventoryItem selectedItem = _allInventoryItems.first;
    final TextEditingController qtyController = TextEditingController(text: '1');
    final TextEditingController priceController = TextEditingController(text: selectedItem.purchasePrice.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Purchase Item'),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.blue.shade800),
                    icon: const Icon(Icons.add_box, size: 18),
                    label: const Text('Add New Product'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddEditProductDialogForPurchase();
                    },
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<InventoryItem>(
                    value: selectedItem,
                    items: _allInventoryItems.map((p) => DropdownMenuItem(value: p, child: Text('${p.itemName} (Stock: ${p.stockQuantity})'))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedItem = val!;
                        priceController.text = selectedItem.purchasePrice.toString();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase Price (₹)', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  onPressed: () {
                    int q = int.tryParse(qtyController.text) ?? 1;
                    double pr = double.tryParse(priceController.text) ?? selectedItem.purchasePrice;
                    setState(() {
                      _cartItems.add({
                        'name': selectedItem.itemName,
                        'qty': q,
                        'price': pr,
                        'stockType': _globalStockType,
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Bill'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ➕ Advanced Add New Product Popup directly inside Purchase Screen
  void _showAddEditProductDialogForPurchase() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController skuController = TextEditingController();
    final TextEditingController openingStockController = TextEditingController(text: '0');
    final TextEditingController qtyController = TextEditingController(text: '0');
    final TextEditingController purchasePriceController = TextEditingController(text: '0');
    final TextEditingController tierPriceController = TextEditingController(text: '0');
    
    Set<String> uniqueCategories = _allInventoryItems
        .map((item) => item.category ?? '')
        .where((cat) => cat.trim().isNotEmpty)
        .toSet();
    if (uniqueCategories.isEmpty) uniqueCategories = {'General', 'Charger', 'Power Bank'};

    String selectedCategory = uniqueCategories.first;
    String priceCategory = 'A';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Inventory Item'),
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
                          value: priceCategory,
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
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
                  item.itemName.toLowerCase() == name.toLowerCase() || 
                  (sku.isNotEmpty && item.sku != null && item.sku!.toLowerCase() == sku.toLowerCase())
                );

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeh Product Name ya SKU ID pehle से मौजूद है!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                await DatabaseHelper.isar.writeTxn(() async {
                  InventoryItem newItem = InventoryItem()
                    ..itemName = name
                    ..sku = sku
                    ..category = selectedCategory
                    ..openingStock = double.tryParse(openingStockController.text) ?? 0.0
                    ..stockQuantity = double.tryParse(qtyController.text) ?? 0.0
                    ..purchasePrice = double.tryParse(purchasePriceController.text) ?? 0.0
                    ..priceA = double.tryParse(tierPriceController.text) ?? 0.0
                    ..priceCategory = priceCategory
                    ..stockType = 'Fresh';

                  await DatabaseHelper.isar.inventoryItems.put(newItem);
                });

                if (!mounted) return;
                Navigator.pop(context);
                await _loadDropdownDataAndSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New Product Added Successfully!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }

  // 🧮 Calculations (Subtotal, Tax, Grand Total)
  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  double get _taxAmount {
    if (!_isGstActive) return 0.0;
    return _subTotal * 0.18; // 18% Tax Calculation
  }

  double get _grandTotal {
    return _subTotal + _taxAmount;
  }

  // 📄 Professional Purchase Bill PDF Generator
  Future<void> _generateAndPrintOrShareBill({required bool isShare}) async {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _cartItems.isEmpty) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Purchase Inward Record', style: const pw.TextStyle(fontSize: 10)),
                      if (_isGstActive && _companyGstin.isNotEmpty)
                        pw.Text('GSTIN: $_companyGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_isGstActive ? 'PURCHASE INVOICE (GST)' : 'PURCHASE BILL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      pw.Text('Bill No: ${_billNoController.text}'),
                      pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'),
                      pw.Text('Stock Type: $_globalStockType', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue),
              pw.SizedBox(height: 10),
              pw.Text('Supplier Details:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Supplier Name: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Payment Mode: $_paymentMode'),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headers: ['S.No', 'Item Description', 'Qty', 'Price (₹)', 'Total (₹)'],
                data: List.generate(_cartItems.length, (index) {
                  final item = _cartItems[index];
                  double total = (item['qty'] as int) * (item['price'] as double);
                  return [
                    '${index + 1}',
                    '${item['name']} (${item['stockType']})',
                    '${item['qty']}',
                    '${item['price']}',
                    '${total.toStringAsFixed(2)}',
                  ];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue), borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Sub Total: ₹ ${_subTotal.toStringAsFixed(2)}'),
                        if (_isGstActive) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('CGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                          pw.Text('SGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                        ],
                        pw.Divider(),
                        pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('₹ ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (isShare) {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Purchase_${_billNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Purchase Bill #${_billNoController.text}. Total: ₹ $_grandTotal');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  // 💾 Save Purchase Transaction & Update Inventory Items Stock
  Future<void> _savePurchaseTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Supplier aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      // 1. Save Accounting Transaction
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = 'Purchase'
        ..voucherNumber = _billNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = _isGstActive ? 'GST Purchase Entry ([$_globalStockType Stock])' : 'Purchase Entry ([$_globalStockType Stock])';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      // 2. Automatically Update Inventory Item Stock (Increase Stock on Purchase)
      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double boughtQty = (cartItem['qty'] as int).toDouble();
        double newPurchasePrice = cartItem['price'];

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          invItem.stockQuantity += boughtQty; // Stock बढ़ेगा
          invItem.purchasePrice = newPurchasePrice; // लेटेस्ट परचेस प्राइस अपडेट करें
          await DatabaseHelper.isar.inventoryItems.put(invItem);
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Entry Successfully Saved & Stock Updated!'), backgroundColor: Colors.green));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Saved Successfully!'),
        content: const Text('Kya aap is purchase bill का print lena chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print / PDF'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareBill(isShare: false);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGstActive ? 'Purchase Entry (GST Mode)' : 'Purchase Entry (Simple Mode)'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        // 🔥 Inventory icon removed from AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                    label: Text(
                      'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _billNoController,
                    decoration: const InputDecoration(labelText: 'Bill No', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                // 🔥 Stock Type Quick Toggle Button for Purchase
                InkWell(
                  onTap: () {
                    setState(() {
                      _globalStockType = _globalStockType == 'Fresh' ? 'Replacement' : 'Fresh';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purchase Stock Type switched to: $_globalStockType'),
                        duration: const Duration(milliseconds: 800),
                        backgroundColor: _globalStockType == 'Fresh' ? Colors.blue.shade700 : Colors.orange.shade800,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: _globalStockType == 'Fresh' ? Colors.blue.shade50 : Colors.orange.shade50,
                      border: Border.all(
                        color: _globalStockType == 'Fresh' ? Colors.blue : Colors.orange,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _globalStockType == 'Fresh' ? Icons.check_circle : Icons.swap_horiz,
                          size: 18,
                          color: _globalStockType == 'Fresh' ? Colors.blue.shade800 : Colors.orange.shade900,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _globalStockType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _globalStockType == 'Fresh' ? Colors.blue.shade800 : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: SearchableField(
                    label: 'Supplier / Party Name *',
                    items: _allAccounts,
                    controller: _partyController,
                    onSelected: (val) {
                      _partyController.text = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('New'),
                  onPressed: _navigateToAddNewParty,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  onPressed: _addItemToCart, // 👈 Opens Advanced Product Add / Select Popup
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(child: Text('Koi item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        double total = (item['qty'] as int) * (item['price'] as double);
                        bool isFresh = item['stockType'] == 'Fresh';
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFresh ? Colors.blue.shade100 : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['stockType'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isFresh ? Colors.blue.shade900 : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text('Qty: ${item['qty']} | Price: ₹ ${item['price']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() => _cartItems.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            
            // 💰 Totals & GST Summary Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_isGstActive) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CGST + SGST (18%):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('₹ ${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _paymentMode = val!),
                          decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      Text('Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                onPressed: _savePurchaseTransaction,
                child: const Text('Save Purchase & Update Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
