import 'package:flutter/material.dart';
import 'add_account_screen.dart';
import 'product_inventory_screen.dart';
import 'purchase_screen.dart';
import 'sales_screen.dart';
import 'purchase_return_screen.dart';
import 'sales_return_screen.dart';
import 'bulk_import_screen.dart';
import 'backup_settings_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggedIn = true;
  final String _selectedBusinessMode = 'Wholesale';
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
              title: const Text('Product & Inventory'),
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
              leading: const Icon(Icons.keyboard_return, color: Colors.redAccent),
              title: const Text('Purchase Return'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseReturnScreen()));
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
            ListTile(
              leading: const Icon(Icons.assignment_return, color: Colors.deepOrange),
              title: const Text('Sales Return'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReturnScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.purple),
              title: const Text('Bulk Data Import'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BulkImportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.teal),
              title: const Text('Backup & Restore Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupSettingsScreen()));
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
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildDashboardCard(
                    context,
                    title: 'Add Party / Accounts',
                    icon: Icons.group_add,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Inventory & Stock',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Purchase Bill',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Purchase Return',
                    icon: Icons.keyboard_return,
                    color: Colors.redAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseReturnScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Sales Invoice',
                    icon: Icons.sell,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Sales Return',
                    icon: Icons.assignment_return,
                    color: Colors.deepOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReturnScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Bulk Import',
                    icon: Icons.upload_file,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BulkImportScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Backup & Restore',
                    icon: Icons.backup,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupSettingsScreen())),
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
