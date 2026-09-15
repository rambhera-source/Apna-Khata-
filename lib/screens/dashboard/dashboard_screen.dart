import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/transaction_model.dart';

// 🔥 Your Exact Original Screen Files Imports
import '../sales/sales_screen.dart';
import '../sales/sales_return_screen.dart';
import '../purchase/purchase_screen.dart';
import '../purchase/purchase_return_screen.dart';
import '../daybook_screen.dart';
import '../ledger_screen.dart';
import '../financial_reports_screen.dart';
import '../product_inventory_screen.dart';
import '../parties_master_screen.dart';
import '../orders_management_screen.dart';
import '../voucher_entry_screen.dart';
import '../setting/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final dynamic currentUser;

  const DashboardScreen({super.key, this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _todaySales = 0.0;
  double _todayPurchases = 0.0;
  double _cashInHand = 0.0;
  double _bankBalance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayTxns = await DatabaseHelper.isar.accountingTransactions
          .filter()
          .dateBetween(startOfDay, endOfDay)
          .findAll();

      double sales = 0.0;
      double purchases = 0.0;

      for (var txn in todayTxns) {
        if (txn.voucherType == 'Sales') {
          sales += txn.amount;
        } else if (txn.voucherType == 'Purchase') {
          purchases += txn.amount;
        }
      }

      final allTxns = await DatabaseHelper.isar.accountingTransactions.where().findAll();
      double cash = 0.0;
      double bank = 0.0;

      for (var txn in allTxns) {
        if (txn.cashOrBank.toLowerCase().contains('cash')) {
          if (txn.voucherType == 'Sales' || txn.voucherType == 'Receipt') {
            cash += txn.amount;
          } else {
            cash -= txn.amount;
          }
        } else {
          if (txn.voucherType == 'Sales' || txn.voucherType == 'Receipt') {
            bank += txn.amount;
          } else {
            bank -= txn.amount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _todaySales = sales;
          _todayPurchases = purchases;
          _cashInHand = cash;
          _bankBalance = bank;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE ERP Dashboard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboardData();
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 TOP SUMMARY CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: "Today's Sales",
                            amount: _todaySales,
                            color: Colors.teal.shade700,
                            icon: Icons.trending_up,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen())),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            title: "Today's Purchase",
                            amount: _todayPurchases,
                            color: Colors.blue.shade700,
                            icon: Icons.trending_down,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: "Cash in Hand",
                            amount: _cashInHand,
                            color: Colors.green.shade700,
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            title: "Bank / UPI Balance",
                            amount: _bankBalance,
                            color: Colors.indigo.shade700,
                            icon: Icons.account_balance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🔥 MODULES GRID (Using your actual screen classes)
                    const Text('Quick Operations & Masters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),

                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.05,
                      children: [
                        _buildMenuCard(context, 'Sales Bill', Icons.point_of_sale, Colors.teal, const SalesScreen()),
                        _buildMenuCard(context, 'Purchase', Icons.shopping_cart, Colors.blue, const PurchaseScreen()),
                        _buildMenuCard(context, 'Sales Return', Icons.assignment_return, Colors.orange, const SalesReturnScreen()),
                        _buildMenuCard(context, 'Purchase Ret.', Icons.remove_shopping_cart, Colors.deepOrange, const PurchaseReturnScreen()),
                        _buildMenuCard(context, 'Parties', Icons.people, Colors.indigo, const PartiesMasterScreen()),
                        _buildMenuCard(context, 'Inventory', Icons.inventory_2, Colors.purple, const ProductInventoryScreen()),
                        _buildMenuCard(context, 'Day Book', Icons.book, Colors.brown, const DayBookScreen()),
                        _buildMenuCard(context, 'Ledger', Icons.account_balance_wallet, Colors.amber.shade900, const LedgerScreen()),
                        _buildMenuCard(context, 'Reports', Icons.bar_chart, Colors.cyan.shade800, const FinancialReportsScreen()),
                        _buildMenuCard(context, 'Orders', Icons.shopping_bag, Colors.pink.shade700, const OrdersManagementScreen()),
                        _buildMenuCard(context, 'Voucher', Icons.receipt_long, Colors.blueGrey, const VoucherEntryScreen()),
                        _buildMenuCard(context, 'Settings', Icons.settings_applications, Colors.grey.shade800, const SettingsScreen()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({required String title, required double amount, required Color color, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, Widget targetScreen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1)),
          ],
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
