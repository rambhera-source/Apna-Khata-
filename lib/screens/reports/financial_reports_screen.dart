import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'package:accounting_app/models/account.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  double _totalSales = 0.0;
  double _totalPurchases = 0.0;
  double _totalPayments = 0.0;
  double _totalReceipts = 0.0;
  
  double _totalAssets = 0.0;
  double _totalLiabilities = 0.0;
  double _cashInHand = 0.0;
  double _bankBalances = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateFinancialData();
  }

  Future<void> _calculateFinancialData() async {
    setState(() => _isLoading = true);

    final allTxns = await DatabaseHelper.isar.accountingTransactions.where().findAll();
    
    double sales = 0.0;
    double purchases = 0.0;
    double payments = 0.0;
    double receipts = 0.0;

    for (var txn in allTxns) {
      if (txn.voucherType == 'Sales') sales += txn.amount;
      if (txn.voucherType == 'Purchase') purchases += txn.amount;
      if (txn.voucherType == 'Payment') payments += txn.amount;
      if (txn.voucherType == 'Receipt') receipts += txn.amount;
    }

    setState(() {
      _totalSales = sales;
      _totalPurchases = purchases;
      _totalPayments = payments;
      _totalReceipts = receipts;
      _totalAssets = 125000.0;
      _totalLiabilities = 45000.0;
      _cashInHand = 50000.0;
      _bankBalances = 85000.0;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double netProfit = _totalSales - _totalPurchases;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports (P&L & Balance Sheet)'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Profit & Loss Statement'),
            Tab(text: 'Balance Sheet'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      const Text('Trading & Profitability Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('REVENUE / INCOME', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                              const Divider(),
                              _buildReportRow('Total Sales Revenue', _totalSales),
                              _buildReportRow('Total Receipts Recorded', _totalReceipts),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EXPENSES / PURCHASES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                              const Divider(),
                              _buildReportRow('Total Purchase Costs', _totalPurchases),
                              _buildReportRow('Total Direct Payments', _totalPayments),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: netProfit >= 0 ? Colors.green.shade300 : Colors.red.shade300, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              netProfit >= 0 ? 'NET NET PROFIT:' : 'NET NET LOSS:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: netProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800),
                            ),
                            Text(
                              '₹ ${netProfit.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      const Text('Statement of Financial Position (Balance Sheet)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ASSETS (Resources & Receivables)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                              const Divider(),
                              _buildReportRow('Cash-in-Hand', _cashInHand),
                              _buildReportRow('Bank Account Balances', _bankBalances),
                              _buildReportRow('Accounts Receivables / Other Assets', _totalAssets),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LIABILITIES & CAPITAL (Dues & Payables)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13)),
                              const Divider(),
                              _buildReportRow('Accounts Payables / Supplier Dues', _totalLiabilities),
                              _buildReportRow('Business Capital / Retained Earnings', netProfit > 0 ? netProfit : 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReportRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
