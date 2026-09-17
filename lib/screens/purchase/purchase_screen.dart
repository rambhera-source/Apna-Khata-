import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/models/settings_model.dart'; 
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/models/pdf_helper.dart';
import '../account/add_account_screen.dart';
import '../products/product_inventory_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final TextEditingController _dateController = TextEditingController();
  
  final TextEditingController _inlineSearchController = TextEditingController();
  final TextEditingController _inlineQtyController = TextEditingController(text: '1');
  final TextEditingController _inlinePriceController = TextEditingController(text: '0');
  final TextEditingController _extraChargeSearchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _partyFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _extraChargeFocusNode = FocusNode();
  final FocusNode _saveButtonFocusNode = FocusNode();

  List<Map<String, dynamic>> _presetExtraChargesList = [];
  final List<Map<String, dynamic>> _appliedExtraChargesList = [];

  DateTime _selectedDate = DateTime.now();

  List<Account> _allAccountsList = [];
  List<InventoryItem> _allInventoryItems = [];
  InventoryItem? _selectedInlineProduct;
  
  final List<Map<String, dynamic>> _cartItems = [];
  
  String _paymentMode = 'Credit';
  final List<String> _paymentModes = ['Credit', 'Cash', 'Bank / UPI'];

  String _globalStockType = 'Fresh';
  final List<String> _stockTypes = ['Fresh', 'Replacement', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';
  double _gstRate = 18.0;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    _loadDropdownDataAndSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateFocusNode.requestFocus();
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
      _presetExtraChargesList = loadedCharges;
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
    double pr = double.tryParse(_inlinePriceController.text) ?? _selectedInlineProduct!.purchasePrice;

    if (q <= 0 || pr < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid quantity and price!'), backgroundColor: Colors.red),
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

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      _searchFocusNode.requestFocus();
    });
  }

  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  double get _extraChargesTotal {
    double total = 0.0;
    for (var charge in _appliedExtraChargesList) {
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
    double taxableValue = _subTotal + _extraChargesTotal;
    if (taxableValue < 0) taxableValue = 0;
    return taxableValue * (_gstRate / 100);
  }

  double get _grandTotal {
    double total = _subTotal + _extraChargesTotal + _taxAmount;
    return total < 0 ? 0 : total;
  }

  void _showPurchasePreviewDialog() {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select supplier name and add items first!'), backgroundColor: Colors.red),
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
            const Text('Purchase Invoice Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
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
                      Text('Purchase Inward Record', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                        Text('Supplier: $partyName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Payment: $_paymentMode | Type: $_globalStockType', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bill No: ${_billNoController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Date: ${_dateController.text}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(4)),
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
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${item['name']} [${item['sku']}]',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                        for (var charge in _appliedExtraChargesList)
                          Text('${charge['name']}: ₹ ${(charge['qty'] * charge['rate']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        if (_isGstActive) Text('GST (${_gstRate}%): + ₹ ${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
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

  Future<void> _generateAndPrintOrShareBill({required bool isShare}) async {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _cartItems.isEmpty) return;

    await PdfHelper.generateAndPrintOrShare(
      title: _isGstActive ? 'PURCHASE INVOICE (GST)' : 'PURCHASE BILL',
      voucherNoKey: 'Bill No',
      voucherNoValue: _billNoController.text,
      date: _dateController.text,
      partyLabel: 'Supplier Name',
      partyName: partyName,
      items: _cartItems,
      subTotal: _subTotal,
      extraCharges: _appliedExtraChargesList.map((e) => {'name': e['name'], 'rate': (e['qty'] as double) * (e['rate'] as double)}).toList(),
      taxAmount: _taxAmount,
      grandTotal: _grandTotal,
      isGstActive: _isGstActive,
      companyGstin: _companyGstin,
      gstRate: _gstRate,
      isShare: isShare,
    );
  }

  Future<void> _savePurchaseTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill supplier and items!'), backgroundColor: Colors.red));
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
        ..notes = 'Purchase Entry';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double boughtQty = (cartItem['qty'] as int).toDouble();
        double newPurchasePrice = cartItem['price'];
        String itemStockType = cartItem['stockType'] ?? 'Fresh';

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          if (itemStockType == 'Fresh') {
            invItem.stockQuantity += boughtQty;
          } else if (itemStockType == 'Replacement') {
            invItem.replacementStock = (invItem.replacementStock ?? 0.0) + boughtQty;
          } else if (itemStockType == 'Damaged') {
            invItem.damagedStock = (invItem.damagedStock ?? 0.0) + boughtQty;
          } else {
            invItem.stockQuantity += boughtQty;
          }

          invItem.purchasePrice = newPurchasePrice;
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
            Text('Purchase Saved Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Purchase bill has been saved successfully and inventory updated.', style: TextStyle(fontSize: 13)),
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
              _generateAndPrintOrShareBill(isShare: true);
              _clearBill();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareBill(isShare: false);
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
      _billNoController.text = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _appliedExtraChargesList.clear();
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
        content: const Text('Do you really want to exit this purchase bill?', style: TextStyle(fontSize: 13)),
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
          title: Text(_isGstActive ? 'Purchase Entry (GST)' : 'Purchase Entry'),
          backgroundColor: Colors.blue.shade800,
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
                        controller: _billNoController,
                        style: const TextStyle(fontSize: 11),
                        decoration: const InputDecoration(
                          labelText: 'Bill No',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
                          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
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
                              labelText: 'Supplier / Party Name *',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              prefixIcon: Icon(Icons.person, size: 16),
                            ),
                            onSubmitted: (_) {
                              if (_partyController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill supplier name first!'), backgroundColor: Colors.red),
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
                                        tileColor: Colors.blue.shade50,
                                        leading: const Icon(Icons.person_add, color: Colors.blue, size: 16),
                                        title: const Text('+ Add New Party / Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
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
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 40,
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
              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(color: Colors.blue.shade800, borderRadius: BorderRadius.circular(4)),
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

              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    ...List.generate(_cartItems.length, (index) {
                      final item = _cartItems[index];
                      double total = (item['qty'] as int) * (item['price'] as double);

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
                                  Text(
                                    item['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text('SKU: ${item['sku']} | Type: ${item['stockType']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 45,
                              child: TextField(
                                controller: TextEditingController(text: item['qty'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: item['qty'].toString().length)),
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
                                controller: TextEditingController(text: item['price'].toString()) ..selection = TextSelection.fromPosition(TextPosition(offset: item['price'].toString().length)),
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
                              child: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue), textAlign: TextAlign.right),
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

                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
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
                                  _inlinePriceController.text = selection.purchasePrice.toString();
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
                                        const SnackBar(content: Text('Please fill supplier name first!'), backgroundColor: Colors.red),
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
                                              tileColor: Colors.blue.shade100,
                                              leading: const Icon(Icons.add_circle, color: Colors.blue, size: 16),
                                              title: const Text('+ Add New Product / Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                                              onTap: () async {
                                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
                                                await _loadDropdownDataAndSettings();
                                              },
                                            );
                                          }
                                          final item = options.elementAt(index - 1);
                                          return ListTile(
                                            dense: true,
                                            title: Text(
                                              item.itemName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text('SKU: ${item.sku ?? "-"} | Stock: ${item.stockQuantity}', style: const TextStyle(fontSize: 9)),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                                    maxLines: 1,
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
              
              // Settings Linked Extra Charges Section
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
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

                    ...List.generate(_appliedExtraChargesList.length, (index) {
                      final charge = _appliedExtraChargesList[index];
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
                              onPressed: () => setState(() => _appliedExtraChargesList.removeAt(index)),
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
                            return _presetExtraChargesList.where((c) => c['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          displayStringForOption: (option) => option['name'],
                          onSelected: (selection) {
                            setState(() {
                              _appliedExtraChargesList.add({
                                'name': selection['name'],
                                'type': selection['type'],
                                'mode': selection['mode'],
                                'qty': 1.0,
                                'rate': selection['value'] ?? 0.0,
                              });
                            });
                            _extraChargeSearchController.clear();
                          },
                          textEditingController: _extraChargeSearchController,
                          focusNode: _extraChargeFocusNode,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(fontSize: 11),
                              decoration: const InputDecoration(
                                labelText: 'Add Charge / Discount from Settings...',
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
                        Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        icon: const Icon(Icons.preview, size: 14),
                        label: const Text('Preview', style: TextStyle(fontSize: 11)),
                        onPressed: _showPurchasePreviewDialog,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share', style: TextStyle(fontSize: 11)),
                        onPressed: () => _generateAndPrintOrShareBill(isShare: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        focusNode: _saveButtonFocusNode,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        onPressed: _savePurchaseTransaction,
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
    _billNoController.dispose();
    _dateController.dispose();
    _inlineSearchController.dispose();
    _inlineQtyController.dispose();
    _inlinePriceController.dispose();
    _extraChargeSearchController.dispose();
    _scrollController.dispose();
    _dateFocusNode.dispose();
    _partyFocusNode.dispose();
    _searchFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _extraChargeFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }
}
