import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import 'searchable_field.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _accountController = TextEditingController();
  List<String> _allAccounts = [];
  List<AccountingTransaction> _ledgerTransactions = [];
  
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  double _currentBalance = 0.0;
  bool _isLoading = false;
  bool _isReportLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAccountNames();
  }

  Future<void> _loadAccountNames() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
    });
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Future<void> _generateLedgerReport() async {
    final accountName = _accountController.text.trim();
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya pehle koi Account ya Party select karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final accountObj = await DatabaseHelper.isar.accounts
        .filter()
        .nameEqualTo(accountName)
        .findFirst();

    _currentBalance = accountObj?.balance ?? 0.0;

    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    final txns = await DatabaseHelper.isar.accountingTransactions
        .filter()
        .dateBetween(startDateTime, endDateTime)
        .and()
        .-(
          (q) => q.partyNameContains(accountName, caseSensitive: false).or().cashOrBankEqualTo(accountName)
        )
        .sortByDateDesc()
        .findAll();

    setState(() {
      _ledgerTransactions = txns;
      _isLoading = false;
      _isReportLoaded = true;
    });
  }

  // ================= 1. EXPORT TO EXCEL FUNCTION =================
  Future<void> _exportToExcel() async {
    if (_ledgerTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export ke liye koi data nahi hai!')));
      return;
    }

    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['Ledger Statement'];
    excel.setDefaultSheet('Ledger Statement');

    // Header Row
    sheetObject.appendRow([
      excel_lib.TextCellValue('Date'),
      excel_lib.TextCellValue('Voucher Type'),
      excel_lib.TextCellValue('Voucher No'),
      excel_lib.TextCellValue('Party / Mode'),
      excel_lib.TextCellValue('Amount (INR)'),
      excel_lib.TextCellValue('Notes')
    ]);

    // Data Rows
    for (var txn in _ledgerTransactions) {
      sheetObject.appendRow([
        excel_lib.TextCellValue(DateFormat('dd-MM-yyyy').format(txn.date)),
        excel_lib.TextCellValue(txn.voucherType),
        excel_lib.TextCellValue(txn.voucherNumber),
        excel_lib.TextCellValue(txn.cashOrBank),
        excel_lib.DoubleCellValue(txn.amount),
        excel_lib.TextCellValue(txn.notes ?? ''),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Ledger_${_accountController.text.trim()}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    // Share via WhatsApp / File system
    await Share.shareXFiles([XFile(filePath)], text: 'Ledger Statement for ${_accountController.text.trim()} (ORLIFE ERP)');
  }

  // ================= 2. GENERATE & DOWNLOAD / SHARE PDF FUNCTION =================
  Future<void> _downloadOrSharePdf() async {
    if (_ledgerTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF ke liye koi data nahi hai!')));
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Account Ledger Statement', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Account Name: ${_accountController.text}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}'),
          pw.Text('Current Balance: Rs. ${_currentBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Voucher No', 'Mode', 'Amount'],
            data: _ledgerTransactions.map((txn) => [
              DateFormat('dd-MM-yyyy').format(txn.date),
              txn.voucherType,
              txn.voucherNumber,
              txn.cashOrBank,
              'Rs. ${txn.amount.toStringAsFixed(2)}',
            ]).toList(),
          ),
        ],
      ),
    );

    // Save PDF to temp and share / print
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Ledger_${_accountController.text.trim()}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share via WhatsApp or other apps
    await Share.shareXFiles([XFile(file.path)], text: 'Ledger Statement PDF - ${_accountController.text.trim()}');
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account / Party Ledger Statement'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_isReportLoaded) ...[
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'Export & Share Excel',
              onPressed: _exportToExcel,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Download & Share PDF',
              onPressed: _downloadOrSharePdf,
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchableField(
              label: 'Select Party, Customer, Supplier or Bank *',
              items: _allAccounts,
              controller: _accountController,
              onSelected: (selectedAccount) {},
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectFromDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'From Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month, size: 20)),
                      child: Text(DateFormat('dd-MM-yyyy').format(_fromDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectToDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'To Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month, size: 20)),
                      child: Text(DateFormat('dd-MM-yyyy').format(_toDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: _generateLedgerReport,
              child: const Text('OK / View Ledger Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            if (_isReportLoaded) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.indigo.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Ledger: ${_accountController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo))),
                    Text('Net Balance: ₹ ${_currentBalance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _currentBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transactions in Selected Date Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, isDense: true),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('WhatsApp PDF'),
                        onPressed: _downloadOrSharePdf,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, isDense: true),
                        icon: const Icon(Icons.table_view, size: 16),
                        label: const Text('Excel'),
                        onPressed: _exportToExcel,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ledgerTransactions.isEmpty
                        ? const Center(child: Text('Is date range mein koi transaction nahi mili.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _ledgerTransactions.length,
                            itemBuilder: (context, index) {
                              final txn = _ledgerTransactions[index];
                              bool isPayment = txn.voucherType == 'Payment';
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isPayment ? Colors.red.shade100 : Colors.green.shade100,
                                    child: Icon(isPayment ? Icons.arrow_upward : Icons.arrow_downward, color: isPayment ? Colors.red : Colors.green),
                                  ),
                                  title: Text('${txn.voucherType} (${txn.voucherNumber})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}\nMode: ${txn.cashOrBank}\nNotes: ${txn.notes ?? "N/A"}'),
                                  isThreeLine: true,
                                  trailing: Text('₹ ${txn.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPayment ? Colors.red : Colors.green)),
                                ),
                              );
                            },
                          ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('Kripya Account chun kar, Date range set karein aur "OK" dabayein.', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
