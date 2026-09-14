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
import 'searchable_field.dart';
import 'product_inventory_screen.dart'; // Inventory view shortcut ke liye

class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key});

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _returnNoController = TextEditingController(text: 'PR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  List<String> _allAccounts = [];
  List<Product> _allProducts = [];
  final List<Map<String, dynamic>> _returnItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final products = await DatabaseHelper.isar.products.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allProducts = products;
    });
  }

  // 📦 Open ProductInventoryScreen (Sirf view/check karne ke liye)
  void _navigateToInventoryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductInventoryScreen()),
    );
    await _loadData();
  }

  // 🛒 Add Existing Item to Return List
  void _addItem() {
    if (_allProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory mein koi product uplabdh nahi hai!'), backgroundColor: Colors.red),
      );
      return;
    }

    Product selectedProduct = _allProducts.first;
    final TextEditingController qtyController = TextEditingController(text: '1');
    final TextEditingController priceController = TextEditingController(text: selectedProduct.sellingPrice.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Purchase Return Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: _allProducts.contains(selectedProduct) ? selectedProduct : _allProducts.first,
                items: _allProducts.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stock})'))).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedProduct = val!;
                    priceController.text = selectedProduct.sellingPrice.toString();
                  });
                },
                decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Return Qty', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Return Rate (₹)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                int q = int.tryParse(qtyController.text) ?? 1;
                double p = double.tryParse(priceController.text) ?? selectedProduct.sellingPrice;
                setState(() {
                  _returnItems.add({
                    'name': selectedProduct.name,
                    'qty': q,
                    'price': p,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  double get _returnTotal => _returnItems.fold(0.0, (sum, i) => sum + ((i['qty'] as int) * (i['price'] as double)));

  Future<void> _generateAndPrintOrShareReturn({required bool isWhatsApp}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('DEBIT NOTE / PURCHASE RETURN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.redAccent)),
            pw.SizedBox(height: 10),
            pw.Text('Return No: ${_returnNoController.text} | Supplier: ${_supplierController.text}'),
            pw.SizedBox(height: 15),
            pw.Table.fromTextArray(
              headers: ['Item', 'Qty', 'Price', 'Total'],
              data: _returnItems.map((i) => [i['name'], '${i['qty']}', '${i['price']}', '${(i['qty'] as int) * (i['price'] as double)}']).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Return Total: ₹ $_returnTotal', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );

    if (isWhatsApp) {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/PurchaseReturn_${_returnNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Purchase Return / Debit Note #${_returnNoController.text}. Total: ₹ $_returnTotal');
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  }

  Future<void> _saveReturn() async {
    if (_supplierController.text.isEmpty || _returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Supplier aur Return Items select karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    final txn = AccountingTransaction()
      ..date = DateTime.now()
      ..voucherType = 'Purchase Return'
      ..voucherNumber = _returnNoController.text
      ..partyName = _supplierController.text.trim()
      ..cashOrBank = 'Debit Note'
      ..amount = _returnTotal
      ..notes = 'Purchase Return generated via ORLIFE ERP';

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accountingTransactions.put(txn);
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Return Saved!'),
        content: const Text('Kya aap is return note ka print lena chahte hain ya share karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareReturn(isWhatsApp: false);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('WhatsApp'),
            onPressed: () {
              Navigator.pop(context);
              _generateAndPrintOrShareReturn(isWhatsApp: true);
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
        title: const Text('Purchase Return (Debit Note)'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            onPressed: _navigateToInventoryScreen,
            tooltip: 'View Inventory',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Supplier Selection (Existing Accounts Only)
            SearchableField(
              label: 'Supplier / Vendor Name *',
              items: _allAccounts,
              controller: _supplierController,
              onSelected: (v) {},
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Return Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: _addItem, 
                  icon: const Icon(Icons.add, size: 16), 
                  label: const Text('Add Return Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _returnItems.isEmpty
                  ? const Center(child: Text('Koi return item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _returnItems.length,
                      itemBuilder: (context, index) {
                        final item = _returnItems[index];
                        double total = (item['qty'] as int) * (item['price'] as double);
                        return Card(
                          child: ListTile(
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Qty: ${item['qty']} | Rate: ₹ ${item['price']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                  onPressed: () => setState(() => _returnItems.removeAt(index)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total Return: ₹ $_returnTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, 
              height: 48, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), 
                onPressed: _saveReturn, 
                child: const Text('Save Return Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
