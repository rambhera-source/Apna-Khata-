import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/account.dart';
import '../../models/transaction_model.dart';
import '../../models/order_model.dart';
import '../../models/settings_model.dart'; 
import '../../models/inventory_model.dart';
import '../../models/pdf_helper.dart';
import '../account/add_account_screen.dart';
import '../products/product_inventory_screen.dart';

class SalesScreen extends StatefulWidget {
  final SalesOrder? initialOrder;

  const SalesScreen({super.key, this.initialOrder});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _isCreatingNewBill = false;
  List<AccountingTransaction> _salesHistory = [];
  bool _isLoadingHistory = false;
  String _searchHistoryQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _isCreatingNewBill = true;
    } else {
      _loadSalesHistory();
    }
  }

  Future<void> _loadSalesHistory() async {
    setState(() => _isLoadingHistory = true);
    var query = DatabaseHelper.isar.accountingTransactions
        .filter()
        .group((q) => q.voucherTypeEqualTo('Sales').or().voucherTypeEqualTo('Sales Return'));

    List<AccountingTransaction> results;
    if (_searchHistoryQuery.isNotEmpty) {
      results = await query.and().partyNameContains(_searchHistoryQuery, caseSensitive: false).sortByDateDesc().findAll();
    } else {
      results = await query.sortByDateDesc().findAll();
    }

    setState(() {
      _salesHistory = results;
      _isLoadingHistory = false;
    });
  }

  void _confirmDeleteTransaction(AccountingTransaction txn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Bill?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete invoice [${txn.voucherNumber}]?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await DatabaseHelper.isar.writeTxn(() async {
                await DatabaseHelper.isar.accountingTransactions.delete(txn.id);
              });
              Navigator.pop(context);
              _loadSalesHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bill Successfully Deleted!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingNewBill && widget.initialOrder == null) {
      return SalesFormView(
        onBack: () {
          setState(() {
            _isCreatingNewBill = false;
          });
          _loadSalesHistory();
        },
      );
    } else if (widget.initialOrder != null) {
      return SalesFormView(
        initialOrder: widget.initialOrder,
        onBack: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Register & History', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search Party Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        onChanged: (val) {
                          setState(() => _searchHistoryQuery = val);
                          _loadSalesHistory();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Sales Bill'),
                      onPressed: () {
                        setState(() {
                          _isCreatingNewBill = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _salesHistory.isEmpty
                      ? const Center(child: Text('No sales bill records found.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _salesHistory.length,
                          itemBuilder: (context, index) {
                            final txn = _salesHistory[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  '${txn.date != null ? DateFormat('dd-MM-yyyy').format(txn.date) : ""} | ${txn.voucherNumber} [${txn.voucherType}]', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                subtitle: Text('Party: ${txn.partyName} | Mode: ${txn.cashOrBank}', style: const TextStyle(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₹${txn.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      onPressed: () => _confirmDeleteTransaction(txn),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SALES FORM VIEW (ORIGINAL FLOW WITH FOCUS)
// ==========================================

class SalesFormView extends StatefulWidget {
  final SalesOrder? initialOrder;
  final VoidCallback onBack;

  const SalesFormView({super.key, this.initialOrder, required this.onBack});

  @override
  State<SalesFormView> createState() => _SalesFormViewState();
}

class _SalesFormViewState extends State<SalesFormView> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController();
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
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  String _transactionType = 'Sales'; 
  final List<String> _transactionTypes = ['Sales', 'Sales Return'];

  String _globalStockType = 'Fresh';
  final List<String> _stockTypes = ['Fresh', 'Old', 'Damaged'];

  bool _isGstActive = false;
  String _companyGstin = '';
  double _gstRate = 18.0;

  @override
  void initState() {
    super.initState();
    _updateInvoiceNumberPrefix();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    _loadDropdownDataAndSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
  }

  void _updateInvoiceNumberPrefix() {
    String prefix = _transactionType == 'Sales' ? 'INV' : 'SRN';
    _invoiceNoController.text = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
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

      if (widget.initialOrder != null) {
        _partyController.text = widget.initialOrder!.partyName;
        for (var item in widget.initialOrder!.items) {
          _cartItems.add({
            'name': item.productName,
            'sku': '-',
            'qty': item.qty,
            'price': item.price,
            'stockType': _globalStockType,
            'isOutOfStock': false,
          });
        }
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
          'isOutOfStock': _selectedInlineProduct!.stockQuantity <= 0,
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

  double get _subTotal => _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  double get _extraChargesTotal {
    double total = 0.0;
    for (var charge in _appliedExtraChargesList) {
      double qty = double.tryParse(charge['qty'].toString()) ?? 1.0;
      double rate = double.tryParse(charge['rate'].toString()) ?? 0.0;
      double amt = qty * rate;
      if (charge['type'] == 'Less' || charge['name'].toString().toLowerCase().contains('discount')) {
        total -= amt;
      } else {
        total += amt;
      }
    }
    return total;
  }
  double get _taxAmount => _isGstActive ? ((_subTotal + _extraChargesTotal < 0 ? 0 : _subTotal + _extraChargesTotal) * (_gstRate / 100)) : 0.0;
  double get _grandTotal => (_subTotal + _extraChargesTotal + _taxAmount) < 0 ? 0 : (_subTotal + _extraChargesTotal + _taxAmount);

  Future<void> _generateAndPrintOrShareInvoice({required bool isWhatsApp}) async {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _cartItems.isEmpty) return;

    await PdfHelper.generateAndPrintOrShare(
      title: _transactionType == 'Sales' ? 'TAX INVOICE' : 'SALES RETURN INVOICE',
      voucherNoKey: 'Invoice No',
      voucherNoValue: _invoiceNoController.text,
      date: _dateController.text,
      partyLabel: 'Bill To',
      partyName: partyName,
      items: _cartItems,
      subTotal: _subTotal,
      extraCharges: _appliedExtraChargesList.map((e) => {'name': e['name'], 'rate': (e['qty'] as double) * (e['rate'] as double)}).toList(),
      taxAmount: _taxAmount,
      grandTotal: _grandTotal,
      isGstActive: _isGstActive,
      companyGstin: _companyGstin,
      gstRate: _gstRate,
      isShare: isWhatsApp,
    );
  }

  Future<void> _saveSalesTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill party and items!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      final txn = AccountingTransaction()
        ..date = _selectedDate
        ..voucherType = _transactionType
        ..voucherNumber = _invoiceNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = _transactionType;
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double qty = (cartItem['qty'] as int).toDouble();
        final invItem = await DatabaseHelper.isar.inventoryItems.filter().itemNameEqualTo(prodName, caseSensitive: false).findFirst();
        if (invItem != null) {
          if (_transactionType == 'Sales') {
            invItem.stockQuantity -= qty;
            if (invItem.stockQuantity < 0) invItem.stockQuantity = 0;
          } else {
            invItem.stockQuantity += qty; 
          }
          await DatabaseHelper.isar.inventoryItems.put(invItem);
        }
      }

      if (widget.initialOrder != null) {
        widget.initialOrder!.status = 'Completed';
        await DatabaseHelper.isar.salesOrders.put(widget.initialOrder!);
      }
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.teal, size: 24),
            SizedBox(width: 8),
            Text('Bill Saved Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Choose an option below to share or print your bill:', style: TextStyle(fontSize: 12)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, minimumSize: const Size(90, 32)),
            icon: const Icon(Icons.share, size: 14),
            label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: true);
              widget.onBack();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, minimumSize: const Size(80, 32)),
            icon: const Icon(Icons.print, size: 14),
            label: const Text('Print', style: TextStyle(fontSize: 11)),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: false);
              widget.onBack();
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onBack();
            },
            child: const Text('Close', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialOrder != null ? 'Generate Bill' : 'New $_transactionType Bill'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
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
                    child: DropdownButtonFormField<String>(
                      value: _transactionType,
                      items: _transactionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _transactionType = val!;
                          _updateInvoiceNumberPrefix();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _invoiceNoController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(labelText: 'Invoice No', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.black12, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
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
                      items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11)))).toList(),
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
                    onSubmitted: (_) => _partyFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: RawAutocomplete<Account>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return _allAccountsList;
                        return _allAccountsList.where((acc) => acc.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (Account option) => option.name,
                      onSelected: (Account selection) {
                        _partyController.text = selection.name;
                        _searchFocusNode.requestFocus();
                      },
                      textEditingController: _partyController,
                      focusNode: _partyFocusNode,
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
                          onSubmitted: (_) => _searchFocusNode.requestFocus(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: SizedBox(
                              width: 300,
                              height: 180,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return ListTile(
                                      tileColor: Colors.teal.shade50,
                                      leading: const Icon(Icons.person_add, color: Colors.teal, size: 16),
                                      title: const Text('+ Add New Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                                      onTap: _navigateToAddNewParty,
                                    );
                                  }
                                  final acc = options.elementAt(index - 1);
                                  return ListTile(
                                    dense: true,
                                    title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

            // Cart Items List & Inline Search
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ...List.generate(_cartItems.length, (index) {
                    final item = _cartItems[index];
                    double total = (item['qty'] as int) * (item['price'] as double);
                    return ListTile(
                      dense: true,
                      title: Text('${item['name']} (Qty: ${item['qty']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                    );
                  }),
                  const SizedBox(height: 10),
                  
                  if (_selectedInlineProduct == null)
                    RawAutocomplete<InventoryItem>(
                      optionsBuilder: (textValue) {
                        if (textValue.text.isEmpty) return _allInventoryItems;
                        return _allInventoryItems.where((i) => i.itemName.toLowerCase().contains(textValue.text.toLowerCase()));
                      },
                      displayStringForOption: (item) => item.itemName,
                      onSelected: (item) {
                        setState(() {
                          _selectedInlineProduct = item;
                          _inlinePriceController.text = item.priceA.toString();
                        });
                        _qtyFocusNode.requestFocus();
                      },
                      textEditingController: _inlineSearchController,
                      focusNode: _searchFocusNode,
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: 'Search Product to add...', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.search, size: 16)),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: SizedBox(
                              width: 250,
                              height: 150,
                              child: ListView.builder(
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final opt = options.elementAt(index);
                                  return ListTile(dense: true, title: Text(opt.itemName, style: const TextStyle(fontSize: 11)), onTap: () => onSelected(opt));
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
                          child: Text(_selectedInlineProduct!.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
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
                            onSubmitted: (_) => _priceFocusNode.requestFocus(),
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
                            onSubmitted: (_) => _addInlineItemToCart(),
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
            const Divider(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                ElevatedButton(
                  focusNode: _saveButtonFocusNode,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                  onPressed: _saveSalesTransaction,
                  child: const Text('Save Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
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
