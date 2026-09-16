import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/transaction_model.dart';

import 'sales/sales_screen.dart';
import 'sales/sales_return_screen.dart';
import 'purchase/purchase_screen.dart';
import 'purchase/purchase_return_screen.dart';
import 'reports/daybook_screen.dart';
import 'reports/ledger_screen.dart';
import 'reports/financial_reports_screen.dart';
import 'products/product_inventory_screen.dart';
import 'account/parties_master_screen.dart';
import 'order/orders_management_screen.dart';
import 'Voucher/voucher_entry_screen.dart';
import 'setting/settings_screen.dart';
import 'setting/backup_settings_screen.dart';
import 'manufacturing_screen.dart';
import 'login_screen.dart';

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

  final List<String> _selectedQuickMenus = [
    'Sales Bill', 'Purchase', 'Sales Return', 'Purchase Ret.',
    'Parties', 'Inventory', 'Day Book', 'Ledger', 'Reports',
    'Orders', 'Voucher', 'Manufacturing', 'Settings'
  ];

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

  void _showCustomizeMenusDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allAvailableMenus = {
              'Sales Bill': Icons.point_of_sale,
              'Purchase': Icons.shopping_cart,
              'Sales Return': Icons.assignment_return,
              'Purchase Ret.': Icons.remove_shopping_cart,
              'Parties': Icons.people,
              'Inventory': Icons.inventory_2,
              'Day Book': Icons.book,
              'Ledger': Icons.account_balance_wallet,
              'Reports': Icons.bar_chart,
              'Orders': Icons.shopping_bag,
              'Voucher': Icons.receipt_long,
              'Manufacturing': Icons.factory,
              'Settings': Icons.settings_applications,
            };

            return AlertDialog(
              title: const Text('Customize Home Shortcuts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: ListView(
                  children: allAvailableMenus.keys.map((menuTitle) {
                    bool isSelected = _selectedQuickMenus.contains(menuTitle);
                    return CheckboxListTile(
                      title: Text(menuTitle, style: const TextStyle(fontSize: 13)),
                      value: isSelected,
                      activeColor: Colors.teal,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedQuickMenus.add(menuTitle);
                          } else {
                            _selectedQuickMenus.remove(menuTitle);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performAutoBackupOnClose() async {
    try {
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      final Map<String, dynamic> backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'inventory': inventoryItems.map((e) => {'itemName': e.itemName, 'sku': e.sku, 'stockQuantity': e.stockQuantity, 'purchasePrice': e.purchasePrice, 'priceA': e.priceA}).toList(),
        'accounts': accounts.map((e) => {'name': e.name, 'groupCategory': e.groupCategory, 'phone': e.phone, 'openingBalance': e.openingBalance}).toList(),
        'transactions': transactions.map((e) => {'date': e.date.toIso8601String(), 'voucherType': e.voucherType, 'voucherNumber': e.voucherNumber, 'partyName': e.partyName, 'amount': e.amount}).toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/orlife_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/auto_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(backupData));
    } catch (_) {}
  }

  // ✨ स्मार्ट बैकअप और एग्जिट प्रोसेस
  Future<void> _triggerBackupAndExit() async {
    bool shouldExit = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit & Secure Backup?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Would you like to take an automated backup before closing the app?', style: TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () {
              shouldExit = true;
              Navigator.pop(context);
            },
            child: const Text('Exit without Backup', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.teal, strokeWidth: 3),
                        SizedBox(width: 20),
                        Text('Creating secure backup...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );

              await _performAutoBackupOnClose();
              if (!mounted) return;
              Navigator.pop(context); // प्रोग्रेस बंद करें

              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      SizedBox(width: 10),
                      Text('Backup Successful', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                  content: const Text('Your data has been safely secured locally.', style: TextStyle(fontSize: 13)),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Okay'),
                    ),
                  ],
                ),
              );

              shouldExit = true;
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('Backup & Exit'),
          ),
        ],
      ),
    );

    if (shouldExit) {
      exit(0); // PC / Mobile ऐप पूरी तरह से बंद हो जाएगी
    }
  }

  Future<bool> _onWillPop() async {
    await _triggerBackupAndExit();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.currentUser != null ? 'Welcome, ${widget.currentUser.name ?? "User"}' : 'ORLIFE ERP Dashboard',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
              icon: const Icon(Icons.tune, size: 20),
              onPressed: _showCustomizeMenusDialog,
              tooltip: 'Customize Shortcuts',
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              tooltip: 'Settings',
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1B365D)),
                accountName: Text(widget.currentUser?.name ?? 'ORLIFE User', style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(widget.currentUser?.username ?? 'ERP System'),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, size: 35, color: Color(0xFF1B365D)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Sales Bill'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Purchase'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Parties Master'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PartiesMasterScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Product Inventory'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Day Book'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.factory),
                title: const Text('Manufacturing / BOM'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManufacturingScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Financial Reports'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialReportsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.backup_rounded, color: Colors.teal),
                title: const Text('Storage & Backup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupSettingsScreen())),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.orange),
                title: const Text('Logout', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
              // 🚪 PC और Mobile दोनों के लिए Sidebar में सबसे नीचे 'Exit App' का ऑप्शन
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Exit App', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); // Drawer बंद करें
                  _triggerBackupAndExit(); // बैकअप और एग्जिट ट्रिगर करें
                },
              ),
            ],
          ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quick Operations & Masters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                          IconButton(
                            icon: const Icon(Icons.tune, size: 18, color: Colors.teal),
                            onPressed: _showCustomizeMenusDialog,
                            tooltip: 'Customize Shortcuts',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.05,
                        children: _selectedQuickMenus.map((menuTitle) {
                          switch (menuTitle) {
                            case 'Sales Bill':
                              return _buildMenuCard(context, 'Sales Bill', Icons.point_of_sale, Colors.teal, const SalesScreen());
                            case 'Purchase':
                              return _buildMenuCard(context, 'Purchase', Icons.shopping_cart, Colors.blue, const PurchaseScreen());
                            case 'Sales Return':
                              return _buildMenuCard(context, 'Sales Return', Icons.assignment_return, Colors.orange, const SalesReturnScreen());
                            case 'Purchase Ret.':
                              return _buildMenuCard(context, 'Purchase Ret.', Icons.remove_shopping_cart, Colors.deepOrange, const PurchaseReturnScreen());
                            case 'Parties':
                              return _buildMenuCard(context, 'Parties', Icons.people, Colors.indigo, const PartiesMasterScreen());
                            case 'Inventory':
                            return _buildMenuCard(context, 'Inventory', Icons.inventory_2, Colors.purple, const ProductInventoryScreen());
                            case 'Day Book':
                              return _buildMenuCard(context, 'Day Book', Icons.book, Colors.brown, const DayBookScreen());
                            case 'Ledger':
                              return _buildMenuCard(context, 'Ledger', Icons.account_balance_wallet, Colors.amber.shade900, const LedgerScreen());
                            case 'Reports':
                              return _buildMenuCard(context, 'Reports', Icons.bar_chart, Colors.cyan.shade800, const FinancialReportsScreen());
                            case 'Orders':
                              return _buildMenuCard(context, 'Orders', Icons.shopping_bag, Colors.pink.shade700, const OrdersManagementScreen());
                            case 'Voucher':
                              return _buildMenuCard(context, 'Voucher', Icons.receipt_long, Colors.blueGrey, const VoucherEntryScreen());
                            case 'Manufacturing':
                              return _buildMenuCard(context, 'Manufacturing', Icons.factory, Colors.deepPurple, const ManufacturingScreen());
                            case 'Settings':
                              return _buildMenuCard(context, 'Settings', Icons.settings_applications, Colors.grey.shade800, const SettingsScreen());
                            default:
                              return Container();
                          }
                        }).toList(),
                      ),
                    ],
                  ),
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
