import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../models/inventory_model.dart';
import '../models/account.dart';

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
import 'vouchers/payment_voucher_screen.dart';
import 'vouchers/receipt_voucher_screen.dart';
import 'vouchers/journal_voucher_screen.dart';
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
    'Orders', 'Payment', 'Receipt', 'Journal', 'Manufacturing', 'Settings'
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptRestoreIfEmpty();
    });
  }

  Future<void> _checkAndPromptRestoreIfEmpty() async {
    try {
      final accountsCount = await DatabaseHelper.isar.accounts.count();
      final txnsCount = await DatabaseHelper.isar.accountingTransactions.count();

      if (accountsCount == 0 && txnsCount == 0) {
        final directory = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${directory.path}/Orlife ERP Backups');

        if (await backupDir.exists()) {
          List<FileSystemEntity> files = backupDir.listSync();
          List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();

          if (jsonFiles.isNotEmpty) {
            jsonFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
            final latestFile = jsonFiles.first;
            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(latestFile.statSync().modified);

            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: const [
                    Icon(Icons.restore_rounded, color: Colors.teal, size: 26),
                    SizedBox(width: 10),
                    Expanded(child: Text('Restore Backup Found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  ],
                ),
                content: Text(
                  'Your database is empty. A recent backup from $formattedDate was found in local storage. Would you like to restore it now?',
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _restoreFromFile(latestFile);
                    },
                    child: const Text('Restore Now'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _restoreFromFile(File file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isCompleted = false;

          if (!isCompleted) {
            file.readAsString().then((jsonString) async {
              Map<String, dynamic> backupData = jsonDecode(jsonString);
              await DatabaseHelper.isar.writeTxn(() async {
                if (backupData.containsKey('inventory')) {
                  List invList = backupData['inventory'];
                  for (var item in invList) {
                    InventoryItem inv = InventoryItem()
                      ..itemName = item['itemName'] ?? ''
                      ..sku = item['sku']
                      ..category = item['category'] ?? 'General'
                      ..purchasePrice = item['purchasePrice'] ?? 0.0
                      ..openingStock = item['openingStock'] ?? 0.0
                      ..stockQuantity = item['stockQuantity'] ?? 0.0
                      ..priceA = item['priceA'] ?? 0.0
                      ..priceCategory = item['priceCategory'] ?? 'A'
                      ..stockType = item['stockType'] ?? 'Fresh';
                    await DatabaseHelper.isar.inventoryItems.put(inv);
                  }
                }

                if (backupData.containsKey('accounts')) {
                  List accList = backupData['accounts'];
                  for (var item in accList) {
                    Account acc = Account()
                      ..name = item['name'] ?? ''
                      ..groupCategory = item['groupCategory'] ?? 'Sundry Debtors'
                      ..phone = item['phone']
                      ..email = item['email']
                      ..address = item['address']
                      ..gstin = item['gstin']
                      ..openingBalance = item['openingBalance'] ?? 0.0
                      ..balanceType = item['balanceType'] ?? 'Dr';
                    await DatabaseHelper.isar.accounts.put(acc);
                  }
                }

                if (backupData.containsKey('transactions')) {
                  List txnList = backupData['transactions'];
                  for (var item in txnList) {
                    AccountingTransaction txn = AccountingTransaction()
                      ..date = DateTime.tryParse(item['date'] ?? '') ?? DateTime.now()
                      ..voucherType = item['voucherType'] ?? 'Sales'
                      ..voucherNumber = item['voucherNumber'] ?? ''
                      ..partyName = item['partyName'] ?? ''
                      ..cashOrBank = item['cashOrBank'] ?? 'Cash'
                      ..amount = item['amount'] ?? 0.0
                      ..notes = item['notes'];
                    await DatabaseHelper.isar.accountingTransactions.put(txn);
                  }
                }
              });

              if (mounted) {
                setDialogState(() {
                  isCompleted = true;
                });
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: isCompleted ? Colors.green : Colors.teal, size: 26),
                const SizedBox(width: 10),
                Text(isCompleted ? 'Restore Successful' : 'Restoring Database...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              isCompleted ? 'Your database has been successfully restored from local backup.' : 'Please wait while we restore your data...',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              if (isCompleted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _loadDashboardData();
                  },
                  child: const Text('OK'),
                ),
            ],
          );
        },
      ),
    );
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
              'Payment': Icons.payment,
              'Receipt': Icons.receipt,
              'Journal': Icons.menu_book,
              'Manufacturing': Icons.factory,
              'Settings': Icons.settings_applications,
            };

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.tune_rounded, color: Colors.teal, size: 24),
                  SizedBox(width: 10),
                  Text('Customize Home Shortcuts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allAvailableMenus.keys.length,
                  itemBuilder: (context, index) {
                    String menuTitle = allAvailableMenus.keys.elementAt(index);
                    IconData menuIcon = allAvailableMenus.values.elementAt(index);
                    bool isSelected = _selectedQuickMenus.contains(menuTitle);

                    return CheckboxListTile(
                      secondary: Icon(menuIcon, color: isSelected ? Colors.teal : Colors.grey, size: 20),
                      title: Text(menuTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      value: isSelected,
                      activeColor: Colors.teal,
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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

  Future<void> _performDashboardBackup() async {
    try {
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      final Map<String, dynamic> backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'inventory': inventoryItems.map((e) => {'itemName': e.itemName, 'sku': e.sku, 'category': e.category, 'purchasePrice': e.purchasePrice, 'openingStock': e.openingStock, 'stockQuantity': e.stockQuantity, 'priceA': e.priceA, 'priceCategory': e.priceCategory, 'stockType': e.stockType}).toList(),
        'accounts': accounts.map((e) => {'name': e.name, 'groupCategory': e.groupCategory, 'phone': e.phone, 'email': e.email, 'address': e.address, 'gstin': e.gstin, 'openingBalance': e.openingBalance, 'balanceType': e.balanceType}).toList(),
        'transactions': transactions.map((e) => {'date': e.date.toIso8601String(), 'voucherType': e.voucherType, 'voucherNumber': e.voucherNumber, 'partyName': e.partyName, 'cashOrBank': e.cashOrBank, 'amount': e.amount, 'notes': e.notes}).toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/Orlife ERP Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupDir.path}/orlife_erp_backup_$dateStr.json');
      await file.writeAsBytes(utf8.encode(jsonEncode(backupData)));
    } catch (_) {}
  }

  Future<void> _triggerBackupAndExit() async {
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
              Navigator.pop(context);
              exit(0);
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
                builder: (context) => StatefulBuilder(
                  builder: (context, setDialogState) {
                    bool isDone = false;

                    if (!isDone) {
                      _performDashboardBackup().then((_) {
                        if (mounted) {
                          setDialogState(() {
                            isDone = true;
                          });
                        }
                      });
                    }

                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(isDone ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: isDone ? Colors.green : Colors.teal, size: 26),
                          const SizedBox(width: 10),
                          Text(isDone ? 'Backup Successful' : 'Creating Backup...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        isDone ? 'Your data has been safely secured inside "Orlife ERP Backups".' : 'Please wait while we secure your data...',
                        style: const TextStyle(fontSize: 13),
                      ),
                      actions: [
                        if (isDone)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              exit(0);
                            },
                            child: const Text('OK'),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
            child: const Text('Backup & Exit'),
          ),
        ],
      ),
    );
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
                leading: const Icon(Icons.payment, color: Colors.red),
                title: const Text('Payment Voucher'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentVoucherScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.receipt, color: Colors.green),
                title: const Text('Receipt Voucher'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReceiptVoucherScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.purple),
                title: const Text('Journal Voucher'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const JournalVoucherScreen())),
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
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Exit App', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _triggerBackupAndExit();
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
                            case 'Payment':
                              return _buildMenuCard(context, 'Payment', Icons.payment, Colors.red, const PaymentVoucherScreen());
                            case 'Receipt':
                              return _buildMenuCard(context, 'Receipt', Icons.receipt, Colors.green, const ReceiptVoucherScreen());
                            case 'Journal':
                              return _buildMenuCard(context, 'Journal', Icons.menu_book, Colors.purple, const JournalVoucherScreen());
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
