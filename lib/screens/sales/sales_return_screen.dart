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

import '../../database/database_helper.dart';
import '../../models/account.dart';
import '../../models/transaction_model.dart';
import '../../models/settings_model.dart';
import '../../models/inventory_model.dart';
import '../account/add_account_screen.dart';
import '../products/product_inventory_screen.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _returnNoController = TextEditingController(text: 'SRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final TextEditingController _dateController = TextEditingController();
  
  final TextEditingController _inlineSearchController = TextEditingController();
  final TextEditingController _inlineQtyController = TextEditingController(text: '1');
  final TextEditingController _inlinePriceController = TextEditingController(text: '0');
  final TextEditingController _freightSearchController = TextEditingController();
  
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _freightFocusNode = FocusNode();
  final FocusNode _saveButtonFocusNode = FocusNode();

  List<Map<String, dynamic>> _presetChargesList = [];
  final List<Map<String, dynamic>> _billChargesList = [];

  DateTime _selectedDate = DateTime.now();

  List<Account> _allAccountsList = [];
  List<InventoryItem> _allInventoryItems = [];
  InventoryItem? _selectedInlineProduct;
  
  final List<Map<String, dynamic>> _cartItems = [];
  String _refundMode = 'Cash';
  final List<String> _refundModes = ['Cash', 'Bank / UPI', 'Adjust in Ledger'];

  String _globalStockType = 'Replacement';
  final List<String> _stockTypes = ['Fresh', 'Replacement', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
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
      _allAccountsList = accounts;
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

  // 📅 Compact & Modern Date Picker with Manual Entry Support
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.green.shade800,
            colorScheme: ColorScheme.light(primary: Colors.green.shade800),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: Center(
            child: SizedBox(
              width: 320,
              height: 420,
              child: child,
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  void _addInlineItemToReturnCart() {
    if (_selectedInlineProduct == null) return;

    int q = int.tryParse(_inlineQtyController.text) ?? 1;
    double pr = double.tryParse(_inlinePriceController.text) ?? _selectedInlineProduct!.purchasePrice;

    if (q <= 0 || pr < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity aur Price valid hone chahiye!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      int existingIndex = _cartItems.indexWhere((item) => item['name'] == _selectedInlineProduct!.itemName);

      if (existingIndex != -1) {
        _cartItems[existingIndex]['qty'] = (_cartItems[existingIndex]['qty'] as int) + q;
        _cartItems[existingIndex]['price'] = pr;
      } else {
        _cartItems.add({
          'name': _selectedInlineProduct!.itemName,
          'sku': _selectedInlineProduct!.sku ?? '-',
          'qty': q,
          'price': pr,
          'stockType': _globalStockType,
        });
      }

      _selectedInlineProduct = null;
      _inlineSearchController.clear();
      _inlineQtyController.text = '1';
      _inlinePriceController.text = '0';
    });

    Future.delayed(const Duration(milliseconds: 100), () => _searchFocusNode.requestFocus());
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
                      pw.Text('Sales Return / Credit Note', style: const pw.TextStyle(fontSize: 10)),
                      if (_isGstActive && _companyGstin.isNotEmpty)
                        pw.Text('GSTIN: $_companyGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_isGstActive ? 'CREDIT NOTE (GST)' : 'SALES RETURN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                      pw.Text('Return No: ${_returnNoController.text}'),
                      pw.Text('Date: ${_dateController.text}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.green),
              pw.SizedBox(height: 10),
              pw.Text('Customer Name: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Refund Mode: $_refundMode'),
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
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.green), borderRadius: pw.BorderRadius.circular(4)),
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
                        pw.Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
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
      final file = File('${output.path}/SalesReturn_${_returnNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Return / Credit Note #${_returnNoController.text}. Total: ₹ $_grandTotal');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  Future<void> _saveSalesReturnTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Party aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = 'Sales Return'
        ..voucherNumber = _returnNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _refundMode
        ..amount = _grandTotal
        ..notes = 'Sales Return Entry';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double returnedQty = (cartItem['qty'] as int).toDouble();

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          invItem.stockQuantity += returnedQty;
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
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Sales Return Saved!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Sales return safalपूर्वक save ho gaya hai. Ab aap ise share ya print kar sakte hain.', style: TextStyle(fontSize: 13)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
      _returnNoController.text = 'SRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
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
        content: const Text('Kya aap waqai is sales return bill ko exit karna chahte hain?', style: TextStyle(fontSize: 13)),
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(_isGstActive ? 'Sales Return (GST)' : 'Sales Return'),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _returnNoController,
                        readOnly: true,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          labelText: 'Return No',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 40,
                      child: DropdownButtonFormField<String>(
                        value: _globalStockType,
                        items: _stockTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (val) => setState(() => _globalStockType = val!),
                        decoration: const InputDecoration(labelText: 'Stock Type', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 40,
                      child: DropdownButtonFormField<String>(
                        value: _refundMode,
                        items: _refundModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setState(() => _refundMode = val!),
                        decoration: const InputDecoration(labelText: 'Refund Mode', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 110,
                    child: TextField(
                      controller: _dateController,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.green),
                          onPressed: _selectDate,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 4),
                        ),
                      ),
                      onChanged: (val) {
                        try {
                          final parsedDate = DateFormat('dd-MM-yyyy').parse(val);
                          setState(() {
                            _selectedDate = parsedDate;
                          });
                        } catch (_) {}
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TapRegion(
                        onTapOutside: (_) {},
                        child: RawAutocomplete<Account>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _allAccountsList;
                            }
                            return _allAccountsList.where((acc) => acc.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || (acc.phone != null && acc.phone!.contains(textEditingValue.text)));
                          },
                          displayStringForOption: (Account option) => option.name,
                          onSelected: (Account selection) {
                            _partyController.text = selection.name;
                            Future.delayed(const Duration(milliseconds: 100), () => _searchFocusNode.requestFocus());
                          },
                          textEditingController: _partyController,
                          focusNode: FocusNode(),
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Customer / Party Name *',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                prefixIcon: Icon(Icons.person, size: 16),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                child: SizedBox(
                                  width: 300,
                                  height: 200,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return ListTile(
                                          tileColor: Colors.green.shade50,
                                          leading: const Icon(Icons.person_add, color: Colors.green, size: 16),
                                          title: const Text('+ Add New Party / Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                                          onTap: () {
                                            _navigateToAddNewParty();
                                          },
                                        );
                                      }
                                      final acc = options.elementAt(index - 1);
                                      return ListTile(
                                        dense: true,
                                        title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        subtitle: Text('Ph: ${acc.phone ?? "N/A"} | Group: ${acc.groupCategory}', style: const TextStyle(fontSize: 9)),
                                        onTap: () => onSelected(acc),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              const Text('Returned Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...List.generate(_cartItems.length, (index) {
                      final item = _cartItems[index];
                      double total = (item['qty'] as int) * (item['price'] as double);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${index + 1}. ${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 45,
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
                              width: 60,
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
                            Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                              onPressed: () => setState(() => _cartItems.removeAt(index)),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedInlineProduct == null)
                            TapRegion(
                              onTapOutside: (_) {},
                              child: RawAutocomplete<InventoryItem>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return _allInventoryItems;
                                  return _allInventoryItems.where((item) =>
                                    item.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                    (item.sku != null && item.sku!.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                                  );
                                },
                                displayStringForOption: (InventoryItem option) => '${option.itemName} [SKU: ${option.sku ?? "-"}]',
                                onSelected: (InventoryItem selection) {
                                  int existingIndex = _cartItems.indexWhere((item) => item['name'] == selection.itemName);

                                  if (existingIndex != -1) {
                                    setState(() {
                                      _cartItems[existingIndex]['qty'] = (_cartItems[existingIndex]['qty'] as int) + 1;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('⚠️ ${selection.itemName} already in return. Quantity updated!'), duration: const Duration(seconds: 2)),
                                    );
                                    _inlineSearchController.clear();
                                  } else {
                                    setState(() {
                                      _selectedInlineProduct = selection;
                                      _inlinePriceController.text = selection.purchasePrice.toString();
                                      _inlineQtyController.text = '1';
                                    });
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _qtyFocusNode.requestFocus();
                                      _inlineQtyController.selection = TextSelection(baseOffset: 0, extentOffset: _inlineQtyController.text.length);
                                    });
                                  }
                                },
                                textEditingController: _inlineSearchController,
                                focusNode: _searchFocusNode,
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      labelText: 'Search Product Name or SKU to return...',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      prefixIcon: Icon(Icons.search, size: 16),
                                    ),
                                    onSubmitted: (val) {
                                      if (val.trim().isEmpty) {
                                        _freightFocusNode.requestFocus();
                                      }
                                    },
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
                                            if (index == 0) {
                                              return ListTile(
                                                tileColor: Colors.green.shade100,
                                                leading: const Icon(Icons.add_circle, color: Colors.green, size: 16),
                                                title: const Text('+ Add New Product / Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
                                                  await _loadDropdownDataAndSettings();
                                                },
                                              );
                                            }
                                            final item = options.elementAt(index - 1);
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
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _selectedInlineProduct!.itemName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: _inlineQtyController,
                                    focusNode: _qtyFocusNode,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                                    onTap: () => _inlineQtyController.selection = TextSelection(baseOffset: 0, extentOffset: _inlineQtyController.text.length),
                                    onSubmitted: (_) {
                                      _priceFocusNode.requestFocus();
                                      _inlinePriceController.selection = TextSelection(baseOffset: 0, extentOffset: _inlinePriceController.text.length);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 65,
                                  child: TextField(
                                    controller: _inlinePriceController,
                                    focusNode: _priceFocusNode,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                                    onTap: () => _inlinePriceController.selection = TextSelection(baseOffset: 0, extentOffset: _inlinePriceController.text.length),
                                    onSubmitted: (_) => _addInlineItemToReturnCart(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                  onPressed: () {
                                    setState(() => _selectedInlineProduct = null);
                                    _searchFocusNode.requestFocus();
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 6),
              
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 2),

                    ...List.generate(_billChargesList.length, (index) {
                      final charge = _billChargesList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(charge['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                            SizedBox(
                              width: 40,
                              height: 26,
                              child: TextField(
                                controller: TextEditingController(text: charge['qty'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: charge['qty'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 10),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(2)),
                                onChanged: (val) {
                                  charge['qty'] = double.tryParse(val) ?? 1.0;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 3),
                            SizedBox(
                              width: 50,
                              height: 26,
                              child: TextField(
                                controller: TextEditingController(text: charge['rate'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: charge['rate'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 10),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(2)),
                                onChanged: (val) {
                                  charge['rate'] = double.tryParse(val) ?? 0.0;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text('₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 12, color: Colors.red),
                              onPressed: () => setState(() => _billChargesList.removeAt(index)),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 2),
                    SizedBox(
                      height: 32,
                      child: TapRegion(
                        onTapOutside: (_) {},
                        child: RawAutocomplete<Map<String, dynamic>>,
                        // ...
