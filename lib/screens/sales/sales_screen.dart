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
import 'package:accounting_app/models/order_model.dart';
import 'package:accounting_app/models/settings_model.dart'; 
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/screens/searchable_field.dart';
import 'package:accounting_app/screens/account/add_account_screen.dart';        
import 'package:accounting_app/screens/products/product_inventory_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController(text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  // Inline Product Search & Input Controllers
  final TextEditingController _inlineQtyController = TextEditingController(text: '1');
  final TextEditingController _inlinePriceController = TextEditingController(text: '0');

  // Dynamic Charges List loaded from Settings (Database)
  List<Map<String, dynamic>> _presetChargesList = [];
  
  // Dynamic Bill Level Charges / Freight / Discounts rows
  final List<Map<String, dynamic>> _billChargesList = [];

  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = [];
  InventoryItem? _selectedInlineProduct;
  
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  String _globalStockType = 'Fresh';
  final List<String> _stockTypes = ['Fresh', 'Old', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';
  double _gstRate = 18.0;

  List<SalesOrder> _pendingOrdersList = [];
  SalesOrder? _selectedPendingOrder;

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
    
    loadedCharges.add({'name': 'Freight Charge', 'type': 'Add', 'mode': 'Fixed', 'value': 30.0});
    loadedCharges.add({'name': 'Discount', 'type': 'Less', 'mode': 'Fixed', 'value': 0.0});

    if (settings != null) {
      try {
        for (var e in settings.extraCharges) {
          try {
            loadedCharges.add(Map<String, dynamic>.from(jsonDecode(e)));
          } catch (_) {}
        }
      } catch (_) {}
    }

    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allInventoryItems = inventoryItems;
      if (settings != null) {
        _isGstActive = settings.isGstEnabled;
        _companyGstin = settings.gstin ?? '';
      }
      _presetChargesList = loadedCharges;
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
      _checkForPendingOrders(newPartyName);
    }
  }

  Future<void> _checkForPendingOrders(String partyName) async {
    if (partyName.isEmpty) return;

    final orders = await DatabaseHelper.isar.salesOrders
        .filter()
        .partyNameEqualTo(partyName, caseSensitive: false)
        .and()
        .statusEqualTo('Pending')
        .findAll();

    setState(() {
      _pendingOrdersList = orders;
      _selectedPendingOrder = orders.isNotEmpty ? orders.first : null;
    });

    if (orders.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${orders.length} Pending Order(s) found for $partyName!'),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addInlineItemToCart() {
    if (_selectedInlineProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya valid product select karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    int q = int.tryParse(_inlineQtyController.text) ?? 1;
    double pr = double.tryParse(_inlinePriceController.text) ?? _selectedInlineProduct!.priceA;

    if (q <= 0 || pr <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity aur Price > 0 honi chahiye!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _cartItems.add({
        'name': _selectedInlineProduct!.itemName,
        'sku': _selectedInlineProduct!.sku ?? '-',
        'qty': q,
        'price': pr,
        'stockType': _globalStockType,
      });

      _selectedInlineProduct = null;
      _inlineQtyController.text = '1';
      _inlinePriceController.text = '0';
    });
  }

  void _editCartItem(int index) {
    final item = _cartItems[index];
    final qtyController = TextEditingController(text: item['qty'].toString());
    final priceController = TextEditingController(text: item['price'].toString());
    String editStockType = item['stockType'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Item: ${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: editStockType,
                    items: _stockTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        editStockType = val!;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Stock Type', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () {
                    int q = int.tryParse(qtyController.text) ?? 1;
                    double pr = double.tryParse(priceController.text) ?? item['price'];
                    
                    setState(() {
                      _cartItems[index]['qty'] = q;
                      _cartItems[index]['price'] = pr;
                      _cartItems[index]['stockType'] = editStockType;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  double get _billChargesTotal {
    double total = 0.0;
    for (var charge in _billChargesList) {
      double qty = charge['qty'] is double ? charge['qty'] : double.tryParse(charge['qty'].toString()) ?? 1.0;
      double rate = charge['rate'] is double ? charge['rate'] : double.tryParse(charge['rate'].toString()) ?? 0.0;
      double amt = qty * rate;

      if (charge['type'] == 'Less' || charge['name'].toString().toLowerCase().contains('discount')) {
        total -= amt;
      } else {
        total += amt;
      }
    }
    return total;
  }

  double get _taxAmount {
    if (!_isGstActive) return 0.0;
    double taxableValue = _subTotal + _billChargesTotal;
    if (taxableValue < 0) taxableValue = 0;
    return taxableValue * (_gstRate / 100);
  }

  double get _grandTotal {
    double total = _subTotal + _billChargesTotal + _taxAmount;
    return total < 0 ? 0 : total;
  }

  Future<void> _generateAndPrintOrShareInvoice({required bool isWhatsApp}) async {
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
                      pw.Text('Wholesale & Retail Mobile Parts & Accessories', style: const pw.TextStyle(fontSize: 10)),
                      if (_isGstActive && _companyGstin.isNotEmpty)
                        pw.Text('GSTIN: $_companyGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_isGstActive ? 'TAX INVOICE (GST)' : 'BILL / ESTIMATE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                      pw.Text('Invoice No: ${_invoiceNoController.text}'),
                      pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
              pw.SizedBox(height: 10),
              pw.Text('Bill To: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal), borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Sub Total: ₹ ${_subTotal.toStringAsFixed(2)}'),
                        for (var charge in _billChargesList)
                          pw.Text('${charge['name']} (${charge['qty']} x ₹${charge['rate']}): ₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(2)}'),
                        if (_isGstActive) pw.Text('GST (${_gstRate.toStringAsFixed(1)}%): + ₹ ${_taxAmount.toStringAsFixed(2)}'),
                        pw.Divider(),
                        pw.Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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

    if (isWhatsApp) {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Invoice_${_invoiceNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Invoice #${_invoiceNoController.text} from ORLIFE. Total: ₹ ${_grandTotal.toStringAsFixed(2)}');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  Future<void> _saveSalesTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Party aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = 'Sales'
        ..voucherNumber = _invoiceNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = 'Sales Invoice';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double soldQty = (cartItem['qty'] as int).toDouble();
        final invItem = await DatabaseHelper.isar.inventoryItems.filter().itemNameEqualTo(prodName, caseSensitive: false).findFirst();
        if (invItem != null) {
          invItem.stockQuantity -= soldQty;
          if (invItem.stockQuantity < 0) invItem.stockQuantity = 0;
          await DatabaseHelper.isar.inventoryItems.put(invItem);
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Bill Successfully Saved!'), backgroundColor: Colors.green));
    _generateAndPrintOrShareInvoice(isWhatsApp: false);
    _clearBill();
  }

  void _clearBill() {
    setState(() {
      _cartItems.clear();
      _partyController.clear();
      _invoiceNoController.text = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _billChargesList.clear();
    });
  }

  // 🛡️ Smart Exit Warning Dialog (Triggers only if items are present in cart)
  Future<bool> _onWillPop() async {
    if (_cartItems.isEmpty) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Discard Bill?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Kya aap waqai is sales bill ko exit karna chahte hain? Aapke add kiye gaye items hat jayenge.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Exit'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sales Invoice'),
          backgroundColor: Colors.teal.shade800,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(DateFormat('dd-MMM-yyyy').format(_selectedDate), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice Number Row (Readonly / Fixed)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _invoiceNoController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Invoice Number (Fixed)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _globalStockType,
                      items: _stockTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _globalStockType = val!),
                      decoration: const InputDecoration(labelText: 'Stock Type', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SearchableField(
                      label: 'Customer / Party Name *',
                      items: _allAccounts,
                      controller: _partyController,
                      onSelected: (val) {
                        _partyController.text = val;
                        _checkForPendingOrders(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('New'),
                    onPressed: _navigateToAddNewParty,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Items in Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Expanded(
                child: _cartItems.isEmpty
                    ? const Center(child: Text('Koi item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          double total = (item['qty'] as int) * (item['price'] as double);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('SKU: ${item['sku']} | Type: ${item['stockType']} | Qty: ${item['qty']} x ₹${item['price']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.orange, size: 18),
                                    onPressed: () => _editCartItem(index),
                                    tooltip: 'Edit Item',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () => setState(() => _cartItems.removeAt(index)),
                                    tooltip: 'Delete Item',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              
              // BOTTOM CALCULATION CONTAINER
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
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
                    
                    // BILL CHARGES SECTION
                    if (_billChargesList.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_billChargesList.length, (i) {
                          final charge = _billChargesList[i];
                          double amt = (charge['qty'] as double) * (charge['rate'] as double);
                          bool isLess = charge['type'] == 'Less';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${charge['name']}:', style: const TextStyle(fontSize: 13)),
                              Text('${isLess ? "-" : "+"} ₹${amt.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: isLess ? Colors.red : Colors.green)),
                            ],
                          );
                        }),
                      ),
                    
                    if (_isGstActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GST (${_gstRate.toStringAsFixed(1)}%):', style: const TextStyle(fontSize: 13)),
                            Text('₹ ${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                      ),
                    
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
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.preview, size: 16),
                      label: const Text('Preview'),
                      onPressed: () => _generateAndPrintOrShareInvoice(isWhatsApp: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('WhatsApp'),
                      onPressed: () => _generateAndPrintOrShareInvoice(isWhatsApp: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                      onPressed: _saveSalesTransaction,
                      child: const Text('Save Bill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addInlineItemToCart,
          backgroundColor: Colors.teal,
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _partyController.dispose();
    _invoiceNoController.dispose();
    _inlineQtyController.dispose();
    _inlinePriceController.dispose();
    super.dispose();
  }
}
