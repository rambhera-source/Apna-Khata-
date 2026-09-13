import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
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
  // Voucher Type: 'Payment', 'Receipt', 'Journal'
  String _voucherType = 'Payment';

  // Controllers
  final TextEditingController _partyController = TextEditingController(); // Payment/Receipt ke liye
  final TextEditingController _debitController = TextEditingController(); // Journal ke liye (Dr)
  final TextEditingController _creditController = TextEditingController(); // Journal ke liye (Cr)
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _cashOrBank = 'Cash-in-Hand';
  final List<String> _cashBankOptions = ['Cash-in-Hand', 'HDFC Bank A/c', 'IDFC First Bank A/c'];
  
  List<String> _allAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
    });
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

    String prefix = 'PMT';
    if (_voucherType == 'Receipt') prefix = 'RCP';
    if (_voucherType == 'Journal') prefix = 'GEN';

    final voucherNo = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    String partyOrAccounts = '';
    if (_voucherType == 'Payment' || _voucherType == 'Receipt') {
      partyOrAccounts = _partyController.text.trim();
      if (partyOrAccounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kripya Party ka naam select karein!'), backgroundColor: Colors.red),
        );
        return;
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
    }

    final txn = AccountingTransaction()
      ..voucherType = _voucherType
      ..voucherNumber = voucherNo
      ..date = DateTime.now()
      ..partyName = partyOrAccounts
      ..cashOrBank = (_voucherType == 'Journal') ? 'Journal Transfer' : _cashOrBank
      ..amount = amount
      ..notes = notes.isEmpty ? null : notes;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accountingTransactions.put(txn);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_voucherType Voucher ($voucherNo) safaltapurvak save ho gaya!'), backgroundColor: Colors.green),
    );

    // Reset Form
    _partyController.clear();
    _debitController.clear();
    _creditController.clear();
    _amountController.clear();
    _notesController.clear();
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
              // 1. Voucher Type Selector (The magic part)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: themeColor.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.grey),
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
                          onChanged: (val) => setState(() => _voucherType = val!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Conditional Fields based on Voucher Type
              if (_voucherType == 'Payment' || _voucherType == 'Receipt') ...[
                // Cash or Bank Ledger
                DropdownButtonFormField<String>(
                  value: _cashOrBank,
                  items: _cashBankOptions.map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (val) => setState(() => _cashOrBank = val!),
                  decoration: const InputDecoration(
                    labelText: 'Paid Through / Received In *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
                const SizedBox(height: 16),

                // Party Name
                SearchableField(
                  label: (_voucherType == 'Payment') ? 'Paid To (Supplier/Party) *' : 'Received From (Customer/Party) *',
                  items: _allAccounts,
                  controller: _partyController,
                  onSelected: (_) {},
                ),
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
              ],
              const SizedBox(height: 16),

              // 3. Amount Field
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

              // 4. Narration / Remarks
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
