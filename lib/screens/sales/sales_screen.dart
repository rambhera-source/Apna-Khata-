import 'dart:io';
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
import 'package:accounting_app/screens/searchable_field.dart'; // ✅ Correct package import
import 'package:accounting_app/screens/account/add_account_screen.dart';        

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController(text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  final TextEditingController _freightController = TextEditingController(text: '0');
  final TextEditingController _discountValueController = TextEditingController(text: '0');
  String _discountType = '₹';

  DateTime _selectedDate = DateTime.now();

  List<String> _allAccounts = [];
  List<InventoryItem> _allInventoryItems = [];
  
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  String _globalStockType = 'Fresh';

  bool _isGstActive = false;
  String _companyGstin = '';

  List<SalesOrder> _pendingOrdersList = [];
  SalesOrder? _selectedPendingOrder;
  bool _isLoadingOrder = false;

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

    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allInventoryItems = inventoryItems;
      if (settings != null) {
        _isGstActive = settings.isGstEnabled;
        _companyGstin = settings.gstin ?? '';
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
      _checkForPendingOrders(newPartyName);
    }
  }

  Future<void> _checkForPendingOrders(String partyName) async {
    if (partyName.isEmpty) return;

    setState(() => _isLoadingOrder = true);

    final orders = await DatabaseHelper.isar.salesOrders
        .filter()
        .partyNameEqualTo(partyName, caseSensitive: false)
        .and()
        .statusEqualTo('Pending')
        .findAll();

    setState(() {
      _pendingOrdersList = orders;
      _selectedPendingOrder = orders.isNotEmpty ? orders.first : null;
      _isLoadingOrder = false;
    });

    if (orders.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${orders.length} Pending Order(s) found for $partyName!'),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadSpecificOrderIntoBill(SalesOrder order) async {
    await order.items.load();

    setState(() {
      _selectedPendingOrder = order;
      _cartItems.clear();
      for (var item in order.items) {
        if (!item.isDelivered) {
          _cartItems.add({
            'name': item.productName,
            'sku': '-',
            'qty': item.qty,
            'price': item.price,
            'stockType': _globalStockType,
          });
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ${order.orderNo} successfully loaded into bill!'), backgroundColor: Colors.green),
    );
  }

  void _showSelectOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Pending Order to Load'),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pendingOrdersList.length,
            itemBuilder: (context, index) {
              final ord = _pendingOrdersList[index];
              return Card(
                child: ListTile(
                  title: Text('Order No: ${ord.orderNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Date: ${DateFormat('dd-MM-yyyy').format(ord.date)}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () {
                      Navigator.pop(context);
                      _loadSpecificOrderIntoBill(ord);
                    },
                    child: const Text('Load'),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _addItemToCart() {
    if (_allInventoryItems.isEmpty) {
      return;
    }

    InventoryItem selectedItem = _allInventoryItems.first;
    final TextEditingController qtyController = TextEditingController(text: '1');
    final TextEditingController priceController = TextEditingController(text: selectedItem.priceA.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Item to Bill'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<InventoryItem>(
                    value: selectedItem,
                    items: _allInventoryItems.map((p) => DropdownMenuItem(value: p, child: Text('${p.itemName} (SKU: ${p.sku ?? "-"})'))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedItem = val!;
                        priceController.text = selectedItem.priceA.toString();
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
                    decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    int q = int.tryParse(qtyController.text) ?? 1;
                    double pr = double.tryParse(priceController.text) ?? selectedItem.priceA;
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

  double get _subTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  double get _freightAmount {
    return double.tryParse(_freightController.text) ?? 0.0;
  }

  double get _discountAmount {
    double val = double.tryParse(_discountValueController.text) ?? 0.0;
    if (_discountType == '%') {
      return (_subTotal * val) / 100;
    }
    return val;
  }

  double get _taxAmount {
    if (!_isGstActive) return 0.0;
    double taxableValue = _subTotal - _discountAmount + _freightAmount;
    if (taxableValue < 0) taxableValue = 0;
    return taxableValue * 0.18;
  }

  double get _grandTotal {
    double total = _subTotal - _discountAmount + _freightAmount + _taxAmount;
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
                      pw.Text('Stock Type: $_globalStockType', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
              pw.SizedBox(height: 10),
              pw.Text('Bill To:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Party Name: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                        if (_discountAmount > 0) pw.Text('Discount: - ₹ ${_discountAmount.toStringAsFixed(2)}'),
                        if (_freightAmount > 0) pw.Text('Freight: + ₹ ${_freightAmount.toStringAsFixed(2)}'),
                        if (_isGstActive) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('CGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                          pw.Text('SGST (9%): ₹ ${(_taxAmount / 2).toStringAsFixed(2)}'),
                        ],
                        pw.Divider(),
                        pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('₹ ${_grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Invoice #${_invoiceNoController.text} from ORLIFE. Total: ₹ $_grandTotal');
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
        ..notes = _isGstActive ? 'GST Sales Invoice ([$_globalStockType Stock])' : 'Sales Invoice ([$_globalStockType Stock])';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      for (var cartItem in _cartItems) {
        String prodName = cartItem['name'];
        double soldQty = (cartItem['qty'] as int).toDouble();
        String itemStockType = cartItem['stockType'] ?? 'Fresh';

        final invItem = await DatabaseHelper.isar.inventoryItems
            .filter()
            .itemNameEqualTo(prodName, caseSensitive: false)
            .findFirst();

        if (invItem != null) {
          invItem.stockQuantity -= soldQty;
          if (invItem.stockQuantity < 0) invItem.stockQuantity = 0;
          invItem.stockType = itemStockType;
          await DatabaseHelper.isar.inventoryItems.put(invItem);
        }
      }

      if (_selectedPendingOrder != null) {
        await _selectedPendingOrder!.items.load();
        
        bool allDelivered = true;
        for (var orderItem in _selectedPendingOrder!.items) {
          var cartMatch = _cartItems.any((c) => c['name'] == orderItem.productName && c['qty'] >= orderItem.qty);
          if (cartMatch) {
            orderItem.isDelivered = true;
          } else {
            allDelivered = false;
          }
          await DatabaseHelper.isar.orderItemModels.put(orderItem);
        }

        if (allDelivered) {
          _selectedPendingOrder!.status = 'Converted to Bill';
        } else {
          _selectedPendingOrder!.status = 'Pending (Partial)';
        }
        await DatabaseHelper.isar.salesOrders.put(_selectedPendingOrder!);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Bill Successfully Saved & Stock Updated!'), backgroundColor: Colors.green));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill Saved Successfully!'),
        content: const Text('Kya aap is bill ka print lena chahte hain ya WhatsApp par share karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: false);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('WhatsApp'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareInvoice(isWhatsApp: true);
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
        title: Text(_isGstActive ? 'Sales Invoice (GST Mode)' : 'Sales Invoice (Simple Mode)'),
        backgroundColor: Colors.teal.shade800,
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
                    icon: const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
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
                    controller: _invoiceNoController,
                    decoration: const InputDecoration(labelText: 'Invoice No', border: OutlineInputBorder()),
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
                        content: Text('Stock Source switched to: $_globalStockType'),
                        duration: const Duration(milliseconds: 800),
                        backgroundColor: _globalStockType == 'Fresh' ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: _globalStockType == 'Fresh' ? Colors.green.shade50 : Colors.orange.shade50,
                      border: Border.all(
                        color: _globalStockType == 'Fresh' ? Colors.green : Colors.orange,
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
                          color: _globalStockType == 'Fresh' ? Colors.green.shade800 : Colors.orange.shade900,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _globalStockType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _globalStockType == 'Fresh' ? Colors.green.shade800 : Colors.orange.shade900,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('New'),
                  onPressed: _navigateToAddNewParty,
                ),
              ],
            ),

            if (_pendingOrdersList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _pendingOrdersList.length == 1
                              ? 'Pending Order: ${_pendingOrdersList.first.orderNo}'
                              : '${_pendingOrdersList.length} Pending Orders Found!',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_pendingOrdersList.length > 1) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.amber.shade900, side: BorderSide(color: Colors.amber.shade800)),
                            onPressed: _showSelectOrderDialog,
                            child: const Text('View All'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(_pendingOrdersList.length == 1 ? 'Load Order' : 'Load Latest'),
                          onPressed: () => _loadSpecificOrderIntoBill(_pendingOrdersList.first),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items in Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  onPressed: _addItemToCart,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.teal.shade100,
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
                                child: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.right),
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
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹ ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Freight / Shipping:', style: TextStyle(fontSize: 13)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _freightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_isGstActive) ...[
                    const SizedBox(height: 6),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                onPressed: _saveSalesTransaction,
                child: const Text('Save & Generate Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
