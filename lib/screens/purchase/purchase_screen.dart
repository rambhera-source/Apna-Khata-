import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/models/settings_model.dart'; 
import 'package:accounting_app/models/inventory_model.dart'; 
import '../searchable_field.dart';
import '../account/add_account_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  // Freight Controllers (Default rate ₹30)
  final TextEditingController _freightQtyController = TextEditingController(text: '1');
  final TextEditingController _freightRateController = TextEditingController(text: '30');

  // Discount Controllers
  final TextEditingController _discountValueController = TextEditingController(text: '0');
  String _discountType = '₹';

  // Dynamic Charges List loaded from Settings
  List<Map<String, dynamic>> _presetChargesList = [];
  Map<String, dynamic>? _selectedPresetCharge;
  final TextEditingController _extraChargeAmountController = TextEditingController(text: '0');
  
  // List to hold multiple added extra charges
  final List<Map<String, dynamic>> _extraChargesList = [];

  // Selected Bill Date Variable
  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = [];
  
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  String _globalStockType = 'Fresh';

  bool _isGstActive = false;
  String _companyGstin = '';

  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));

  @override
  void initState() {
    super.initState();
    _loadDropdownDataAndSettings();
  }

  Future<void> _loadDropdownDataAndSettings() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();

    List<Map<String, dynamic>> loadedCharges = [];
    if (settings != null) {
      try {
        loadedCharges = settings.extraCharges.map((e) {
          try {
            return Map<String, dynamic>.from(jsonDecode(e));
          } catch (_) {
            return {'name': e.toString(), 'type': 'Add', 'mode': 'Fixed', 'value': 0.0};
          }
        }).toList();
      } catch (_) {
        loadedCharges = [
          {'name': 'Packing Charge', 'type': 'Add', 'mode': 'Fixed', 'value': 0.0},
        ];
      }
    }

    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allInventoryItems = inventoryItems;
      if (settings != null) {
        _isGstActive = settings.isGstEnabled;
        _companyGstin = settings.gstin ?? '';
      }
      _presetChargesList = loadedCharges;
      if (_presetChargesList.isNotEmpty) {
        _selectedPresetCharge = _presetChargesList.first;
        _extraChargeAmountController.text = _selectedPresetCharge!['value'].toString();
      }
    });
  }

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

  // 🛒 Add Purchase Item Popup
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
                    items: _allInventoryItems.map((p) => DropdownMenuItem(value: p, child: Text('${p.itemName} (SKU: ${p.sku ?? "-"})'))).toList(),
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
                        'sku': selectedItem.sku ?? '-',
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
                    const SnackBar(content: Text('Yeh Product Name ya SKU ID पहले से मौजूद है!'), backgroundColor: Colors.red),
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

  // 🧮 Calculations
  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  double get _freightTotalAmount {
    int qty = int.tryParse(_freightQtyController.text) ?? 0;
    double rate = double.tryParse(_freightRateController.text) ?? 0.0;
    return qty * rate;
  }

  double get _discountAmount {
    double val = double.tryParse(_discountValueController.text) ?? 0.0;
    if (_discountType == '%') {
      return (_subTotal * val) / 100;
    }
    return val;
  }

  double get _extraChargesTotal {
    double totalNet = 0.0;
    for (var item in _extraChargesList) {
      double amt = item['amount'] as double;
      if (item['mode'] == 'Percentage') {
        amt = (_subTotal * amt) / 100;
      }
      if (item['type'] == 'Add') {
        totalNet += amt;
      } else {
        totalNet -= amt;
      }
    }
    return totalNet;
  }

  double get _taxAmount {
    if (!_isGstActive) return 0.0;
    double taxableValue = _subTotal - _discountAmount + _freightTotalAmount + _extraChargesTotal;
    if (taxableValue < 0) taxableValue = 0;
    return taxableValue * 0.18;
  }

  double get _grandTotal {
    double total = _subTotal - _discountAmount + _freightTotalAmount + _extraChargesTotal + _taxAmount;
    return total < 0 ? 0 : total;
  }

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
                headers: ['S.No', 'Item Description (SKU)', 'Qty', 'Price (₹)', 'Total (₹)'],
                data: List.generate(_cartItems.length, (index) {
                  final item = _cartItems[index];
                  double total = (item['qty'] as int) * (item['price'] as double);
                  return [
                    '${index + 1}',
                    '${item['name']} [${item['sku']}] (${item['stockType']})',
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
                        if (_discountAmount > 0) pw.Text('Discount: - ₹ ${_discountAmount.toStringAsFixed(2)}'),
                        if (_freightTotalAmount > 0) pw.Text('Freight Charge: + ₹ ${_freightTotalAmount.toStringAsFixed(2)}'),
                        for (var extra in _extraChargesList)
                          pw.Text('${extra['name']} (${extra['type']}): ${extra['type'] == 'Add' ? '+' : '-'} ₹ ${(extra['amount'] as double).toStringAsFixed(2)}'),
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

  Future<void> _savePurchaseTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Supplier aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = 'Purchase'
        ..voucherNumber = _billNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = _isGstActive ? 'GST Purchase Entry ([$_globalStockType Stock])' : 'Purchase Entry ([$_globalStockType Stock])';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double boughtQty = (cartItem['qty'] as int).toDouble();
        double newPurchasePrice = cartItem['price'];

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          invItem.stockQuantity += boughtQty;
          invItem.purchasePrice = newPurchasePrice;
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
        content: const Text('Kya aap is purchase bill ka print lena chahte hain?'),
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
                  onPressed: _addItemToCart,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.blue.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 4, child: Text('Product Name / SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 30),
                ],
              ),
            ),
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(child: Text('Koi item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        double total = (item['qty'] as int) * (item['price'] as double);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('SKU: ${item['sku']} (${item['stockType']})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text('${item['qty']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('₹${item['price']}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue), textAlign: TextAlign.right),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () {
                                  setState(() => _cartItems.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // DISCOUNT SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount:', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _discountValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 60,
                            child: DropdownButtonFormField<String>(
                              value: _discountType,
                              items: const [
                                DropdownMenuItem(value: '₹', child: Text('₹')),
                                DropdownMenuItem(value: '%', child: Text('%')),
                              ],
                              onChanged: (val) => setState(() => _discountType = val!),
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FREIGHT CHARGE (Default ₹30)
                  const Text('Freight Charge (Default ₹30 / unit):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _freightQtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'No. (1, 2, 3...)', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _freightRateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Rate (₹)', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '= ₹ ${_freightTotalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // EXTRA CHARGES DROPDOWN (Loaded from Settings Master)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedPresetCharge,
                          isExpanded: true,
                          items: _presetChargesList.map((c) => DropdownMenuItem(
                            value: c, 
                            child: Text('${c['name']} (${c['type'] == 'Add' ? '+' : '-'})', style: TextStyle(fontSize: 13, color: c['type'] == 'Add' ? Colors.blue.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold)),
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedPresetCharge = val;
                              if (val != null) {
                                _extraChargeAmountController.text = val['value'].toString();
                              }
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Select Charge / Discount', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _extraChargeAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Value', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                        onPressed: () {
                          if (_selectedPresetCharge != null) {
                            setState(() {
                              _extraChargesList.add({
                                'name': _selectedPresetCharge!['name'],
                                'type': _selectedPresetCharge!['type'],
                                'mode': _selectedPresetCharge!['mode'],
                                'amount': double.tryParse(_extraChargeAmountController.text) ?? 0.0,
                              });
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  // LIST OF ADDED EXTRA CHARGES
                  if (_extraChargesList.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Column(
                      children: List.generate(_extraChargesList.length, (i) {
                        final ex = _extraChargesList.length > i ? _extraChargesList[i] : null;
                        if (ex == null) return const SizedBox.shrink();
                        bool isAdd = ex['type'] == 'Add';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${ex['name']} (${ex['mode']})', style: TextStyle(fontSize: 12, color: isAdd ? Colors.blue.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text('${isAdd ? "+" : "-"} ${ex['amount']}${ex['mode'] == 'Percentage' ? '%' : '₹'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAdd ? Colors.blue : Colors.red)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                  onPressed: () => setState(() => _extraChargesList.removeAt(i)),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                  ],

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _paymentMode = val!),
                          decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
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
