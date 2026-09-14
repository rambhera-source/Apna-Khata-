import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'orders_management_screen.dart';

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
  
  // Focus node for capturing PC keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      _businessType = widget.currentUser!.businessType;
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

  // ⌨️ Action Handlers for Hotkeys
  void _openLedger() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [Ctrl+L]: Ledger & Parties Screen Open')));
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrdersManagementScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _openSaleBilling() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [F8]: Sale Billing / Invoice Screen Open')));
  }

  void _openPayment() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [F5]: Payment Voucher Open')));
  }

  void _openReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [F6]: Receipt Voucher Open')));
  }

  void _openGeneralVoucher() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [F7]: General Voucher Open')));
  }

  void _openInventory() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [Ctrl+I]: Inventory & Products Screen Open')));
  }

  void _openPurchase() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [Ctrl+P]: Purchase Entry Screen Open')));
  }

  void _openManufacturing(bool isMfg) {
    if (isMfg) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shortcut [Ctrl+M]: BOM & Production Module Open!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeh module sirf Manufacturing users ke liye hai!'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isManufacturing = _businessType.toLowerCase().contains('manufactur');

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // ⌨️ Professional Accounting Hotkeys Mapping
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
              isManufacturing ? 'ORLIFE / Factory Dashboard (ERP Hotkeys Active)' : 'ORLIFE / Accounting Dashboard (ERP Hotkeys Active)', 
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      // ================= WINDOWS / PC DESKTOP LAYOUT =================
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
                            // Right Side: PC Professional Accounting Vouchers & Hotkeys Guide
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
                                      const Text('💻 ERP Hotkeys Guide', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // ================= ANDROID MOBILE LAYOUT =================
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
        _buildActionTile(
          icon: Icons.receipt,
          iconColor: Colors.green,
          title: 'Sale Billing [F8]',
          subtitle: 'Create sale invoices & billing',
          onTap: _openSaleBilling,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.shopping_bag,
          iconColor: Colors.blue,
          title: 'Purchase Entry [Ctrl+P]',
          subtitle: 'Manage supplier purchases & stock in',
          onTap: _openPurchase,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.account_balance_wallet,
          iconColor: Colors.indigo,
          title: 'Ledger & Parties [Ctrl+L]',
          subtitle: 'Manage customer/supplier ledger balances',
          onTap: _openLedger,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.shopping_cart,
          iconColor: Colors.amber,
          title: 'Orders & Sales [Ctrl+O]',
          subtitle: 'Book new orders, view history',
          onTap: _openOrders,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.inventory_2,
          iconColor: Colors.orange,
          title: 'Inventory & Products [Ctrl+I]',
          subtitle: 'Manage chargers, batteries, accessories stock',
          onTap: _openInventory,
        ),
        if (isManufacturing) ...[
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.precision_manufacturing,
            iconColor: Colors.deepPurple,
            title: 'BOM & Production [Ctrl+M]',
            subtitle: 'Manage bill of materials & production batches',
            onTap: () => _openManufacturing(true),
          ),
        ],
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.payment,
          iconColor: Colors.red,
          title: 'Payment Voucher [F5]',
          subtitle: 'Record payments made',
          onTap: _openPayment,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.request_quote,
          iconColor: Colors.teal,
          title: 'Receipt Voucher [F6]',
          subtitle: 'Record money received',
          onTap: _openReceipt,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.note_alt,
          iconColor: Colors.brown,
          title: 'General Voucher [F7]',
          subtitle: 'Journal & general accounting entries',
          onTap: _openGeneralVoucher,
        ),
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
