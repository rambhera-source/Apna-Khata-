import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/screens/searchable_field.dart';

class JournalVoucherScreen extends StatefulWidget {
  const JournalVoucherScreen({super.key});

  @override
  State<JournalVoucherScreen> createState() => _JournalVoucherScreenState();
}

class _JournalVoucherScreenState extends State<JournalVoucherScreen> {
  DateTime _selectedDate = DateTime.now();
  String _voucherNumber = '';

  final List<Map<String, dynamic>> _voucherRows = [];

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
  }

  void _generateVoucherNumber() {
    _voucherNumber = 'GEN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {});
  }

  void _initDefaultRows() {
    _voucherRows.clear();
    _voucherRows.add({
      'type': 'Dr',
      'accountController': TextEditingController(),
      'amountController': TextEditingController(),
    });
    _voucherRows.add({
      'type': 'Cr',
      'accountController': TextEditingController(),
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

  double get _totalDebit {
    double total = 0.0;
    for (var row in _voucherRows) {
      if (row['type'] == 'Dr') {
        total += double.tryParse(row['amountController'].text) ?? 0.0;
      }
    }
    return total;
  }

  double get _totalCredit {
    double total = 0.0;
    for (var row in _voucherRows) {
      if (row['type'] == 'Cr') {
        total += double.tryParse(row['amountController'].text) ?? 0.0;
      }
    }
    return total;
  }

  void _addRow() {
    setState(() {
      _voucherRows.add({
        'type': 'Dr',
        'accountController': TextEditingController(),
        'amountController': TextEditingController(),
      });
    });
  }

  Future<void> _saveJournalVoucher() async {
    double drTotal = _totalDebit;
    double crTotal = _totalCredit;

    if (drTotal <= 0 || crTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid Debit and Credit amounts!'), backgroundColor: Colors.red),
      );
      return;
    }

    if ((drTotal - crTotal).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mismatch! Total Debit (₹$drTotal) must equal Total Credit (₹$crTotal)'), backgroundColor: Colors.red),
      );
      return;
    }

    List<String> summaryParts = [];
    for (var row in _voucherRows) {
      String type = row['type'];
      String acc = row['accountController'].text.trim();
      String amt = row['amountController'].text.trim();
      if (acc.isNotEmpty && amt.isNotEmpty) {
        summaryParts.add('$type: $acc (₹$amt)');
      }
    }

    String partySummary = summaryParts.join(' | ');
    String notes = _notesController.text.trim();

    await DatabaseHelper.isar.writeTxn(() async {
      for (var row in _voucherRows) {
        String type = row['type'];
        String accName = row['accountController'].text.trim();
        double amt = double.tryParse(row['amountController'].text) ?? 0.0;

        if (accName.isNotEmpty && amt > 0) {
          // Dr adds positive balance, Cr reduces balance with negative amount
          double finalAmount = (type == 'Dr') ? amt : -amt;

          final txn = AccountingTransaction()
            ..voucherType = 'Journal'
            ..voucherNumber = _voucherNumber
            ..date = _selectedDate
            ..partyName = accName
            ..cashOrBank = 'General'
            ..amount = finalAmount
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
        content: Text('Journal Voucher ($_voucherNumber) has been saved successfully.', style: const TextStyle(fontSize: 13)),
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
    for (var row in _voucherRows) {
      row['accountController'].dispose();
      row['amountController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Voucher Entry'),
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Account Entries (Dr / Cr):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text('Add Row', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _addRow,
                  ),
                ],
              ),
              const SizedBox(height: 4),

              ...List.generate(_voucherRows.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _voucherRows[index]['type'],
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Dr', child: Text('Dr')),
                              DropdownMenuItem(value: 'Cr', child: Text('Cr')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _voucherRows[index]['type'] = val!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: SearchableField(
                          label: 'Account Name #${index + 1} *',
                          items: _allAccounts,
                          controller: _voucherRows[index]['accountController'],
                          onSelected: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _voucherRows[index]['amountController'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          onChanged: (_) => setState(() {
                            if ((_totalDebit - _totalCredit).abs() <= 0.01 && _totalDebit > 0) {
                              FocusScope.of(context).requestFocus(_narrationFocusNode);
                            }
                          }),
                        ),
                      ),
                      if (_voucherRows.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _voucherRows.removeAt(index)),
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
                  color: (_totalDebit == _totalCredit && _totalDebit > 0) ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (_totalDebit == _totalCredit && _totalDebit > 0) ? Colors.green.shade300 : Colors.red.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Dr: ₹${_totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                    Text('Total Cr: ₹${_totalCredit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
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
                  onPressed: _saveJournalVoucher,
                  child: const Text('Save Journal Voucher', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
