import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'orders_management_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserAccount? currentUser;
  const DashboardScreen({super.key, this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalParties = 0;
  int _totalProducts = 0;
  int _pendingOrdersCount = 0;
  bool _isLoading = true;
  String _businessType = 'Wholesaler / Retailer';
  String _userName = 'ORLIFE ERP User';

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      _businessType = widget.currentUser!.businessType;
      _userName = widget.currentUser!.name.isNotEmpty ? widget.currentUser!.name : 'ORLIFE ERP';
    }
    _loadDashboardData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

  // ⌨️ Action Handlers for Hotkeys & Button Clicks
  void _openLedger() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ledger & Parties Screen Open [Ctrl+L]')));
  }

  void _openOrders() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrdersManagementScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _openSaleBilling() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale Billing / Invoice Screen Open [F8]')));
  }

  void _openPayment() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Voucher Open [F5]')));
  }

  void _openReceipt() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt Voucher Open [F6]')));
  }

  void _openGeneralVoucher() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('General Voucher Open [F7]')));
  }

  void _openInventory() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory & Products Screen Open [Ctrl+I]')));
  }

  void _openPurchase() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Entry Screen Open [Ctrl+P]')));
  }

  void _openManufacturing(bool isMfg) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    if (isMfg) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BOM & Production Module Open! [Ctrl+M]')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeh module sirf Manufacturing users ke liye hai!'), backgroundColor: Colors.red));
    }
  }

  // 🚪 Logout Handler
  void _handleLogout() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isManufacturing = _businessType.toLowerCase().contains('manufactur');

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): _openLedger,
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openOrders,
          const SingleActivator(LogicalKeyboardKey.f8): _openSaleBilling,
          const SingleActivator(LogicalKeyboardKey.f5): _openPayment,
          const SingleActivator(LogicalKeyboardKey.f6): _openReceipt,
          const SingleActivator(LogicalKeyboardKey.f7): _openGeneralVoucher,
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): _openInventory,
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): _openPurchase,
          const SingleActivator(LogicalKeyboardKey.keyM, control: true): () => _openManufacturing(isManufacturing),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              isManufacturing ? 'ORLIFE / Factory Dashboard' : 'ORLIFE / Accounting Dashboard', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
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
          
          // 📱 MOBILE LEFT SIDEBAR (DRAWER) - Fixed Touch / Tap Issues
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.amber.shade900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24,
                        child: Icon(Icons.business, color: Colors.brown, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _userName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: $_businessType',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.green),
                  title: const Text('Sale Billing [F8]'),
                  onTap: _openSaleBilling,
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                  title: const Text('Purchase Entry [Ctrl+P]'),
                  onTap: _openPurchase,
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.indigo),
                  title: const Text('Ledger & Parties [Ctrl+L]'),
                  onTap: _openLedger,
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.amber),
                  title: const Text('Orders & Sales [Ctrl+O]'),
                  onTap: _openOrders,
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.orange),
                  title: const Text('Inventory & Products [Ctrl+I]'),
                  onTap: _openInventory,
                ),
                if (isManufacturing)
                  ListTile(
                    leading: const Icon(Icons.precision_manufacturing, color: Colors.deepPurple),
                    title: const Text('BOM & Production [Ctrl+M]'),
                    onTap: () => _openManufacturing(true),
                  ),
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.red),
                  title: const Text('Payment Voucher [F5]'),
                  onTap: _openPayment,
                ),
                ListTile(
                  leading: const Icon(Icons.request_quote, color: Colors.teal),
                  title: const Text('Receipt Voucher [F6]'),
                  onTap: _openReceipt,
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt, color: Colors.brown),
                  title: const Text('General Voucher [F7]'),
                  onTap: _openGeneralVoucher,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: _handleLogout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      // ================= PC / DESKTOP LAYOUT (With Right Shortcuts Panel) =================
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ListView(
                                children: [
                                  _buildSummaryCard(isManufacturing),
                                  const SizedBox(height: 20),
                                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  _buildMainActionsList(isManufacturing),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right Side: PC Quick Shortcuts Panel
                            Expanded(
                              flex: 1,
                              child: Card(
                                elevation: 3,
                                color: Colors.blue.shade50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('💻 PC ERP Hotkeys', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                      const Divider(),
                                      const SizedBox(height: 4),
                                      _buildShortcutButton('Ledger [Ctrl+L]', Icons.account_balance_wallet, Colors.indigo, _openLedger),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Sale Bill [F8]', Icons.receipt, Colors.green, _openSaleBilling),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Purchase [Ctrl+P]', Icons.shopping_bag, Colors.blue, _openPurchase),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Order [Ctrl+O]', Icons.add_shopping_cart, Colors.amber, _openOrders),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Payment [F5]', Icons.payment, Colors.red, _openPayment),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Receipt [F6]', Icons.request_quote, Colors.teal, _openReceipt),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Gen Voucher [F7]', Icons.note_alt, Colors.brown, _openGeneralVoucher),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Inventory [Ctrl+I]', Icons.inventory_2, Colors.orange, _openInventory),
                                      if (isManufacturing) ...[
                                        const SizedBox(height: 6),
                                        _buildShortcutButton('BOM/Mfg [Ctrl+M]', Icons.precision_manufacturing, Colors.deepPurple, () => _openManufacturing(true)),
                                      ],
                                      const Divider(),
                                      _buildShortcutButton('Logout', Icons.logout, Colors.red, _handleLogout),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // ================= MOBILE LAYOUT (Clean Single Column) =================
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView(
                          children: [
                            _buildSummaryCard(isManufacturing),
                            const SizedBox(height: 20),
                            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildMainActionsList(isManufacturing),
                          ],
                        ),
                      );
                    }
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isManufacturing) {
    return Card(
      elevation: 3,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isManufacturing ? 'Overview Summary (Factory Mode)' : 'Overview Summary', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)
            ),
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
    );
  }

  Widget _buildMainActionsList(bool isManufacturing) {
    return Column(
      children: [
        _buildActionTile(icon: Icons.receipt, iconColor: Colors.green, title: 'Sale Billing [F8]', subtitle: 'Create sale invoices & billing', onTap: _openSaleBilling),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.shopping_bag, iconColor: Colors.blue, title: 'Purchase Entry [Ctrl+P]', subtitle: 'Manage supplier purchases & stock in', onTap: _openPurchase),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.account_balance_wallet, iconColor: Colors.indigo, title: 'Ledger & Parties [Ctrl+L]', subtitle: 'Manage customer/supplier ledger balances', onTap: _openLedger),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.shopping_cart, iconColor: Colors.amber, title: 'Orders & Sales [Ctrl+O]', subtitle: 'Book new orders, view history', onTap: _openOrders),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.inventory_2, iconColor: Colors.orange, title: 'Inventory & Products [Ctrl+I]', subtitle: 'Manage chargers, batteries, accessories stock', onTap: _openInventory),
        if (isManufacturing) ...[
          const SizedBox(height: 10),
          _buildActionTile(icon: Icons.precision_manufacturing, iconColor: Colors.deepPurple, title: 'BOM & Production [Ctrl+M]', subtitle: 'Manage bill of materials & production batches', onTap: () => _openManufacturing(true)),
        ],
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.payment, iconColor: Colors.red, title: 'Payment Voucher [F5]', subtitle: 'Record payments made', onTap: _openPayment),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.request_quote, iconColor: Colors.teal, title: 'Receipt Voucher [F6]', subtitle: 'Record money received', onTap: _openReceipt),
        const SizedBox(height: 10),
        _buildActionTile(icon: Icons.note_alt, iconColor: Colors.brown, title: 'General Voucher [F7]', subtitle: 'Journal & general accounting entries', onTap: _openGeneralVoucher),
      ],
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

  Widget _buildActionTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
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

  Widget _buildShortcutButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, color: color, size: 16),
        label: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
    );
  }
}
