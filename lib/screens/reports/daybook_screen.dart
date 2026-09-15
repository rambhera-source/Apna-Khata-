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
  String _selectedVoucherType = 'All'; // 'All', 'Payment', 'Receipt', 'Journal', 'Sales', 'Purchase'
  final List<String> _voucherTypes = ['All', 'Payment', 'Receipt', 'Journal', 'Sales', 'Purchase'];

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7)); // Default last 7 days
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

  // 🔍 Filter aur Date ke aadhar par Entries Fetch karna
  Future<void> _fetchDayBookData() async {
    setState(() => _isLoading = true);

    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    // Isar query base
    var query = DatabaseHelper.isar.accountingTransactions
        .filter()
        .dateBetween(startDateTime, endDateTime);

    List<AccountingTransaction> result = [];

    if (_selectedVoucherType == 'All') {
      result = await query.sortByDateDesc().findAll();
    } else {
      // Specific voucher type filter (Payment, Receipt, Journal, Sales, Purchase)
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

  @override
  Widget build(BuildContext context) {
    // Total Amount calculate karna current filtered list ka
    double totalAmount = _dayBookEntries.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book & Transaction Register'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= FILTER BAR =================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Voucher Type Filter Dropdown
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _selectedVoucherType,
                        items: _voucherTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type == 'All' ? 'All Transactions' : '$type Vouchers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedVoucherType = val!);
                          _fetchDayBookData();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Filter by Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),

                    // 2. From Date Picker Button
                    InkWell(
                      onTap: () => _selectFromDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          DateFormat('dd-MM-yyyy').format(_fromDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),

                    // 3. To Date Picker Button
                    InkWell(
                      onTap: () => _selectToDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          DateFormat('dd-MM-yyyy').format(_toDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ================= SUMMARY BANNER =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing: ${_selectedVoucherType == 'All' ? 'All Entries' : '$_selectedVoucherType Only'} (${_dayBookEntries.length} records)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                  ),
                  Text(
                    'Total Amount: ₹ ${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ================= TRANSACTIONS LIST =================
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _dayBookEntries.isEmpty
                      ? const Center(
                          child: Text('Selected filter ya date range mein koi entry nahi mili.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: _dayBookEntries.length,
                          itemBuilder: (context, index) {
                            final txn = _dayBookEntries[index];
                            
                            // Color coding based on voucher type
                            Color badgeColor = Colors.teal;
                            if (txn.voucherType == 'Payment') badgeColor = Colors.red;
                            if (txn.voucherType == 'Receipt') badgeColor = Colors.green;
                            if (txn.voucherType == 'Journal') badgeColor = Colors.purple;
                            if (txn.voucherType == 'Sales') badgeColor = Colors.teal.shade700;
                            if (txn.voucherType == 'Purchase') badgeColor = Colors.blue.shade700;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: badgeColor.withOpacity(0.15),
                                  child: Text(
                                    txn.voucherType.substring(0, 1),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${txn.voucherType} - ${txn.voucherNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      '₹ ${txn.amount.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Party / Account: ${txn.partyName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      Text('Mode: ${txn.cashOrBank} | Date: ${DateFormat('dd-MM-yyyy').format(txn.date)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      if (txn.notes != null && txn.notes!.isNotEmpty)
                                        Text('Notes: ${txn.notes}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                 ),
                                isThreeLine: true,
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
