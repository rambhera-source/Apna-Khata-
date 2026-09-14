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

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _returnNoController = TextEditingController(text: 'SR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
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

  void _addItem() {
    if (_allProducts.isEmpty) return;
    Product selectedProduct = _allProducts.first;
    final TextEditingController qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Return Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selectedProduct,
              items: _allProducts.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (val) => selectedProduct = val!,
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Return Qty', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int q = int.tryParse(qtyController.text) ?? 1;
              setState(() {
                _returnItems.add({'name': selectedProduct.name, 'qty': q, 'price': selectedProduct.sellingPrice});
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
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
            pw.Text('CREDIT NOTE / SALES RETURN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
            pw.SizedBox(height: 10),
            pw.Text('Return No: ${_returnNoController.text} | Party: ${_partyController.text}'),
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
      final file = File('${output.path}/Return_${_returnNoController.text}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Return / Credit Note #${_returnNoController.text}. Total: ₹ $_returnTotal');
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  }

  Future<void> _saveReturn() async {
    if (_partyController.text.isEmpty || _returnItems.isEmpty) return;

    final txn = AccountingTransaction()
      ..date = DateTime.now()
      ..voucherType = 'Sales Return'
      ..voucherNumber = _returnNoController.text
      ..partyName = _partyController.text.trim()
      ..cashOrBank = 'Credit Note'
      ..amount = _returnTotal
      ..notes = 'Sales Return generated via ORLIFE ERP';

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accountingTransactions.put(txn);
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sales Return Saved!'),
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
      appBar: AppBar(title: const Text('Sales Return (Credit Note)'), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SearchableField(label: 'Customer / Party Name *', items: _allAccounts, controller: _partyController, onSelected: (v) {}),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Return Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: const Text('Add Return Item')),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _returnItems.length,
                itemBuilder: (context, index) {
                  final item = _returnItems[index];
                  return Card(
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Qty: ${item['qty']} | Price: ${item['price']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _returnItems.removeAt(index))),
                    ),
                  );
                },
              ),
            ),
            Text('Total Return: ₹ $_returnTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, 
              height: 48, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white), 
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
