import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'searchable_field.dart';

class VoucherEntryScreen extends StatefulWidget {
  const VoucherEntryScreen({super.key});

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  String _voucherType = 'Payment';
  DateTime _selectedDate = DateTime.now();
  String _voucherNumber = '';

  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _debitController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _modeFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  String _paymentMode = 'Cash';
  final List<String> _paymentModes = [
    'Cash', 
    'Bank Transfer (NEFT/RTGS)', 
    'UPI / QR Code', 
    'Cheque', 
    'Third Party Gateway'
  ];

  String _selectedBank = 'HDFC Bank A/c';
  final List<String> _bankList = ['HDFC Bank A/c', 'IDFC First Bank A/c', 'Kotak Bank A/c', 'SBI Current A/c'];

  String _selectedUpiApp = 'PhonePe / Google Pay';
  final List<String> _upiList = ['PhonePe / Google Pay', 'Paytm Business', 'BharatPe QR'];

  String _selectedThirdParty = 'Razorpay Gateway';
  final List<String> _thirdPartyList = ['Razorpay Gateway', 'Cashfree', 'Instamojo'];

  List<String> _allAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _generateVoucherNumber();
  }

  void _generateVoucherNumber() {
    String prefix = 'PMT';
    if (_voucherType == 'Receipt') prefix = 'RCP';
    if (_voucherType == 'Journal') prefix = 'GEN';
    
    _voucherNumber = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {});
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

  Future<void> _saveVoucher() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final notes = _notesController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya valid Amount darj karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    String partyOrAccounts = '';
    String cashOrBankSource = 'Cash-in-Hand';

    if (_voucherType == 'Payment' || _voucherType == 'Receipt') {
      partyOrAccounts = _partyController.text.trim();
      if (partyOrAccounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kripya Party ka naam select karein!'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_paymentMode == 'Cash') {
        cashOrBankSource = 'Cash-in-Hand';
      } else if (_paymentMode.contains('Bank')) {
        cashOrBankSource = _selectedBank;
      } else if (_paymentMode.contains('UPI')) {
        cashOrBankSource = 'UPI: $_selectedUpiApp';
      } else if (_paymentMode == 'Cheque') {
        cashOrBankSource = 'Cheque Payment via $_selectedBank';
      } else {
        cashOrBankSource = 'Third Party: $_selectedThirdParty';
      }

    } else {
      final dr = _debitController.text.trim();
      final cr = _creditController.text.trim();
      if (dr.isEmpty || cr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit aur Credit dono accounts select karein!'), backgroundColor: Colors.red),
        );
        return;
      }
      partyOrAccounts = 'Dr: $dr | Cr: $cr';
      cashOrBankSource = 'Journal Transfer';
    }

    final txn = AccountingTransaction()
      ..voucherType = _voucherType
      ..voucherNumber = _voucherNumber
      ..date = _selectedDate
      ..partyName = partyOrAccounts
      ..cashOrBank = cashOrBankSource
      ..amount = amount
      ..notes = notes.isEmpty ? null : notes;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accountingTransactions.put(txn);

      if (_voucherType == 'Payment' || _voucherType == 'Receipt') {
        final partyAccount = await DatabaseHelper.isar.accounts
            .filter()
            .nameEqualTo(partyOrAccounts)
            .findFirst();

        if (partyAccount != null) {
          await DatabaseHelper.isar.accounts.put(partyAccount);
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_voucherType Voucher ($_voucherNumber) safaltapurvak save ho gaya!'), backgroundColor: Colors.green),
    );

    _partyController.clear();
    _debitController.clear();
    _creditController.clear();
    _amountController.clear();
    _notesController.clear();
    _generateVoucherNumber();
    setState(() {});
  }

  @override
  void dispose() {
    _partyController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _amountFocusNode.dispose();
    _modeFocusNode.dispose();
    _notesFocusNode.dispose();
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
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: themeColor.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Voucher Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _voucherType,
                          items: const [
                            DropdownMenuItem(value: 'Payment', child: Text('Payment (Dr)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Receipt', child: Text('Receipt (Cr)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Journal', child: Text('General / Journal', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _voucherType = val!;
                              _generateVoucherNumber();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Voucher Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(
                          DateFormat('dd-MM-yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(text: _voucherNumber),
                      decoration: const InputDecoration(
                        labelText: 'Voucher No (Auto)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number, size: 20),
                        filled: true,
                        fillColor: Colors.black12,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_voucherType == 'Payment' || _voucherType == 'Receipt') ...[
                SearchableField(
                  label: (_voucherType == 'Payment') ? 'Party Name (Paid To) *' : 'Party Name (Received From) *',
                  items: _allAccounts,
                  controller: _partyController,
                  onSelected: (selectedName) {
                    FocusScope.of(context).requestFocus(_amountFocusNode);
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_rupee),
                    fillColor: themeColor.withOpacity(0.08),
                    filled: true,
                  ),
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_modeFocusNode);
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  focusNode: _modeFocusNode,
                  items: _paymentModes.map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode, style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (val) => setState(() => _paymentMode = val!),
                  decoration: const InputDecoration(
                    labelText: 'Mode of Payment / Receipt *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                ),

                if (_paymentMode.contains('Bank') || _paymentMode == 'Cheque') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBank,
                    items: _bankList.map((bank) {
                      return DropdownMenuItem(value: bank, child: Text(bank));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBank = val!),
                    decoration: const InputDecoration(
                      labelText: 'Select Bank Account *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ] else if (_paymentMode.contains('UPI')) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedUpiApp,
                    items: _upiList.map((upi) {
                      return DropdownMenuItem(value: upi, child: Text(upi));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedUpiApp = val!),
                    decoration: const InputDecoration(
                      labelText: 'Select UPI App / QR *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                ] else if (_paymentMode == 'Third Party Gateway') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedThirdParty,
                    items: _thirdPartyList.map((tp) {
                      return DropdownMenuItem(value: tp, child: Text(tp));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedThirdParty = val!),
                    decoration: const InputDecoration(
                      labelText: 'Select Third Party Portal *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cloud_sync),
                    ),
                  ),
                ],

              ] else ...[
                SearchableField(
                  label: 'Debit Account (Dr) *',
                  items: _allAccounts,
                  controller: _debitController,
                  onSelected: (_) {},
                ),
                const SizedBox(height: 16),
                SearchableField(
                  label: 'Credit Account (Cr) *',
                  items: _allAccounts,
                  controller: _creditController,
                  onSelected: (_) {},
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_rupee),
                    fillColor: Colors.purple.shade50,
                    filled: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Narration / Remarks (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                onSubmitted: (_) => _saveVoucher(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _saveVoucher,
                  child: Text('Save $_voucherType Entry', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
