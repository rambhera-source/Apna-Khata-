import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import 'orders_management_screen.dart';
// Agar aapne Parties ya Products ki alag screens banayi hain, toh unhe yahan import kar sakte hain:
// import 'parties_screen.dart';
// import 'products_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalParties = 0;
  int _totalProducts = 0;
  int _pendingOrdersCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final parties = await DatabaseHelper.isar.accounts.where().findAll();
      final products = await DatabaseHelper.isar.products.where().findAll();
      final orders = await DatabaseHelper.isar.salesOrders.where().findAll();

      int pendingCount = orders.where((o) => o.status == 'Pending' || o.status.contains('Pending')).length;

      setState(() {
        _totalParties = parties.length;
        _totalProducts = products.length;
        _pendingOrdersCount = pendingCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE / Accounting Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 10),
                        // Quick Stats Summary Card
                        Card(
                          elevation: 3,
                          color: Colors.amber.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Overview Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoItem('Parties', '$_totalParties', Colors.blue),
                                    _buildInfoItem('Products', '$_totalProducts', Colors.green),
                                    _buildInfoItem('Pending', '$_pendingOrdersCount', Colors.orange),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        // 1. Orders & Sales Management
                        _buildActionTile(
                          icon: Icons.shopping_cart,
                          iconColor: Colors.amber,
                          title: 'Orders & Sales Management',
                          subtitle: 'Book new orders, view history, or manage items',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OrdersManagementScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                        ),
                        const SizedBox(height: 10),

                        // 2. Parties / Customers Khata
                        _buildActionTile(
                          icon: Icons.people,
                          iconColor: Colors.blue,
                          title: 'Parties & Customers',
                          subtitle: 'Manage dealers, customers & ledger balances',
                          onTap: () {
                            // Yahan apni Parties screen ka route lagayein agar hai
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Parties Screen par navigate karne ke liye route jodein!')),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 3. Inventory / Products Catalog
                        _buildActionTile(
                          icon: Icons.inventory_2,
                          iconColor: Colors.green,
                          title: 'Inventory & Products',
                          subtitle: 'Manage chargers, batteries, accessories stock',
                          onTap: () {
                            // Yahan apni Products screen ka route lagayein
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Products Inventory Screen jodein!')),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 4. Reports & Daybook
                        _buildActionTile(
                          icon: Icons.bar_chart,
                          iconColor: Colors.purple,
                          title: 'Business Reports & Daybook',
                          subtitle: 'View sales analytics, PDF/Excel reports',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reports module jodein!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      tileColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}
