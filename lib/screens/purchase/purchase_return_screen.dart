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
import '../products/product_inventory_screen.dart';

class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key});

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _returnNoController = TextEditingController(text: 'PRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  final TextEditingController _inlineSearchController = TextEditingController();
  final TextEditingController _inlineQtyController = TextEditingController(text: '1');
  final TextEditingController _inlinePriceController = TextEditingController(text: '0');
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  List<Map<String, dynamic>> _presetChargesList = [];
  final List<Map<String, dynamic>> _billChargesList = [];

  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = [];
  InventoryItem? _selectedInlineProduct;
  
  final List<Map<String, dynamic>> _cartItems = [];
  
  String _paymentMode = 'Credit';
  final List<String> _paymentModes = ['Credit', 'Cash', 'Bank / UPI'];

  String _globalStockType = 'Replacement';
  final List<String> _stockTypes = ['Fresh', 'Replacement', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';

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

  void _addInlineItemToReturnCart() {
    if (_selectedInlineProduct == null) return;

    int q = int.tryParse(_inlineQtyController.text) ?? 1;
    double pr = double.tryParse(_inlinePriceController.text) ?? _selectedInlineProduct!.purchasePrice;

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
      _inlineSearchController.clear();
      _inlineQtyController.text = '1';
      _inlinePriceController.text = '0';
    });

    Future.delayed(const Duration(milliseconds: 100), () => _searchFocusNode.requestFocus());
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
              title: const Text('Edit Return Item'),
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
    return taxableValue * 0.18;
  }

  double get _grandTotal {
    double total = _subTotal + _billChargesTotal + _taxAmount;
    return total < 0 ? 0 : total;
  }

  Future<void> _generateAndPrintOrShareReturn({required bool isShare}) async {
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
                      pw.Text('Purchase Return / Debit Note', style: const pw.TextStyle(fontSize: 10)),
                      if (_isGstActive && _companyGstin.isNotEmpty)
                        pw.Text('GSTIN: $_companyGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_isGstActive ? 'DEBIT NOTE (GST)' : 'PURCHASE RETURN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      pw.Text('Return No: ${_returnNoController.text}'),
                      pw.Text('Date: ${DateFormat('dd-MM-yy').format(_selectedDate)}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue),
              pw.SizedBox(height: 10),
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
                        for (var charge in _billChargesList)
                          pw.Text('${charge['name']} (${charge['qty']} x ₹${charge['rate']}): ₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(2)}'),
                        if (_isGstActive) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('CGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                          pw.Text('SGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                        ],
                        pw.Divider(),
                        pw.Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
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
      final file = File('${output.path}/PurchaseReturn_${_returnNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Purchase Return / Debit Note #${_returnNoController.text}. Total: ₹ $_grandTotal');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  Future<void> _savePurchaseReturnTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Party aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = 'Purchase Return'
        ..voucherNumber = _returnNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = 'Purchase Return Entry';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double returnedQty = (cartItem['qty'] as int).toDouble();

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          invItem.stockQuantity -= returnedQty;
          if (invItem.stockQuantity < 0) invItem.stockQuantity = 0;
          await DatabaseHelper.isar.inventoryItems.put(invItem);
        }
      }
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('Purchase Return Saved!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Purchase return safalपूर्वक save ho gaya hai. Ab aap ise share ya print kar sakte hain.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearBill();
            },
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share PDF'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareReturn(isShare: true);
              _clearBill();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareReturn(isShare: false);
              _clearBill();
            },
          ),
        ],
      ),
    );
  }

  void _clearBill() {
    setState(() {
      _cartItems.clear();
      _partyController.clear();
      _returnNoController.text = 'PRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _billChargesList.clear();
    });
  }

  Future<bool> _onWillPop() async {
    if (_cartItems.isEmpty) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Discard Return Bill?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Kya aap waqai is purchase return bill ko exit karna chahte hain?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
          title: Text(_isGstActive ? 'Purchase Return (GST)' : 'Purchase Return'),
          backgroundColor: Colors.blue.shade900,
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
                      Text(DateFormat('dd-MMM-yy').format(_selectedDate), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _returnNoController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Return No',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: DropdownButtonFormField<String>(
                        value: _globalStockType,
                        items: _stockTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) => setState(() => _globalStockType = val!),
                        decoration: const InputDecoration(labelText: 'Stock Type', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMode,
                        items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setState(() => _paymentMode = val!),
                        decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: _selectDate,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 13, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd-MM-yy').format(_selectedDate),
                              style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 42,
                      child: SearchableField(
                        label: 'Supplier / Party Name *',
                        items: _allAccounts,
                        controller: _partyController,
                        onSelected: (val) => _partyController.text = val,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      icon: const Icon(Icons.person_add, size: 14),
                      label: const Text('New', style: TextStyle(fontSize: 11)),
                      onPressed: _navigateToAddNewParty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const Text('Returned Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),

              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _cartItems.isEmpty
                          ? const Center(child: Text('Koi return item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                          : ListView.builder(
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];
                                double total = (item['qty'] as int) * (item['price'] as double);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${index + 1}. ${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 50,
                                        child: TextField(
                                          controller: TextEditingController(text: item['qty'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: item['qty'].toString().length)),
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            int? q = int.tryParse(val);
                                            if (q != null && q > 0) {
                                              setState(() => _cartItems[index]['qty'] = q);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 65,
                                        child: TextField(
                                          controller: TextEditingController(text: item['price'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: item['price'].toString().length)),
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            double? p = double.tryParse(val);
                                            if (p != null && p >= 0) {
                                              setState(() => _cartItems[index]['price'] = p);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                        onPressed: () => setState(() => _cartItems.removeAt(index)),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Autocomplete<InventoryItem>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return const Iterable<InventoryItem>.empty();
                              return _allInventoryItems.where((item) =>
                                item.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                (item.sku != null && item.sku!.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                              );
                            },
                            displayStringForOption: (InventoryItem option) => '${option.itemName} [SKU: ${option.sku ?? "-"}]',
                            onSelected: (InventoryItem selection) {
                              setState(() {
                                _selectedInlineProduct = selection;
                                _inlinePriceController.text = selection.purchasePrice.toString();
                              });
                              Future.delayed(const Duration(milliseconds: 100), () => _qtyFocusNode.requestFocus());
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              if (_inlineSearchController.text.isNotEmpty && controller.text.isEmpty) {
                                controller.text = _inlineSearchController.text;
                              }
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Search Product Name or SKU to add...',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  prefixIcon: const Icon(Icons.search, size: 16),
                                ),
                                onChanged: (val) => _inlineSearchController.text = val,
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: SizedBox(
                                    width: 280,
                                    height: 150,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == options.length) {
                                          return ListTile(
                                            tileColor: Colors.blue.shade100,
                                            leading: const Icon(Icons.add_circle, color: Colors.blue, size: 16),
                                            title: const Text('Add New Product / Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                                            onTap: () async {
                                              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
                                              await _loadDropdownDataAndSettings();
                                            },
                                          );
                                        }
                                        final item = options.elementAt(index);
                                        return ListTile(
                                          dense: true,
                                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          subtitle: Text('SKU: ${item.sku ?? "-"} | Stock: ${item.stockQuantity}', style: const TextStyle(fontSize: 9)),
                                          onTap: () => onSelected(item),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_selectedInlineProduct != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _inlineQtyController,
                                    focusNode: _qtyFocusNode,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onSubmitted: (_) => _priceFocusNode.requestFocus(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _inlinePriceController,
                                    focusNode: _priceFocusNode,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onSubmitted: (_) => _addInlineItemToReturnCart(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  onPressed: _addInlineItemToReturnCart,
                                  child: const Text('Add', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),

                    ...List.generate(_billChargesList.length, (index) {
                      final charge = _billChargesList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(charge['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            SizedBox(
                              width: 50,
                              child: TextField(
                                controller: TextEditingController(text: charge['qty'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: charge['qty'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(4)),
                                onChanged: (val) {
                                  charge['qty'] = double.tryParse(val) ?? 1.0;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: TextEditingController(text: charge['rate'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: charge['rate'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(4)),
                                onChanged: (val) {
                                  charge['rate'] = double.tryParse(val) ?? 0.0;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14, color: Colors.red),
                              onPressed: () => setState(() => _billChargesList.removeAt(index)),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 4),
                    Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        return _presetChargesList.where((c) => c['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (option) => option['name'],
                      onSelected: (selection) {
                        setState(() {
                          _billChargesList.add({
                            'name': selection['name'],
                            'type': selection['type'],
                            'mode': selection['mode'],
                            'qty': 1.0,
                            'rate': selection['value'] ?? 0.0,
                          });
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Add Freight / Charge...',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            prefixIcon: Icon(Icons.add_circle_outline, size: 16),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: SizedBox(
                              width: 240,
                              height: 120,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final opt = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(opt['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onTap: () => onSelected(opt),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                      icon: const Icon(Icons.preview, size: 14),
                      label: const Text('Preview', style: TextStyle(fontSize: 12)),
                      onPressed: () => _generateAndPrintOrShareReturn(isShare: false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                      icon: const Icon(Icons.share, size: 14),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      onPressed: () => _generateAndPrintOrShareReturn(isShare: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: _savePurchaseReturnTransaction,
                      child: const Text('Save Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _partyController.dispose();
    _returnNoController.dispose();
    _inlineSearchController.dispose();
    _inlineQtyController.dispose();
    _inlinePriceController.dispose();
    _searchFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }
}
