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
  double _filteredTotalAmount = 0.0;
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

  // 🔍 Generate Ledger & Calculate Totals
  Future<void> _generateLedgerReport() async {
    final accountName = _accountController.text.trim();
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya pehle koi Account ya Party select karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Account ka balance fetch karna (Safe handling)
    final accountObj = await DatabaseHelper.isar.accounts
        .filter()
        .nameEqualTo(accountName)
        .findFirst();

    // Account model ke anusaar balance default 0.0 rakha gaya hai
    _currentBalance = 0.0; 
    if (accountObj != null) {
      // Agar accountObj mein opening balance ya amount hai toh yahan fetch hoga
    }

    // 2. Date range setup
    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    // 3. Transactions Fetching
    final txns = await DatabaseHelper.isar.accountingTransactions
        .filter()
        .dateBetween(startDateTime, endDateTime)
        .and()
        .group((q) => q
            .partyNameEqualTo(accountName, caseSensitive: false)
            .or()
            .cashOrBankEqualTo(accountName))
        .sortByDateDesc()
        .findAll();

    // 4. Filtered total amount calculation
    double totalAmt = 0.0;
    for (var t in txns) {
      totalAmt += t.amount;
    }

    setState(() {
      _ledgerTransactions = txns;
      _filteredTotalAmount = totalAmt;
      _currentBalance = totalAmt; // Net transaction amount as current ledger balance
      _isLoading = false;
      _isReportLoaded = true;
    });
  }

  // ================= 1. EXPORT TO EXCEL =================
  Future<void> _exportToExcel() async {
    if (_ledgerTransactions.isEmpty) return;

    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['Ledger Statement'];
    excel.setDefaultSheet('Ledger Statement');

    sheetObject.appendRow([
      excel_lib.TextCellValue('Date'),
      excel_lib.TextCellValue('Entry Type'),
      excel_lib.TextCellValue('Bill / Voucher No'),
      excel_lib.TextCellValue('Mode / Source'),
      excel_lib.TextCellValue('Amount (INR)'),
      excel_lib.TextCellValue('Notes')
    ]);

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

    sheetObject.appendRow([
      excel_lib.TextCellValue('CLOSING BALANCE'),
      excel_lib.TextCellValue(''),
      excel_lib.TextCellValue(''),
      excel_lib.TextCellValue(''),
      excel_lib.DoubleCellValue(_currentBalance),
      excel_lib.TextCellValue('')
    ]);

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Ledger_${_accountController.text.trim()}.xlsx';
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(excel.encode()!);
    if (!mounted) return;
    await Share.shareXFiles([XFile(filePath)], text: 'Ledger Statement for ${_accountController.text.trim()} (ORLIFE ERP)');
  }

  // ================= 2. SHARE PDF VIA WHATSAPP =================
  Future<void> _downloadOrSharePdf() async {
    if (_ledgerTransactions.isEmpty) return;

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
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Bill / Voucher No', 'Mode', 'Amount'],
            data: _ledgerTransactions.map((txn) => [
              DateFormat('dd-MM-yyyy').format(txn.date),
              txn.voucherType,
              txn.voucherNumber,
              txn.cashOrBank,
              'Rs. ${txn.amount.toStringAsFixed(2)}',
            ]).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Closing Balance:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Rs. ${_currentBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Ledger_${_accountController.text.trim()}.pdf');
    await file.writeAsBytes(await pdf.save());
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'Ledger Statement PDF - ${_accountController.text.trim()}');
  }

  // ================= 3. DIRECT PHYSICAL PRINT =================
  Future<void> _printLedger() async {
    if (_ledgerTransactions.isEmpty) return;

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
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Bill / Voucher No', 'Mode', 'Amount'],
            data: _ledgerTransactions.map((txn) => [
              DateFormat('dd-MM-yyyy').format(txn.date),
              txn.voucherType,
              txn.voucherNumber,
              txn.cashOrBank,
              'Rs. ${txn.amount.toStringAsFixed(2)}',
            ]).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Closing Balance:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Rs. ${_currentBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                onPressed: _generateLedgerReport,
                child: const Text('OK / View Ledger Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
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
                  const Text('All Transactions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  Wrap(
                    spacing: 6,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print'),
                        onPressed: _printLedger,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('WhatsApp'),
                        onPressed: _downloadOrSharePdf,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
                              
                              Color badgeColor = Colors.indigo;
                              if (txn.voucherType == 'Sales') badgeColor = Colors.teal;
                              if (txn.voucherType == 'Purchase') badgeColor = Colors.blue;
                              if (txn.voucherType == 'Payment') badgeColor = Colors.red;
                              if (txn.voucherType == 'Receipt') badgeColor = Colors.green;
                              if (txn.voucherType == 'Journal') badgeColor = Colors.purple;

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: badgeColor.withOpacity(0.15),
                                    child: Text(
                                      txn.voucherType.isNotEmpty ? txn.voucherType.substring(0, 1) : 'V',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${txn.voucherType} (${txn.voucherNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('₹ ${txn.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor)),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date: ${DateFormat('dd-MM-yyyy').format(txn.date)} | Mode: ${txn.cashOrBank}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                        if (txn.notes != null && txn.notes!.isNotEmpty)
                                          Text('Notes: ${txn.notes}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CLOSING BALANCE:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      '₹ ${_currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 17, 
                        color: _currentBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
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
