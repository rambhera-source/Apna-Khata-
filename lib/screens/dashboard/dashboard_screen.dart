import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/user_model.dart';
import 'package:accounting_app/screens/voucher_entry_screen.dart';
import 'package:accounting_app/screens/sales/sales_screen.dart';
import 'package:accounting_app/screens/purchase/purchase_screen.dart';
import 'package:accounting_app/screens/sales/sales_return_screen.dart';
import 'package:accounting_app/screens/purchase/purchase_return_screen.dart';
import 'package:accounting_app/screens/reports/ledger_screen.dart';
import 'package:accounting_app/screens/order/orders_management_screen.dart';
import 'package:accounting_app/screens/reports/financial_reports_screen.dart';
import 'package:accounting_app/screens/reports/daybook_screen.dart';
import 'package:accounting_app/screens/account/parties_master_screen.dart';
import 'package:accounting_app/screens/products/product_inventory_screen.dart';
import 'package:accounting_app/screens/setting/settings_screen.dart';
import 'package:accounting_app/screens/manufacturing_screen.dart';
import 'package:accounting_app/screens/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserAccount currentUser;
  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalSales = 0.0;
  double _totalPurchases = 0.0;
  double _cashBalance = 50000.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    double sales = 0.0;
    double purchases = 0.0;
    double cash = 50000.0;

    setState(() {
      _totalSales = sales;
      _totalPurchases = purchases;
      _cashBalance = cash;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isManufacturing = widget.currentUser.businessType == 'Manufacturing';

    return Scaffold(
      appBar: AppBar(
        title: Text('ORLIFE ERP - ${widget.currentUser.name} (${widget.currentUser.role})'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),

      // 📱 CLEAN SIDEBAR (DRAWER) WITHOUT NUMBERS
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 26,
                    child: Icon(Icons.store, color: Colors.teal, size: 30),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ORLIFE ERP Menu',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.currentUser.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // SALES
            ExpansionTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.teal),
              title: const Text('Sales', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Sales Bill'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Sales Return'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReturnScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Sales & Return History'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
                  },
                ),
              ],
            ),

            // PURCHASE
            ExpansionTile(
              leading: const Icon(Icons.shopping_cart, color: Colors.blue),
              title: const Text('Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Purchase Bill'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Purchase Return'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseReturnScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Purchase History'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
                  },
                ),
              ],
            ),

            // ACCOUNTS
            ListTile(
              leading: const Icon(Icons.people, color: Colors.indigo),
              title: const Text('Accounts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PartiesMasterScreen()));
              },
            ),

            // ORDERS MANAGEMENT
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.amber),
              title: const Text('Orders Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersManagementScreen()));
              },
            ),

            // PRODUCT INVENTORY
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.orange),
              title: const Text('Product Inventory'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
              },
            ),

            // VOUCHER ENTRY
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.red),
              title: const Text('Voucher Entry'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen()));
              },
            ),

            // REPORTS
            ExpansionTile(
              leading: const Icon(Icons.analytics, color: Colors.deepPurple),
              title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Day Book'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DayBookScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Financial Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialReportsScreen()));
                  },
                ),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Ledger'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LedgerScreen()));
                  },
                ),
              ],
            ),

            // SETTINGS & BACKUP
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blueGrey),
              title: const Text('Settings (Backup & Master)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DayBookScreen()),
                            );
                          },
                          child: Card(
                            color: Colors.teal.shade50,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Sales', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹ ${_totalSales.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DayBookScreen()),
                            );
                          },
                          child: Card(
                            color: Colors.blue.shade50,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Purchases', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹ ${_totalPurchases.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Quick Shortcuts & Modules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _buildMenuCard(context, 'Sales Bill', Icons.point_of_sale, Colors.teal, const SalesScreen()),
                      _buildMenuCard(context, 'Purchase Bill', Icons.shopping_cart, Colors.blue, const PurchaseScreen()),
                      _buildMenuCard(context, 'Parties Master', Icons.people, Colors.indigo, const PartiesMasterScreen()),
                      _buildMenuCard(context, 'Inventory', Icons.inventory, Colors.orange, const ProductInventoryScreen()),
                      _buildMenuCard(context, 'Day Book', Icons.book, Colors.brown, const DayBookScreen()),
                      _buildMenuCard(context, 'Ledger', Icons.account_balance_wallet, Colors.purple, const LedgerScreen()),
                      _buildMenuCard(context, 'Orders', Icons.list_alt, Colors.amber.shade800, const OrdersManagementScreen()),
                      _buildMenuCard(context, 'Reports', Icons.analytics, Colors.deepPurple, const FinancialReportsScreen()),
                      if (isManufacturing)
                        _buildMenuCard(context, 'Manufacturing', Icons.precision_manufacturing, Colors.indigo.shade900, const ManufacturingScreen()),
                      _buildMenuCard(context, 'Payment', Icons.payment, Colors.red.shade700, const VoucherEntryScreen()),
                      _buildMenuCard(context, 'Receipt', Icons.receipt, Colors.green.shade700, const VoucherEntryScreen()),
                      _buildMenuCard(context, 'Settings', Icons.settings, Colors.blueGrey, const SettingsScreen()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, Widget screen) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen)).then((_) => _loadDashboardData());
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 22,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
