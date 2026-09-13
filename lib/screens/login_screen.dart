import 'package:flutter/material.dart';
import 'product_inventory_screen.dart';
import 'purchase_screen.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';
import 'add_account_screen.dart'; // 👈 Add Account screen import kiya

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggedIn = true; // Aapke dashboard flow ke liye
  String _selectedBusinessMode = 'Wholesale';
  final TextEditingController _firmNameController = TextEditingController(text: 'ORLIFE Mobile Accessories');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE Business Hub - Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => setState(() => _isLoggedIn = false),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_firmNameController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountText: Text('Mode: $_selectedBusinessMode'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, color: Colors.teal, size: 40),
              ),
              decoration: const BoxDecoration(color: Colors.teal),
            ),
            // 👥 Add Party / Accounts Option in Sidebar
            ListTile(
              leading: const Icon(Icons.group_add, color: Colors.indigo),
              title: const Text('Add Party & Accounts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.teal),
              title: const Text('Product & Inventory Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: Colors.blue),
              title: const Text('Purchase Bill Entry'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell, color: Colors.orange),
              title: const Text('Sales Invoice Entry'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings & Configuration'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, ${_firmNameController.text} ($_selectedBusinessMode Mode)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // 🏠 Grid Cards on Dashboard Home Page
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // 👥 1. Add Party / Accounts Card
                  _buildDashboardCard(
                    context,
                    title: 'Add Party / Accounts',
                    icon: Icons.group_add,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen())),
                  ),
                  // 📦 2. Inventory Card
                  _buildDashboardCard(
                    context,
                    title: 'Inventory & Stock',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen())),
                  ),
                  // 🛒 3. Purchase Card
                  _buildDashboardCard(
                    context,
                    title: 'Purchase Bill',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen())),
                  ),
                  // 🏷️ 4. Sales Card
                  _buildDashboardCard(
                    context,
                    title: 'Sales Invoice',
                    icon: Icons.sell,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
