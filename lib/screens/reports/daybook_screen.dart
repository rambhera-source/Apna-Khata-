import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/transaction_model.dart';

class DayBookScreen extends StatefulWidget {
  const DayBookScreen({super.key});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  // Filters
  String _selectedVoucherType = 'All'; 
  final List<String> _voucherTypes = ['All', 'Payment', 'Receipt', 'Journal', 'Sales', 'Purchase'];

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7)); 
  DateTime _toDate = DateTime.now();

  List<AccountingTransaction> _dayBookEntries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDayBookData();
  }

  // From Date Picker
  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _fetchDayBookData();
    }
  }

  // To Date Picker
  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _fetchDayBookData();
    }
  }

  // Fetch Entries from Isar Database
  Future<void> _fetchDayBookData() async {
    setState(() => _isLoading = true);

    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    var query = DatabaseHelper.isar.accountingTransactions
        .filter()
        .dateBetween(startDateTime, endDateTime);

    List<AccountingTransaction> result = [];

    if (_selectedVoucherType == 'All') {
      result = await query.sortByDateDesc().findAll();
    } else {
      result = await query
          .and()
          .voucherTypeEqualTo(_selectedVoucherType)
          .sortByDateDesc()
          .findAll();
    }

    setState(() {
      _dayBookEntries = result;
      _isLoading = false;
    });
  }

  // Edit Dialog when clicking on Voucher Number
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
                    labelText: 'Notes / Remarks',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                final newAmount = double.tryParse(amountController.text) ?? txn.amount;
                final newNotes = notesController.text.trim();

                await DatabaseHelper.isar.writeTxn(() async {
                  txn.amount = newAmount;
                  txn.notes = newNotes.isEmpty ? null : newNotes;
                  await DatabaseHelper.isar.accountingTransactions.put(txn);
                });

                Navigator.pop(context);
                _fetchDayBookData();

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

  @override
  Widget build(BuildContext context) {
    double totalAmount = _dayBookEntries.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book & Transaction Register', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= COMPACT FILTER BAR =================
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // 1. Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedVoucherType,
                          items: _voucherTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type == 'All' ? 'All Types' : type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedVoucherType = val!);
                            _fetchDayBookData();
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 2. From Date
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => _selectFromDate(context),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            DateFormat('dd-MM-yy').format(_fromDate),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3. To Date
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => _selectToDate(context),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            DateFormat('dd-MM-yy').format(_toDate),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ================= SUMMARY BANNER =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Records: ${_dayBookEntries.length}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey.shade800),
                  ),
                  Text(
                    'Total: ₹ ${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ================= TRANSACTIONS LIST =================
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _dayBookEntries.isEmpty
                      ? const Center(
                          child: Text('Koi entry nahi mili.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        )
                      : ListView.builder(
                          itemCount: _dayBookEntries.length,
                          itemBuilder: (context, index) {
                            final txn = _dayBookEntries[index];
                            
                            Color badgeColor = Colors.teal;
                            if (txn.voucherType == 'Payment') badgeColor = Colors.red;
                            if (txn.voucherType == 'Receipt') badgeColor = Colors.green;
                            if (txn.voucherType == 'Journal') badgeColor = Colors.purple;
                            if (txn.voucherType == 'Sales') badgeColor = Colors.teal.shade700;
                            if (txn.voucherType == 'Purchase') badgeColor = Colors.blue.shade700;

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Date | Clickable Voucher Number | Amount
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // 1. Date
                                        Text(
                                          DateFormat('dd-MM-yy').format(txn.date),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                        ),
                                        
                                        // 2. Voucher / Invoice Number (Clickable to Edit)
                                        InkWell(
                                          onTap: () => _openEditTransactionDialog(txn),
                                          child: Container(
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
                                        ),

                                        // 3. Amount
                                        Text(
                                          '₹ ${txn.amount.toStringAsFixed(2)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: badgeColor),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 6, thickness: 0.5),

                                    // Row 2: Party Name & Mode
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Party: ${txn.partyName}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Mode: ${txn.cashOrBank}',
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
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
