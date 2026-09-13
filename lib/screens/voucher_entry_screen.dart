import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import 'searchable_field.dart';

class VoucherEntryScreen extends StatefulWidget {
  const VoucherEntryScreen({super.key});

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  // 1. Voucher Type: 'Payment', 'Receipt', 'Journal'
  String _voucherType = 'Payment';

  // 2. Date Selection
  DateTime _selectedDate = DateTime.now();

  // 3. Auto Voucher Number (State ke sath update hoga)
  String _voucherNumber = '';

  // Controllers
  final TextEditingController _partyController = TextEditingController(); // Party Name (Payment/Receipt)
  final TextEditingController _debitController = TextEditingController();   // Journal ke liye (Dr)
  final TextEditingController _creditController = TextEditingController();  // Journal ke liye (Cr)
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // 4. Mode of Payment / Receipt fields
  String _paymentMode = 'Cash'; // 'Cash', 'Bank', 'Third Party'
  final List<String> _paymentModes = ['Cash', 'Bank', 'Third Party'];

  // Specific Sub-Dropdown selections
  String _selectedBank = 'HDFC Bank A/c';
  final List<String> _bankList = ['HDFC Bank A/c', 'IDFC First Bank A/c', 'Kotak Bank A/c'];

  String _selectedThirdParty = 'PhonePe / Google Pay';
  final List<String> _thirdPartyList = ['PhonePe / Google Pay', 'Paytm Business', 'Razorpay Gateway'];

  List<String> _allAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _generateVoucherNumber();
  }

  // Auto Voucher Number Generator based on Type
  void _generateVoucherNumber() {
    String prefix = 'PMT';
    if (_voucherType == 'Receipt') prefix = 'RCP';
    if (_voucherType == 'Journal') prefix = 'GEN';
    
    // Unique ID ya timestamp ke aadhar par auto number
    _voucherNumber = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {});
  }

  Future<void> _loadAccounts() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
    });
  }

  // Date Picker Dialog
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

  // Save Transaction to Isar DB
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

      // Source decide karna ki paisa kahan se gaya / kahan aaya
      if (_paymentMode == 'Cash') {
        cashOrBankSource = 'Cash-in-Hand';
      } else if (_paymentMode == 'Bank') {
        cashOrBankSource = _selectedBank;
      } else {
        cashOrBankSource = 'Third Party: $_selectedThirdParty';
      }

    } else {
      // Journal Entry
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
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_voucherType Voucher ($_voucherNumber) safaltapurvak save ho gaya!'), backgroundColor: Colors.green),
    );

    // Reset Form & Generate New Voucher Number for next entry
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
        title: Text('Accounting Voucher Entry ($_voucherType)'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Voucher Type Selector
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
                              _generateVoucherNumber(); // Type badalte hi naya voucher code generate hoga
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Row: Date Selection & Auto Voucher Number
              Row(
                children: [
                  // Date Picker Box
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
                  // Auto Voucher Number Box
                  Expanded(
                    child: TextField(
                      readOnly: true, // Auto generated hai toh user manually edit nahi karega
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

              // 3. Conditional Fields based on Voucher Type
              if (_voucherType == 'Payment' || _voucherType == 'Receipt') ...[
                // Party Name (Supplier for Payment, Customer for Receipt)
                SearchableField(
                  label: (_voucherType == 'Payment') ? 'Party Name (Paid To) *' : 'Party Name (Received From) *',
                  items: _allAccounts,
                  controller: _partyController,
                  onSelected: (_) {},
                ),
                const SizedBox(height: 16),

                // Amount Field
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_rupee),
                    fillColor: themeColor.withOpacity(0.08),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Payment / Receipt Mode Selection (Cash / Bank / Third Party)
                DropdownButtonFormField<String>(
                  value: _paymentMode,
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

                // 5. Dynamic Sub-Dropdown agar Bank ya Third Party select kiya ho
                if (_paymentMode == 'Bank') ...[
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
                ] else if (_paymentMode == 'Third Party') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedThirdParty,
                    items: _thirdPartyList.map((tp) {
                      return DropdownMenuItem(value: tp, child: Text(tp));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedThirdParty = val!),
                    decoration: const InputDecoration(
                      labelText: 'Select Third Party Portal / Gateway *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                ],

              ] else ...[
                // Journal / General Entry fields (Debit & Credit)
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

                // Amount Field for Journal
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    fillColor: Colors.purple50,
                    filled: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 6. Narration / Remarks
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Narration / Remarks (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
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
