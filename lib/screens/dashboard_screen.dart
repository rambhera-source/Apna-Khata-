import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sales_screen.dart';
import 'purchase_screen.dart';
import 'sales_return_screen.dart';
import 'purchase_return_screen.dart';
import 'product_inventory_screen.dart';
import 'manufacturing_screen.dart'; 
import 'super_admin_dashboard_screen.dart'; 
import 'backup_settings_screen.dart'; 
import 'settings_screen.dart'; 
import 'voucher_entry_screen.dart'; 
import 'ledger_screen.dart';

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
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            tooltip: 'Company & GST Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, size: 28),
            tooltip: 'Super Admin Control',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.backup, size: 26),
            tooltip: 'Storage & Backup Manager',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSettingsScreen())),
          ),
        ],
      ),
      body: Row(
        children: [
          // ================= LEFT / MAIN CONTENT AREA =================
          Expanded(
            flex: 3,
            child: Padding(
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
                              'Fast Desktop Billing, Inventory & Accounting Suite',
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
                      crossAxisCount: 3, // 3 columns taaki grid balanced rahe
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _buildDashboardCard(context, title: 'Sales Invoice', icon: Icons.point_of_sale, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
                        _buildDashboardCard(context, title: 'Purchase Bill', icon: Icons.shopping_cart, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseScreen()))),
                        _buildDashboardCard(context, title: 'Sales Return', icon: Icons.assignment_return, color: Colors.deepOrange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReturnScreen()))),
                        _buildDashboardCard(context, title: 'Purchase Return', icon: Icons.remove_shopping_cart, color: Colors.redAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReturnScreen()))),
                        _buildDashboardCard(context, title: 'Inventory Stock', icon: Icons.inventory_2, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductInventoryScreen()))),
                        _buildDashboardCard(context, title: 'Manufacturing & BOM', icon: Icons.precision_manufacturing, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManufacturingScreen()))),
                        _buildDashboardCard(context, title: 'Vouchers (Pay/Rcpt)', icon: Icons.account_balance_wallet, color: Colors.amber.shade900, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherEntryScreen()))),
                        _buildDashboardCard(context, title: 'Account Ledger', icon: Icons.menu_book, color: Colors.indigo.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen()))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= RIGHT SIDE: SHORTCUTS & QUICK ACTIONS PANEL =================
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(left: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade900,
                  child: const Row(
                    children: [
                      Icon(Icons.keyboard, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Keyboard Shortcuts',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    'Click any shortcut or use keys:',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),

                // Shortcut List Items (Clickable & Informative)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _buildShortcutTile(context, title: 'Sales Invoice', shortcut: 'Ctrl + S', icon: Icons.point_of_sale, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
                      _buildShortcutTile(context, title: 'Purchase Bill', shortcut: 'Ctrl + P', icon: Icons.shopping_cart, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseScreen()))),
                      _buildShortcutTile(context, title: 'Payment Voucher', shortcut: 'Alt + P', icon: Icons.payment, color: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherEntryScreen()))),
                      _buildShortcutTile(context, title: 'Receipt Voucher', shortcut: 'Alt + R', icon: Icons.receipt, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherEntryScreen()))),
                      _buildShortcutTile(context, title: 'Journal Entry', shortcut: 'Alt + J', icon: Icons.note_alt, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherEntryScreen()))),
                      _buildShortcutTile(context, title: 'Account Ledger', shortcut: 'Ctrl + L', icon: Icons.menu_book, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen()))),
                      _buildShortcutTile(context, title: 'Inventory Stock', shortcut: 'Ctrl + I', icon: Icons.inventory_2, color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductInventoryScreen()))),
                    ],
                  ),
                ),

                // Footer note inside sidebar
                Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  child: const Text(
                    'ORLIFE ERP v1.0 • Desktop Ready',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Grid Dashboard Card Builder
  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 24, color: color),
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
      ),
    );
  }

  // Right Sidebar Shortcut Tile Builder
  Widget _buildShortcutTile(
    BuildContext context, {
    required String title,
    required String shortcut,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(
            shortcut,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
