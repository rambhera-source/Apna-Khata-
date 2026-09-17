import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/screens/searchable_field.dart';

class ReceiptVoucherScreen extends StatefulWidget {
  const ReceiptVoucherScreen({super.key});

  @override
  State<ReceiptVoucherScreen> createState() => _ReceiptVoucherScreenState();
}

class _ReceiptVoucherScreenState extends State<ReceiptVoucherScreen> {
  DateTime _selectedDate = DateTime.now();
  String _voucherNumber = '';

  final List<Map<String, dynamic>> _creditRows = [];
  final List<Map<String, dynamic>> _debitRows = [];

  final TextEditingController _notesController = TextEditingController();
  
  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _narrationFocusNode = FocusNode();
  final FocusNode _saveButtonFocusNode = FocusNode();

  List<String> _allAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _generateVoucherNumber();
    _initDefaultRows();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
  }

  void _generateVoucherNumber() {
    _voucherNumber = 'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {});
  }

  void _initDefaultRows() {
    _creditRows.clear();
    _debitRows.clear();

    _creditRows.add({
      'accountController': TextEditingController(),
      'amountController': TextEditingController(),
    });
    _debitRows.add({
      'accountController': TextEditingController(text: 'Cash-in-Hand'),
      'amountController': TextEditingController(),
    });
  }

  Future<void> _loadAccounts() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  double get _totalCredit {
    double total = 0.0;
    for (var row in _creditRows) {
      total += double.tryParse(row['amountController'].text) ?? 0.0;
    }
    return total;
  }

  double get _totalDebit {
    double total = 0.0;
    for (var row in _debitRows) {
      total += double.tryParse(row['amountController'].text) ?? 0.0;
    }
    return total;
  }

  void _addCreditRow() {
    setState(() {
      _creditRows.add({
        'accountController': TextEditingController(),
        'amountController': TextEditingController(),
      });
    });
  }

  void _addDebitRowWithRemaining() {
    double diff = _totalCredit - _totalDebit;
    if (diff > 0) {
      setState(() {
        _debitRows.add({
          'accountController': TextEditingController(text: 'Cash-in-Hand'),
          'amountController': TextEditingController(text: diff.toStringAsFixed(2)),
        });
      });
    }
  }

  Future<void> _saveReceiptVoucher() async {
    double crTotal = _totalCredit;
    double drTotal = _totalDebit;

    if (crTotal <= 0 || drTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid Credit and Debit amounts!'), backgroundColor: Colors.red),
      );
      return;
    }

    if ((crTotal - drTotal).abs() > 0.01) {
      _addDebitRowWithRemaining();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remaining amount automatically adjusted in Debit row.'), backgroundColor: Colors.orange),
      );
      return;
    }

    List<String> crListDesc = [];
    for (var r in _creditRows) {
      String acc = r['accountController'].text.trim();
      String amt = r['amountController'].text.trim();
      if (acc.isNotEmpty && amt.isNotEmpty) crListDesc.add('$acc (₹$amt)');
    }

    List<String> drListDesc = [];
    for (var r in _debitRows) {
      String acc = r['accountController'].text.trim();
      String amt = r['amountController'].text.trim();
      if (acc.isNotEmpty && amt.isNotEmpty) drListDesc.add('$acc (₹$amt)');
    }

    String partySummary = 'Cr: [${crListDesc.join(", ")}] | Dr: [${drListDesc.join(", ")}]';
    String sourceSummary = _debitRows.first['accountController'].text.trim();
    if (sourceSummary.isEmpty) sourceSummary = 'Cash-in-Hand';

    String notes = _notesController.text.trim();

    await DatabaseHelper.isar.writeTxn(() async {
      // Save Credit transactions (Negative amount to reduce/credit party balance)
      for (var r in _creditRows) {
        String accName = r['accountController'].text.trim();
        double amt = double.tryParse(r['amountController'].text) ?? 0.0;
        if (accName.isNotEmpty && amt > 0) {
          final txn = AccountingTransaction()
            ..voucherType = 'Receipt'
            ..voucherNumber = _voucherNumber
            ..date = _selectedDate
            ..partyName = accName
            ..cashOrBank = sourceSummary
            ..amount = -amt
            ..notes = notes.isEmpty ? partySummary : '$notes [$partySummary]';
          await DatabaseHelper.isar.accountingTransactions.put(txn);
        }
      }

      // Save Debit transactions (Positive amount to increase Cash/Bank balance)
      for (var r in _debitRows) {
        String accName = r['accountController'].text.trim();
        double amt = double.tryParse(r['amountController'].text) ?? 0.0;
        if (accName.isNotEmpty && amt > 0) {
          final txn = AccountingTransaction()
            ..voucherType = 'Receipt'
            ..voucherNumber = _voucherNumber
            ..date = _selectedDate
            ..partyName = accName
            ..cashOrBank = sourceSummary
            ..amount = amt
            ..notes = notes.isEmpty ? partySummary : '$notes [$partySummary]';
          await DatabaseHelper.isar.accountingTransactions.put(txn);
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
            Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
            SizedBox(width: 10),
            Text('Voucher Saved Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Receipt Voucher ($_voucherNumber) has been saved successfully.', style: const TextStyle(fontSize: 13)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notesController.clear();
                _generateVoucherNumber();
                _initDefaultRows();
              });
            },
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _dateFocusNode.dispose();
    _narrationFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    for (var r in _creditRows) {
      r['accountController'].dispose();
      r['amountController'].dispose();
    }
    for (var r in _debitRows) {
      r['accountController'].dispose();
      r['amountController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Voucher Entry'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        focusNode: _dateFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Voucher Date',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        child: Text(
                          DateFormat('dd-MM-yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(text: _voucherNumber),
                      decoration: const InputDecoration(
                        labelText: 'Voucher No (Auto)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.confirmation_number, size: 18),
                        filled: true,
                        fillColor: Colors.black12,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Credit Section (Cr) - Party
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Credit Accounts (Cr - Party):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    icon: const Icon(Icons.add_circle, size: 16, color: Colors.green),
                    label: const Text('Add Cr Row', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    onPressed: _addCreditRow,
                  ),
                ],
              ),
              ...List.generate(_creditRows.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchableField(
                          label: 'Credit Account #${index + 1} *',
                          items: _allAccounts,
                          controller: _creditRows[index]['accountController'],
                          onSelected: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _creditRows[index]['amountController'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          onChanged: (_) => setState(() {
                            if ((_totalCredit - _totalDebit).abs() <= 0.01 && _totalCredit > 0) {
                              FocusScope.of(context).requestFocus(_narrationFocusNode);
                            }
                          }),
                        ),
                      ),
                      if (_creditRows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _creditRows.removeAt(index)),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Debit Section (Dr - Source Cash/Bank)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Debit Accounts (Dr - Source):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    icon: const Icon(Icons.add_circle, size: 16, color: Colors.red),
                    label: const Text('Add Dr Row', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                    onPressed: _addDebitRowWithRemaining,
                  ),
                ],
              ),
              ...List.generate(_debitRows.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchableField(
                          label: 'Debit Account #${index + 1} *',
                          items: _allAccounts,
                          controller: _debitRows[index]['accountController'],
                          onSelected: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _debitRows[index]['amountController'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          onChanged: (_) => setState(() {
                            if ((_totalCredit - _totalDebit).abs() <= 0.01 && _totalCredit > 0) {
                              FocusScope.of(context).requestFocus(_narrationFocusNode);
                            }
                          }),
                        ),
                      ),
                      if (_debitRows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _debitRows.removeAt(index)),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_totalCredit == _totalDebit && _totalCredit > 0) ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (_totalCredit == _totalDebit && _totalCredit > 0) ? Colors.green.shade300 : Colors.red.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Cr: ₹${_totalCredit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                    Text('Total Dr: ₹${_totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _notesController,
                focusNode: _narrationFocusNode,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Narration / Remarks (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.note, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_saveButtonFocusNode);
                },
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  focusNode: _saveButtonFocusNode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saveReceiptVoucher,
                  child: const Text('Save Receipt Voucher', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
