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
import '../models/order_model.dart';
import 'searchable_field.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController(text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  List<String> _allAccounts = [];
  List<Product> _allProducts = [];
  
  // Cart items list: { 'name': String, 'qty': int, 'price': double }
  final List<Map<String, dynamic>> _cartItems = [];
  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Bank / UPI', 'Credit'];

  // Pending Order tracking for selected party
  SalesOrder? _pendingOrder;
  bool _isLoadingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final products = await DatabaseHelper.isar.products.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allProducts = products;
    });
  }

  // 🔍 Party select hote hi check karein ki uska koi Pending Order hai ya nahi
  Future<void> _checkForPendingOrder(String partyName) async {
    if (partyName.isEmpty) return;

    setState(() => _isLoadingOrder = true);

    // Isar se is party ka pending order dhundhein
    final order = await DatabaseHelper.isar.salesOrders
        .filter()
        .partyNameEqualTo(partyName, caseSensitive: false)
        .and()
        .statusEqualTo('Pending')
        .findFirst();

    setState(() {
      _pendingOrder = order;
      _isLoadingOrder = false;
    });

    if (order != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Pending Order found (${order.orderNo}) for $partyName!'),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // 📥 Pending Order items ko bill cart mein load karna
  Future<void> _loadPendingOrderIntoBill() async {
    if (_pendingOrder == null) return;

    await _pendingOrder!.items.load(); // Isar link load karein

    setState(() {
      _cartItems.clear();
      for (var item in _pendingOrder!.items) {
        if (!item.isDelivered) {
          _cartItems.add({
            'name': item.productName,
            'qty': item.qty,
            'price': item.price,
          });
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pending order items successfully loaded into bill!'), backgroundColor: Colors.green),
    );
  }

  void _addItemToCart() {
    if (_allProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle inventory mein products add karein!')));
      return;
    }

    Product selectedProduct = _allProducts.first;
    final TextEditingController qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Item to Sales Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: selectedProduct,
                items: _allProducts.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stock})'))).toList(),
                onChanged: (val) => selectedProduct = val!,
                decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                int q = int.tryParse(qtyController.text) ?? 1;
                setState(() {
                  _cartItems.add({
                    'name': selectedProduct.name,
                    'qty': q,
                    'price': selectedProduct.sellingPrice,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  double get _grandTotal {
    return _cartItems.fold(0.0, (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)));
  }

  // 📄 Professional Sales Invoice PDF & Print / Share Generator
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
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX INVOICE / SALES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                      pw.Text('Invoice No: ${_invoiceNoController.text}'),
                      pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}'),
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
                headers: ['S.No', 'Item Description', 'Qty', 'Price (₹)', 'Total (₹)'],
                data: List.generate(_cartItems.length, (index) {
                  final item = _cartItems[index];
                  double total = (item['qty'] as int) * (item['price'] as double);
                  return [
                    '${index + 1}',
                    item['name'],
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
                    padding: const EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal), borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
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

  // 💾 Save Sales Transaction & Update Pending Order Status / Remaining Items
  Future<void> _saveSalesTransaction() async {
    if (_partyController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Party aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      // 1. Save Accounting Transaction
      final txn = AccountingTransaction()
        ..date = DateTime.now()
        ..voucherType = 'Sales'
        ..voucherNumber = _invoiceNoController.text
        ..partyName = _partyController.text.trim()
        ..cashOrBank = _paymentMode
        ..amount = _grandTotal
        ..notes = 'Sales Invoice generated via ORLIFE ERP';
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      // 2. Agar koi pending order se bill bana hai toh order status update karein
      if (_pendingOrder != null) {
        await _pendingOrder!.items.load();
        
        // Check karein ki saare items deliver ho gaye ya kuch bache hain
        bool allDelivered = true;
        for (var orderItem in _pendingOrder!.items) {
          // Check if item exists in current cart
          var cartMatch = _cartItems.any((c) => c['name'] == orderItem.productName && c['qty'] >= orderItem.qty);
          if (cartMatch) {
            orderItem.isDelivered = true;
          } else {
            allDelivered = false; // Kuch item kam ya remove kiye gaye hain, toh order pending rahega
          }
          await DatabaseHelper.isar.orderItemModels.put(orderItem);
        }

        if (allDelivered) {
          _pendingOrder!.status = 'Converted to Bill';
        } else {
          _pendingOrder!.status = 'Pending (Partial)';
        }
        await DatabaseHelper.isar.salesOrders.put(_pendingOrder!);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Bill Successfully Saved!'), backgroundColor: Colors.green));
    
    // Show Action Dialog for Print / WhatsApp
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
        title: const Text('Sales Invoice (Billing)'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party Selection and Invoice No
            Row(
              children: [
                Expanded(
                  child: SearchableField(
                    label: 'Customer / Party Name *',
                    items: _allAccounts,
                    controller: _partyController,
                    onSelected: (val) {
                      _partyController.text = val;
                      _checkForPendingOrder(val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _invoiceNoController,
                    decoration: const InputDecoration(labelText: 'Invoice No', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),

            // 🔥 PENDING ORDER BANNER (Agar party ka order pending hoga toh yahan dikhega)
            if (_pendingOrder != null) ...[
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
                          'Pending Order Found: ${_pendingOrder!.orderNo} (${DateFormat('dd-MM-yyyy').format(_pendingOrder!.date)})',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, isDense: true),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Load Order'),
                      onPressed: _loadPendingOrderIntoBill,
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
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(child: Text('Koi item add nahi kiya gaya hai. Party select karein ya order load karein.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        double total = (item['qty'] as int) * (item['price'] as double);
                        return Card(
                          child: ListTile(
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Qty: ${item['qty']} | Price: ₹ ${item['price']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () {
                                    // Item remove karne par order mein pending rehta hai
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _paymentMode,
                    items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setState(() => _paymentMode = val!),
                    decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Text('Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
              onPressed: _saveSalesTransaction,
              child: const Text('Save & Generate Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
