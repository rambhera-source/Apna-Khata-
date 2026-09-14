import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/inventory_model.dart';
import '../models/order_model.dart';
import 'orders_management_screen.dart';

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
      final products = await DatabaseHelper.isar.inventoryStocks.where().findAll();
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
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard('Total Parties', '$_totalParties', Icons.people, Colors.blue, null),
                      _buildStatCard('Products / Stock', '$_totalProducts', Icons.inventory, Colors.green, null),
                      _buildStatCard('Pending Orders', '$_pendingOrdersCount', Icons.shopping_cart_checkout, Colors.orange, null),
                      _buildStatCard('Quick Billing', 'New', Icons.receipt_long, Colors.purple, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrdersManagementScreen()),
                        ).then((_) => _loadDashboardData());
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.shopping_cart, color: Colors.amber),
                          title: const Text('Orders & Sales Management', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Book new orders, view history, or manage items'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          tileColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OrdersManagementScreen()),
                            ).then((_) => _loadDashboardData());
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
