import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
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
  
  // Date Range States
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30)); // Default last 30 days
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

  // From Date Picker
  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  // To Date Picker
  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  // 🔍 Date Range ke aadhar par Ledger fetch karne ka main function (OK button click hone par)
  Future<void> _generateLedgerReport() async {
    final accountName = _accountController.text.trim();
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya pehle koi Account ya Party select karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Account ka balance nikalna
    final accountObj = await DatabaseHelper.isar.accounts
        .filter()
        .nameEqualTo(accountName)
        .findFirst();

    _currentBalance = accountObj?.balance ?? 0.0;

    // 2. Date range filter ke sath transactions fetch karna (From Date ki subha 00:00 se To Date ki raat 23:59 tak)
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

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⌨️ Ctrl + L Shortcut Handler wrapper
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          // Shortcut dabane par agar screen par hain toh focus account controller par aa jayega
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shortcut Ctrl + L Activated: Search Account'), duration: Duration(milliseconds: 800)),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Account / Party Ledger (Ctrl + L)'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Account Search & Dropdown Field
                SearchableField(
                  label: 'Select Party, Customer, Supplier or Bank *',
                  items: _allAccounts,
                  controller: _accountController,
                  onSelected: (selectedAccount) {
                    // Account select hone ke baad user date choose karega
                  },
                ),
                const SizedBox(height: 14),

                // 2. Date Range Row (From Date & To Date)
                Row(
                  children: [
                    // From Date Box
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectFromDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'From Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month, size: 20),
                          ),
                          child: Text(
                            DateFormat('dd-MM-yyyy').format(_fromDate),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // To Date Box
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectToDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'To Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month, size: 20),
                          ),
                          child: Text(
                            DateFormat('dd-MM-yyyy').format(_toDate),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. OK Button (Report Generate karne ke liye)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _generateLedgerReport,
                  child: const Text('OK / View Ledger Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                // 4. Ledger Report View Area
                if (_isReportLoaded) ...[
                  // Summary Card with Current Balance
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Ledger: ${_accountController.text}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Net Balance: ₹ ${_currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15, 
                            color: _currentBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Transactions in Selected Date Range:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),

                  // Transactions List View
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _ledgerTransactions.isEmpty
                            ? const Center(
                                child: Text('Is date range mein koi transaction nahi mili.', style: TextStyle(color: Colors.grey)),
                              )
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
                                        child: Icon(
                                          isPayment ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: isPayment ? Colors.red : Colors.green,
                                        ),
                                      ),
                                      title: Text('${txn.voucherType} (${txn.voucherNumber})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}\nMode: ${txn.cashOrBank}\nNotes: ${txn.notes ?? "N/A"}'),
                                      isThreeLine: true,
                                      trailing: Text(
                                        '₹ ${txn.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isPayment ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ] else ...[
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Kripya Account chun kar, Date range set karein aur "OK" dabayein.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
