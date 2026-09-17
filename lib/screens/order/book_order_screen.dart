import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/models/order_model.dart';
import 'package:accounting_app/models/settings_model.dart';
import 'package:accounting_app/models/pdf_helper.dart';
import '../searchable_field.dart';
import '../account/add_account_screen.dart';
import '../products/product_inventory_screen.dart';

class BookOrderScreen extends StatefulWidget {
  const BookOrderScreen({super.key});

  @override
  State<BookOrderScreen> createState() => _BookOrderScreenState();
}

class _BookOrderScreenState extends State<BookOrderScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController(text: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
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
  final FocusNode _freightFocusNode = FocusNode();
  final FocusNode _saveButtonFocusNode = FocusNode();

  List<Map<String, dynamic>> _presetChargesList = [];
  final List<Map<String, dynamic>> _appliedExtraChargesList = [];

  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = [];
  InventoryItem? _selectedInlineProduct;
  final List<Map<String, dynamic>> _orderItems = [];

  bool _isGstActive = false;
  String _companyGstin = '';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
  }

  @override
  void dispose() {
    _partyController.dispose();
    _orderNoController.dispose();
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
    _freightFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

  void _navigateToInventoryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductInventoryScreen()),
    );
    await _loadData();
  }

  void _navigateToAddNewParty() async {
    final String? newPartyName = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
    );

    await _loadData();

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
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
      _partyFocusNode.requestFocus();
    }
  }

  void _addInlineItemToOrder() {
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
      int existingIndex = _orderItems.indexWhere((item) => item['name'] == _selectedInlineProduct!.itemName);

      if (existingIndex != -1) {
        _orderItems[existingIndex]['qty'] = (_orderItems[existingIndex]['qty'] as int) + q;
        _orderItems[existingIndex]['price'] = pr;
      } else {
        _orderItems.add({
          'name': _selectedInlineProduct!.itemName,
          'sku': _selectedInlineProduct!.sku ?? '-',
          'qty': q,
          'price': pr,
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
    return _orderItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
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

  double get _grandTotal {
    double total = _subTotal + _extraChargesTotal;
    return total < 0 ? 0 : total;
  }

  Future<void> _generateAndPrintOrShareOrder({required bool isShare}) async {
    final partyName = _partyController.text.trim();
    if (partyName.isEmpty || _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill party and items!'), backgroundColor: Colors.red));
      return;
    }

    await PdfHelper.generateAndPrintOrShare(
      title: 'SALES ORDER (PENDING)',
      voucherNoKey: 'Order No',
      voucherNoValue: _orderNoController.text,
      date: _dateController.text,
      partyLabel: 'Customer Name',
      partyName: partyName,
      items: _orderItems,
      subTotal: _subTotal,
      extraCharges: _appliedExtraChargesList.map((e) => {'name': e['name'], 'rate': (e['qty'] as double) * (e['rate'] as double)}).toList(),
      taxAmount: 0.0,
      grandTotal: _grandTotal,
      isGstActive: _isGstActive,
      companyGstin: _companyGstin,
      gstRate: 0.0,
      isShare: isShare,
    );
  }

  Future<void> _saveOrder() async {
    if (_partyController.text.isEmpty || _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill party and items!'), backgroundColor: Colors.red));
      return;
    }

    final newOrder = SalesOrder()
      ..orderNo = _orderNoController.text
      ..partyName = _partyController.text.trim()
      ..date = _selectedDate
      ..status = 'Pending';

    List<OrderItemModel> itemModels = [];
    for (var item in _orderItems) {
      final im = OrderItemModel()
        ..productName = item['name']
        ..qty = item['qty']
        ..price = item['price']
        ..isDelivered = false;
      itemModels.add(im);
    }

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.orderItemModels.putAll(itemModels);
      await DatabaseHelper.isar.salesOrders.put(newOrder);
      newOrder.items.addAll(itemModels);
      await newOrder.items.save();
    });

    setState(() {
      _orderItems.clear();
      _orderNoController.text = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _partyController.clear();
      _appliedExtraChargesList.clear();
    });

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Order Booked Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Order has been saved successfully. You can now share or print it.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share PDF'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareOrder(isShare: true);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareOrder(isShare: false);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Book New Order'),
        backgroundColor: Colors.amber.shade900,
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
                      controller: _orderNoController,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(
                        labelText: 'Order No',
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
                          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.amber),
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
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SearchableField(
                      label: 'Customer / Party Name *',
                      items: _allAccounts,
                      controller: _partyController,
                      focusNode: _partyFocusNode,
                      onSelected: (val) {
                        _partyController.text = val;
                        Future.delayed(const Duration(milliseconds: 100), () => _searchFocusNode.requestFocus());
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
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

            const Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),

            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ...List.generate(_orderItems.length, (index) {
                    final item = _orderItems[index];
                    double total = (item['qty'] as int) * (item['price'] as double);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${index + 1}. ${item['name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                  setState(() => _orderItems[index]['qty'] = q);
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
                                  setState(() => _orderItems[index]['price'] = p);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                            onPressed: () => setState(() => _orderItems.removeAt(index)),
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
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedInlineProduct == null)
                          Autocomplete<InventoryItem>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return _allInventoryItems;
                              return _allInventoryItems.where((item) =>
                                item.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                (item.sku != null && item.sku!.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                              );
                            },
                            displayStringForOption: (InventoryItem option) => '${option.itemName} [SKU: ${option.sku ?? "-"}] (Stock: ${option.stockQuantity})',
                            onSelected: (InventoryItem selection) {
                              int existingIndex = _orderItems.indexWhere((item) => item['name'] == selection.itemName);

                              if (existingIndex != -1) {
                                setState(() {
                                  _orderItems[existingIndex]['qty'] = (_orderItems[existingIndex]['qty'] as int) + 1;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${selection.itemName} already in order. Quantity updated!'), duration: const Duration(seconds: 2)),
                                );
                                _inlineSearchController.clear();
                              } else {
                                setState(() {
                                  _selectedInlineProduct = selection;
                                  _inlinePriceController.text = selection.priceA.toString();
                                  _inlineQtyController.text = '1';
                                });
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  _qtyFocusNode.requestFocus();
                                  _inlineQtyController.selection = TextSelection(baseOffset: 0, extentOffset: _inlineQtyController.text.length);
                                });
                              }
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              if (_inlineSearchController.text.isNotEmpty && controller.text.isEmpty) {
                                controller.text = _inlineSearchController.text;
                              }
                              return TextField(
                                controller: controller,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: 'Search Product Name or SKU to add...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  prefixIcon: Icon(Icons.search, size: 16),
                                ),
                                onChanged: (val) => _inlineSearchController.text = val,
                                onSubmitted: (val) {
                                  if (val.trim().isEmpty) {
                                    FocusScope.of(context).requestFocus(_extraChargeFocusNode);
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
                                            tileColor: Colors.amber.shade100,
                                            leading: const Icon(Icons.add_circle, color: Colors.amber, size: 16),
                                            title: const Text('+ Manage Inventory / Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber)),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              _navigateToInventoryScreen();
                                            },
                                          );
                                        }
                                        final item = options.elementAt(index - 1);
                                        return ListTile(
                                          dense: true,
                                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          subtitle: Text('SKU: ${item.sku ?? "-"} | Stock: ${item.stockQuantity} | Price: ₹${item.priceA}', style: const TextStyle(fontSize: 9)),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
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
                                  onSubmitted: (_) => _addInlineItemToOrder(),
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
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
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
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        return _presetChargesList.where((c) => c['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
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
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: _extraChargeFocusNode,
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
                    ),
                  ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
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
                      onPressed: () => _generateAndPrintOrShareOrder(isShare: false),
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
                      label: const Text('Share', style: TextStyle(fontSize: 11)),
                      onPressed: () => _generateAndPrintOrShareOrder(isShare: true),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      focusNode: _saveButtonFocusNode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: _saveOrder,
                      child: const Text('Save Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
