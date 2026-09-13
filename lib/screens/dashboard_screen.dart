import 'package:flutter/material.dart';
import 'sales_screen.dart';
import 'purchase_screen.dart';
import 'sales_return_screen.dart';
import 'purchase_return_screen.dart';
import 'product_inventory_screen.dart';
import 'manufacturing_screen.dart'; 
import 'super_admin_dashboard_screen.dart'; 
import 'backup_settings_screen.dart'; 
import 'settings_screen.dart'; 
import 'voucher_entry_screen.dart'; // ✅ Naya Accounting Voucher Entry screen import kiya gaya hai

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE Mobile Accessories - ERP'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // ⚙️ Company & GST Settings Button
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            tooltip: 'Company & GST Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          // 🛡️ Super Admin Control Button
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, size: 28),
            tooltip: 'Super Admin Control',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
              );
            },
          ),
          // 💾 Backup & Restore Manager Button
          IconButton(
            icon: const Icon(Icons.backup, size: 26),
            tooltip: 'Storage & Backup Manager',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Welcome Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.storefront, size: 40, color: Colors.white),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORLIFE Management Hub',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Billing, Inventory & Accounting Control',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Quick Access Modules:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Grid Menu for Modules
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  // 1. Sales Module
                  _buildDashboardCard(
                    context,
                    title: 'Sales Invoice',
                    icon: Icons.point_of_sale,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())),
                  ),

                  // 2. Purchase Module
                  _buildDashboardCard(
                    context,
                    title: 'Purchase Bill',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen())),
                  ),

                  // 3. Sales Return Module
                  _buildDashboardCard(
                    context,
                    title: 'Sales Return',
                    icon: Icons.assignment_return,
                    color: Colors.deepOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReturnScreen())),
                  ),

                  // 4. Purchase Return Module
                  _buildDashboardCard(
                    context,
                    title: 'Purchase Return',
                    icon: Icons.remove_shopping_cart,
                    color: Colors.redAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseReturnScreen())),
                  ),

                  // 5. Inventory Management
                  _buildDashboardCard(
                    context,
                    title: 'Inventory Stock',
                    icon: Icons.inventory_2,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen())),
                  ),

                  // 6. Manufacturing & BOM Dashboard
                  _buildDashboardCard(
                    context,
                    title: 'Manufacturing & BOM',
                    icon: Icons.precision_manufacturing,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManufacturingScreen())),
                  ),

                  // 7. 🔥 Accounting Voucher Entry (Payment, Receipt, Journal)
                  _buildDashboardCard(
                    context,
                    title: 'Vouchers (Pay/Rcpt)',
                    icon: Icons.account_balance_wallet,
                    color: Colors.amber.shade900,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
