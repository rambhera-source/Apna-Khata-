import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/screens/searchable_field.dart';

class VoucherEntryScreen extends StatefulWidget {
  const VoucherEntryScreen({super.key});

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  String _voucherType = 'Payment'; // Payment, Receipt, Journal
  DateTime _selectedDate = DateTime.now();
  String _voucherNumber = '';

  // Multi-Row Lists for Accounts & Amounts
  final List<Map<String, dynamic>> _debitRows = [];
  final List<Map<String, dynamic>> _creditRows = [];

  final TextEditingController _notesController = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();

  List<String> _allAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _generateVoucherNumber();
    _initDefaultRows();
  }

  void _generateVoucherNumber() {
    String prefix = 'PMT';
    if (_voucherType == 'Receipt') prefix = 'RCP';
    if (_voucherType == 'Journal') prefix = 'GEN';
    
    _voucherNumber = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {});
  }

  void _initDefaultRows() {
    _debitRows.clear();
    _creditRows.clear();

    if (_voucherType == 'Payment') {
      // Payment: Party is Debit, Source (Cash/Bank) is Credit
      _debitRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
      _creditRows.add({'accountController': TextEditingController(text: 'Cash-in-Hand'), 'amountController': TextEditingController()});
    } else if (_voucherType == 'Receipt') {
      // Receipt: Source (Cash/Bank) is Debit, Party is Credit
      _debitRows.add({'accountController': TextEditingController(text: 'Cash-in-Hand'), 'amountController': TextEditingController()});
      _creditRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
    } else {
      // Journal: Multiple Dr and Cr allowed
      _debitRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
      _creditRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
    }
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
    for (var row in _debitRows) {
      total += double.tryParse(row['amountController'].text) ?? 0.0;
    }
    return total;
  }

  double get _totalCredit {
    double total = 0.0;
    for (var row in _creditRows) {
      total += double.tryParse(row['amountController'].text) ?? 0.0;
    }
    return total;
  }

  void _addDebitRow() {
    setState(() {
      _debitRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
    });
  }

  void _addCreditRow() {
    setState(() {
      _creditRows.add({'accountController': TextEditingController(), 'amountController': TextEditingController()});
    });
  }

  Future<void> _saveVoucher() async {
    double drTotal = _totalDebit;
    double crTotal = _totalCredit;

    if (drTotal <= 0 || crTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya valid Debit aur Credit amount darj karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    if ((drTotal - crTotal).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mismatch! Total Debit (₹$drTotal) must equal Total Credit (₹$crTotal)'), backgroundColor: Colors.red),
      );
      return;
    }

    // Prepare descriptions for database transaction storage
    List<String> drListDesc = [];
    for (var r in _debitRows) {
      String acc = r['accountController'].text.trim();
      String amt = r['amountController'].text.trim();
      if (acc.isNotEmpty && amt.isNotEmpty) drListDesc.add('$acc (₹$amt)');
    }

    List<String> crListDesc = [];
    for (var r in _creditRows) {
      String acc = r['accountController'].text.trim();
      String amt = r['amountController'].text.trim();
      if (acc.isNotEmpty && amt.isNotEmpty) crListDesc.add('$acc (₹$amt)');
    }

    String partySummary = 'Dr: [${drListDesc.join(", ")}] | Cr: [${crListDesc.join(", ")}]';
    String sourceSummary = _voucherType == 'Payment' ? (_creditRows.first['accountController'].text.trim()) : (_debitRows.first['accountController'].text.trim());
    if (sourceSummary.isEmpty) sourceSummary = 'Cash-in-Hand';

    final notes = _notesController.text.trim();

    final txn = AccountingTransaction()
      ..voucherType = _voucherType
      ..voucherNumber = _voucherNumber
      ..date = _selectedDate
      ..partyName = partySummary
      ..cashOrBank = sourceSummary
      ..amount = drTotal
      ..notes = notes.isEmpty ? null : notes;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accountingTransactions.put(txn);
    });

    if (!mounted) return;

    // ✨ Smart & Short Success Popup ("Saved Successfully!")
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
            SizedBox(width: 10),
            Text('Saved Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('$_voucherType Voucher ($_voucherNumber) has been saved.', style: const TextStyle(fontSize: 13)),
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
    _notesFocusNode.dispose();
    for (var r in _debitRows) {
      r['accountController'].dispose();
      r['amountController'].dispose();
    }
    for (var r in _creditRows) {
      r['accountController'].dispose();
      r['amountController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = Colors.teal;
    if (_voucherType == 'Payment') themeColor = Colors.red.shade700;
    if (_voucherType == 'Receipt') themeColor = Colors.green.shade700;
    if (_voucherType == 'Journal') themeColor = Colors.purple.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Voucher Entry ($_voucherType)'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Voucher Type Switcher Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: themeColor.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: themeColor, size: 18),
                    const SizedBox(width: 10),
                    const Text('Voucher Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _voucherType,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          items: const [
                            DropdownMenuItem(value: 'Payment', child: Text('Payment Voucher', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Receipt', child: Text('Receipt Voucher', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Journal', child: Text('Journal / General', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _voucherType = val!;
                              _generateVoucherNumber();
                              _initDefaultRows();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Date & Voucher No
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

              // 🔴 DEBIT SECTION (Dr)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Debit Accounts (Dr):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    icon: const Icon(Icons.add_circle, size: 16, color: Colors.red),
                    label: const Text('Add Dr Row', style: TextStyle(fontSize: 11, color: Colors.red)),
                    onPressed: _addDebitRow,
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
                          onChanged: (_) => setState(() {}),
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
              const SizedBox(height: 10),

              // 🟢 CREDIT SECTION (Cr)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Credit Accounts (Cr):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    icon: const Icon(Icons.add_circle, size: 16, color: Colors.green),
                    label: const Text('Add Cr Row', style: TextStyle(fontSize: 11, color: Colors.green)),
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
                          onChanged: (_) => setState(() {}),
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
              const SizedBox(height: 14),

              // 📊 Totals & Validation Banner
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

              // Remarks / Narration
              TextField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Narration / Remarks (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.note, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saveVoucher,
                  child: Text('Save $_voucherType Entry', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
