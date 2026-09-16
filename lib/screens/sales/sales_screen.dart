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
import '../../models/order_model.dart';
import '../../models/settings_model.dart'; 
import '../../models/inventory_model.dart';
import '../account/add_account_screen.dart';
import '../products/product_inventory_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController(text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final TextEditingController _dateController = TextEditingController();
  
  final TextEditingController _inlineSearchController = TextEditingController();
  final TextEditingController _inlineQtyController = TextEditingController(text: '1');
  final TextEditingController _inlinePriceController = TextEditingController(text: '0');
  final TextEditingController _freightSearchController = TextEditingController();
  
  // 🔥 Permanent Focus Nodes
  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _partyFocusNode = FocusNode();
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
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  String _globalStockType = 'Fresh';
  final List<String> _stockTypes = ['Fresh', 'Old', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';
  double _gstRate = 18.0;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    _loadDropdownDataAndSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
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
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
      _partyFocusNode.requestFocus();
    }
  }

  void _addInlineItemToCart() {
    if (_selectedInlineProduct == null) return;

    int q = int.tryParse(_inlineQtyController.text) ?? 1;
    double pr = double.tryParse(_inlinePriceController.text) ?? _selectedInlineProduct!.priceA;

    if (q <= 0 || pr < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity aur Price valid hone chahiye!'), backgroundColor: Colors.red),
      );
      return;
    }

    bool isOutOfStock = _selectedInlineProduct!.stockQuantity <= 0;

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
          'isOutOfStock': isOutOfStock,
        });
      }

      _selectedInlineProduct = null;
      _inlineSearchController.clear();
      _inlineQtyController.text = '1';
      _inlinePriceController.text = '0';
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      _searchFocusNode.requestFocus();
    });
  }

  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  // 🔥 फ्रेट और डिस्काउंट चार्जेज का कुल योग
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

  // 🔥 Interactive Invoice Preview Dialog (Freight & Discount के साथ)
  void _showInvoicePreviewDialog() {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Pehle Party Name aur Items add karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Invoice Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Column(
                    children: [
                      Text('ORLIFE Mobile Accessories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Wholesale & Retail Mobile Parts', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const Divider(thickness: 1.5, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill To: $partyName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Payment: $_paymentMode | Type: $_globalStockType', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Inv No: ${_invoiceNoController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Date: ${_dateController.text}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(4)),
                  child: const Row(
                    children: [
                      SizedBox(width: 25, child: Text('S.N.', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Item Name (SKU)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 35, child: Text('Qty', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 50, child: Text('Price', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      SizedBox(width: 55, child: Text('Total', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ...List.generate(_cartItems.length, (index) {
                  final item = _cartItems[index];
                  double total = (item['qty'] as int) * (item['price'] as double);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 25, child: Text('${index + 1}', style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 3, child: Text('${item['name']} [${item['sku']}]', style: const TextStyle(fontSize: 11))),
                        SizedBox(width: 35, child: Text('${item['qty']}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                        SizedBox(width: 50, child: Text('₹${item['price']}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                        SizedBox(width: 55, child: Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: ₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        for (var charge in _billChargesList)
                          Text('${charge['name']}: ₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        if (_isGstActive) Text('GST (${_gstRate}%): + ₹ ${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
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
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print / PDF'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: false);
            },
          ),
        ],
      ),
    );
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
                      pw.Text('Date: ${_dateController.text}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
              pw.SizedBox(height: 10),
              pw.Text('Bill To: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                headers: ['S.No', 'Item Description (SKU)', 'Qty', 'Unit', 'Price (₹)', 'Amount (₹)'],
                data: List.generate(_cartItems.length, (index) {
                  final item = _cartItems[index];
                  double total = (item['qty'] as int) * (item['price'] as double);
                  return [
                    '${index + 1}',
                    '${item['name']} [${item['sku']}]',
                    '${item['qty']}',
                    'Pcs',
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
                          pw.Text('${charge['name']}: ₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(2)}'),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.teal, size: 28),
            SizedBox(width: 10),
            Text('Bill Saved Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Aapka sales bill safalपूर्वक save ho gaya hai. Ab aap ise share ya print kar sakte hain.', style: TextStyle(fontSize: 13)),
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
              _generateAndPrintOrShareInvoice(isWhatsApp: true);
              _clearBill();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: false);
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
      _invoiceNoController.text = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _billChargesList.clear();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
  }

  Future<bool> _onWillPop() async {
    if (_cartItems.isEmpty) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Discard Bill?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Kya aap waqai is sales bill ko exit karna chahte hain?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Sales Invoice'),
          backgroundColor: Colors.teal.shade800,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar (Invoice No, Stock Type, Payment Mode)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _invoiceNoController,
                        readOnly: true,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          labelText: 'Invoice No',
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
                        value: _paymentMode,
                        items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setState(() => _paymentMode = val!),
                        decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Date & Customer Autocomplete
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 120,
                    child: TextField(
                      controller: _dateController,
                      focusNode: _dateFocusNode,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                          onPressed: _selectDate,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 4),
                        ),
                      ),
                      onTap: () {
                        _dateController.selection = TextSelection(baseOffset: 0, extentOffset: _dateController.text.length);
                      },
                      onSubmitted: (_) {
                        _partyFocusNode.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: RawAutocomplete<Account>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _allAccountsList;
                          }
                          return _allAccountsList.where((acc) => 
                            acc.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                            (acc.phone != null && acc.phone!.contains(textEditingValue.text))
                          );
                        },
                        displayStringForOption: (Account option) => option.name,
                        onSelected: (Account selection) {
                          _partyController.text = selection.name;
                          Future.delayed(const Duration(milliseconds: 50), () {
                            _searchFocusNode.requestFocus();
                          });
                        },
                        textEditingController: _partyController,
                        focusNode: _partyFocusNode,
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(fontSize: 12),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Customer / Party Name *',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              prefixIcon: Icon(Icons.person, size: 16),
                            ),
                            onSubmitted: (_) {
                              if (_partyController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Pehle Customer / Party Name bharein!'), backgroundColor: Colors.red),
                                );
                                _partyFocusNode.requestFocus();
                              } else {
                                _searchFocusNode.requestFocus();
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
                                width: 300,
                                height: 200,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return ListTile(
                                        tileColor: Colors.teal.shade50,
                                        leading: const Icon(Icons.person_add, color: Colors.teal, size: 16),
                                        title: const Text('+ Add New Party / Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
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
                ],
              ),
              const SizedBox(height: 6),

              // Professional Grid Table Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(color: Colors.teal.shade800, borderRadius: BorderRadius.circular(4)),
                child: const Row(
                  children: [
                    SizedBox(width: 25, child: Text('S.N.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                    Expanded(flex: 3, child: Text('Item Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                    SizedBox(width: 45, child: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                    SizedBox(width: 45, child: Text('Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.right)),
                    SizedBox(width: 65, child: Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.right)),
                    SizedBox(width: 25),
                  ],
                ),
              ),
              const SizedBox(height: 2),

              // Professional Items Table & Inline Search Grid
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...List.generate(_cartItems.length, (index) {
                      final item = _cartItems[index];
                      double total = (item['qty'] as int) * (item['price'] as double);
                      bool isOutOfStock = item['isOutOfStock'] ?? false;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 25, child: Text('${index + 1}', style: const TextStyle(fontSize: 11))),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isOutOfStock ? Colors.red : Colors.black87)),
                                  Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 45,
                              child: TextField(
                                controller: TextEditingController(text: item['qty'].toString())..selection = TextSelection.fromPosition(TextPosition(offset: item['qty'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
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
                            const SizedBox(width: 45, child: Text('Pcs', style: TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: TextEditingController(text: item['price'].toString())..selection = TextSelection.fromPosition(TextPosition(offset: item['price'].toString().length)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
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
                            SizedBox(
                              width: 65,
                              child: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal), textAlign: TextAlign.right),
                            ),
                            SizedBox(
                              width: 25,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 14),
                                onPressed: () => setState(() => _cartItems.removeAt(index)),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 6),

                    // Inline Product Search Bar inside Grid style
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedInlineProduct == null)
                            RawAutocomplete<InventoryItem>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (_partyController.text.trim().isEmpty) {
                                  return const Iterable<InventoryItem>.empty();
                                }
                                if (textEditingValue.text.isEmpty) return _allInventoryItems;
                                return _allInventoryItems.where((item) =>
                                  item.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                  (item.sku != null && item.sku!.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                                );
                              },
                              displayStringForOption: (InventoryItem option) => '${option.itemName} [SKU: ${option.sku ?? "-"}]',
                              onSelected: (InventoryItem selection) {
                                setState(() {
                                  _selectedInlineProduct = selection;
                                  _inlinePriceController.text = selection.priceA.toString();
                                  _inlineQtyController.text = '1';
                                });
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  _qtyFocusNode.requestFocus();
                                  _inlineQtyController.selection = TextSelection(baseOffset: 0, extentOffset: _inlineQtyController.text.length);
                                });
                              },
                              textEditingController: _inlineSearchController,
                              focusNode: _searchFocusNode,
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'Search Product Name or SKU to add...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    prefixIcon: Icon(Icons.search, size: 16),
                                  ),
                                  onTap: () {
                                    if (_partyController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('⚠️ Kripya pehle Customer / Party Name bharein!'), backgroundColor: Colors.red),
                                      );
                                      _partyFocusNode.requestFocus();
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
                                              tileColor: Colors.teal.shade100,
                                              leading: const Icon(Icons.add_circle, color: Colors.teal, size: 16),
                                              title: const Text('+ Add New Product / Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                                              onTap: () async {
                                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
                                                await _loadDropdownDataAndSettings();
                                              },
                                            );
                                          }
                                          final item = options.elementAt(index - 1);
                                          bool isOutOfStock = item.stockQuantity <= 0;

                                          return ListTile(
                                            dense: true,
                                            title: Text(item.itemName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isOutOfStock ? Colors.red : Colors.black87)),
                                            subtitle: Text('SKU: ${item.sku ?? "-"} | Stock: ${item.stockQuantity}', style: TextStyle(fontSize: 9, color: isOutOfStock ? Colors.red.shade700 : Colors.grey)),
                                            onTap: () => onSelected(item),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _selectedInlineProduct!.itemName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _selectedInlineProduct!.stockQuantity <= 0 ? Colors.red : Colors.teal),
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
                                    onSubmitted: (_) {
                                      _addInlineItemToCart();
                                    },
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
              
              // 🔥 Freight & Discount Charges Section (सेटिंग्स से लिंक्ड)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
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
                        child: RawAutocomplete<Map<String, dynamic>>(
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
                            _freightSearchController.clear();
                          },
                          textEditingController: _freightSearchController,
                          focusNode: _freightFocusNode,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(fontSize: 11),
                              decoration: const InputDecoration(
                                labelText: 'Add Freight / Discount Charge...',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                prefixIcon: Icon(Icons.add_circle_outline, size: 14),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isEmpty) {
                                  FocusScope.of(context).requestFocus(_saveButtonFocusNode);
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
                      ),
                    ),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Fixed Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        icon: const Icon(Icons.preview, size: 14),
                        label: const Text('Preview', style: TextStyle(fontSize: 11)),
                        onPressed: _showInvoicePreviewDialog,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                        onPressed: () => _generateAndPrintOrShareInvoice(isWhatsApp: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        focusNode: _saveButtonFocusNode,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        onPressed: _saveSalesTransaction,
                        child: const Text('Save Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
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
    _invoiceNoController.dispose();
    _dateController.dispose();
    _inlineSearchController.dispose();
    _inlineQtyController.dispose();
    _inlinePriceController.dispose();
    _freightSearchController.dispose();
    _dateFocusNode.dispose();
    _partyFocusNode.dispose();
    _searchFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _freightFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }
}
