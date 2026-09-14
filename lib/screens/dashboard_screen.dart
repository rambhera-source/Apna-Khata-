import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
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
      final products = await DatabaseHelper.isar.products.where().findAll(); // 🔥 Yahan inventoryStocks se products kar diya hai
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
                        // Quick Stats & Billing Card
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
                        ListTile(
                          leading: const Icon(Icons.shopping_cart, color: Colors.amber, size: 28),
                          title: const Text('Orders & Sales Management', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: const Text('Book new orders, view history, or manage items'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          tileColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildInfoItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }
}
