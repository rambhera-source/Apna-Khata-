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

import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import '../searchable_field.dart';

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
  bool _showNarrationAndDetails = true; // Toggle for showing contra details & notes

  // Focus Nodes for Keyboard Navigation
  final FocusNode _accountFocusNode = FocusNode();
  final FocusNode _fromDateFocusNode = FocusNode();
  final FocusNode _toDateFocusNode = FocusNode();
  final FocusNode _listFocusNode = FocusNode();
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountNames();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _accountFocusNode.dispose();
    _fromDateFocusNode.dispose();
    _toDateFocusNode.dispose();
    _listFocusNode.dispose();
    super.dispose();
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
    if (picked != null) {
      setState(() => _fromDate = picked);
      FocusScope.of(context).requestFocus(_toDateFocusNode);
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _generateLedgerReport();
    }
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

    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

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

    double totalAmt = 0.0;
    for (var t in txns) {
      totalAmt += t.amount;
    }

    setState(() {
      _ledgerTransactions = txns;
      _currentBalance = totalAmt;
      _isLoading = false;
      _isReportLoaded = true;
      _focusedIndex = 0;
    });

    FocusScope.of(context).requestFocus(_listFocusNode);
  }

  // Edit Dialog when clicking on any transaction row
  void _openEditTransactionDialog(AccountingTransaction txn) {
    final TextEditingController amountController = TextEditingController(text: txn.amount.toString());
    final TextEditingController notesController = TextEditingController(text: txn.notes ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${txn.voucherType} (${txn.voucherNumber})', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Party: ${txn.partyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Text('Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Narration',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                final newAmount = double.tryParse(amountController.text) ?? txn.amount;
                final newNotes = notesController.text.trim();

                await DatabaseHelper.isar.writeTxn(() async {
                  txn.amount = newAmount;
                  txn.notes = newNotes.isEmpty ? null : newNotes;
                  await DatabaseHelper.isar.accountingTransactions.put(txn);
                });

                Navigator.pop(context);
                _generateLedgerReport();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction successfully updated!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ================= EXCEL EXPORT =================
  Future<void> _exportToExcel() async {
    if (_ledgerTransactions.isEmpty) return;

    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['Ledger Statement'];
    excel.setDefaultSheet('Ledger Statement');

    sheetObject.appendRow([
      excel_lib.TextCellValue('Date'),
      excel_lib.TextCellValue('Bill / Voucher No'),
      excel_lib.TextCellValue('Entry Type'),
      excel_lib.TextCellValue('Party / Account'),
      excel_lib.TextCellValue('Mode / Source'),
      excel_lib.TextCellValue('Amount (INR)'),
      excel_lib.TextCellValue('Notes')
    ]);

    for (var txn in _ledgerTransactions) {
      sheetObject.appendRow([
        excel_lib.TextCellValue(DateFormat('dd-MM-yyyy').format(txn.date)),
        excel_lib.TextCellValue(txn.voucherNumber),
        excel_lib.TextCellValue(txn.voucherType),
        excel_lib.TextCellValue(txn.partyName),
        excel_lib.TextCellValue(txn.cashOrBank),
        excel_lib.DoubleCellValue(txn.amount),
        excel_lib.TextCellValue(txn.notes ?? ''),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Ledger_${_accountController.text.trim()}.xlsx';
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(excel.encode()!);
    if (!mounted) return;
    await Share.shareXFiles([XFile(filePath)], text: 'Ledger Statement for ${_accountController.text.trim()}');
  }

  // ================= PDF SHARE =================
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
                pw.Text('ORLIFE ERP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Ledger Statement', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Account Name: ${_accountController.text}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}'),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Voucher No', 'Type', 'Party Name', 'Mode', 'Amount'],
            data: _ledgerTransactions.map((txn) => [
              DateFormat('dd-MM-yyyy').format(txn.date),
              txn.voucherNumber,
              txn.voucherType,
              txn.partyName,
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

  // ================= DIRECT PRINT =================
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
                pw.Text('ORLIFE ERP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Ledger Statement', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Account Name: ${_accountController.text}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}'),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Voucher No', 'Type', 'Party Name', 'Mode', 'Amount'],
            data: _ledgerTransactions.map((txn) => [
              DateFormat('dd-MM-yyyy').format(txn.date),
              txn.voucherNumber,
              txn.voucherType,
              txn.partyName,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account / Party Ledger Statement', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= COMPACT FILTER SECTION =================
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    SearchableField(
                      label: 'Select Party, Customer, Supplier or Bank *',
                      items: _allAccounts,
                      controller: _accountController,
                      onSelected: (selectedAccount) {
                        FocusScope.of(context).requestFocus(_fromDateFocusNode);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectFromDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'From Date',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_month, size: 16),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              child: Text(DateFormat('dd-MM-yy').format(_fromDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectToDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'To Date',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_month, size: 16),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              child: Text(DateFormat('dd-MM-yy').format(_toDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: _generateLedgerReport,
                            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            if (_isReportLoaded) ...[
              // ================= SUMMARY & TOGGLE BAR =================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Toggle for Narration / Details
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 32,
                          child: Switch(
                            value: _showNarrationAndDetails,
                            activeColor: Colors.indigo,
                            onChanged: (val) => setState(() => _showNarrationAndDetails = val),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Details & Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ],
                    ),
                    // Export Buttons
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.print, size: 18, color: Colors.blueGrey),
                          tooltip: 'Print PDF',
                          onPressed: _printLedger,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.share, size: 18, color: Colors.green),
                          tooltip: 'Share WhatsApp PDF',
                          onPressed: _downloadOrSharePdf,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.table_view, size: 18, color: Colors.teal),
                          tooltip: 'Export Excel',
                          onPressed: _exportToExcel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ================= TRANSACTIONS LIST WITH ARROW NAVIGATION =================
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ledgerTransactions.isEmpty
                        ? const Center(child: Text('Is date range mein koi transaction nahi mili.', style: TextStyle(color: Colors.grey, fontSize: 13)))
                        : Focus(
                            focusNode: _listFocusNode,
                            onKey: (node, event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  setState(() {
                                    if (_focusedIndex < _ledgerTransactions.length - 1) _focusedIndex++;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                  setState(() {
                                    if (_focusedIndex > 0) _focusedIndex--;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                                  if (_ledgerTransactions.isNotEmpty) {
                                    _openEditTransactionDialog(_ledgerTransactions[_focusedIndex]);
                                  }
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: ListView.builder(
                              itemCount: _ledgerTransactions.length,
                              itemBuilder: (context, index) {
                                final txn = _ledgerTransactions[index];
                                final bool isSelected = (index == _focusedIndex);
                                
                                Color badgeColor = Colors.indigo;
                                if (txn.voucherType == 'Sales') badgeColor = Colors.teal;
                                if (txn.voucherType == 'Purchase') badgeColor = Colors.blue;
                                if (txn.voucherType == 'Payment') badgeColor = Colors.red;
                                if (txn.voucherType == 'Receipt') badgeColor = Colors.green;
                                if (txn.voucherType == 'Journal') badgeColor = Colors.purple;

                                return InkWell(
                                  onTap: () {
                                    setState(() => _focusedIndex = index);
                                    _openEditTransactionDialog(txn);
                                  },
                                  child: Card(
                                    elevation: isSelected ? 2 : 1,
                                    color: isSelected ? Colors.indigo.shade50 : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(
                                        color: isSelected ? Colors.indigo : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 3),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Row 1: Date | Voucher Number | Type | Amount
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                DateFormat('dd-MM-yy').format(txn.date),
                                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  '${txn.voucherType}: ${txn.voucherNumber}',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: badgeColor),
                                                ),
                                              ),
                                              Text(
                                                '₹ ${txn.amount.toStringAsFixed(2)}',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: badgeColor),
                                              ),
                                            ],
                                          ),
                                          
                                          // Conditional Details based on Toggle
                                          if (_showNarrationAndDetails) ...[
                                            const Divider(height: 6, thickness: 0.5),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Party: ${txn.partyName}',
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  'Source: ${txn.cashOrBank}',
                                                  style: const TextStyle(color: Colors.black54, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                            if (txn.notes != null && txn.notes!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Note: ${txn.notes}',
                                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 10, color: Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),

              const SizedBox(height: 6),
              // ================= CLOSING BALANCE BANNER =================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CLOSING BALANCE:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      '₹ ${_currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 15, 
                        color: _currentBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('Kripya Account chun kar, Date range set karein aur "OK" dabayein.', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
