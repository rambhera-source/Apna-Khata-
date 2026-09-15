import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';

class AllHistoryScreen extends StatefulWidget {
  final String initialType; // 'Sales', 'SalesReturn', 'Purchase', 'PurchaseReturn', 'Payment', 'Receipt', etc.
  const AllHistoryScreen({super.key, required this.initialType});

  @override
  State<AllHistoryScreen> createState() => _AllHistoryScreenState();
}

class _AllHistoryScreenState extends State<AllHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _types = ['Sales', 'SalesReturn', 'Purchase', 'PurchaseReturn', 'Payment', 'Receipt'];
  
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    int initialIndex = _types.indexOf(widget.initialType);
    if (initialIndex == -1) initialIndex = 0;

    _tabController = TabController(length: _types.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadHistoryForType(_types[_tabController.index]);
      }
    });

    _loadHistoryForType(_types[initialIndex]);
  }

  Future<void> _loadHistoryForType(String type) async {
    setState(() => _isLoading = true);
    try {
      // Isar se selected voucherType ke mutabiq records fetch karna
      final results = await DatabaseHelper.isar.accountingTransactions
          .filter()
          .voucherTypeEqualTo(type)
          .findAll();

      setState(() {
        _transactions = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _transactions = [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getThemeColor(String type) {
    switch (type) {
      case 'Sales': return Colors.teal;
      case 'SalesReturn': return Colors.orange;
      case 'Purchase': return Colors.blue;
      case 'PurchaseReturn': return Colors.deepOrange;
      case 'Payment': return Colors.red;
      case 'Receipt': return Colors.green;
      default: return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History & Records'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _types.map((t) => Tab(text: t.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' '))).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(
                  child: Text(
                    'Is category mein koi history ya bill maujud nahi hai.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final txn = _transactions[index];
                    Color cardColor = _getThemeColor(txn.voucherType ?? '');

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cardColor.withOpacity(0.15),
                          child: Icon(Icons.receipt_long, color: cardColor),
                        ),
                        title: Text(
                          'Party: ${txn.partyName ?? "Cash / Walk-in"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Date: ${txn.date ?? "N/A"} | Bill No: ${txn.billNo ?? "N/A"}'),
                        trailing: Text(
                          '₹ ${(txn.amount ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cardColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
