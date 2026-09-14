import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

// ✅ All Screens Imported (Including AddAccountScreen)
import 'sales_screen.dart';
import 'sales_return_screen.dart';
import 'purchase_screen.dart';
import 'purchase_return_screen.dart';
import 'ledger_screen.dart';
import 'orders_management_screen.dart';
import 'product_inventory_screen.dart';
import 'manufacturing_screen.dart';
import 'voucher_entry_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'add_account_screen.dart'; // 🔥 Added Import

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
  bool _isGridView = false; 
  String _businessType = 'Wholesaler / Retailer';
  String _userName = 'ORLIFE ERP User';

  // 📌 Module Visibility Map
  final Map<String, bool> _visibleModules = {
    'add_account': true,
    'sale_billing': true,
    'sales_return': true,
    'purchase': true,
    'purchase_return': true,
    'ledger': true,
    'orders': true,
    'inventory': true,
    'manufacturing': true,
    'payment': true,
    'receipt': true,
    'general_voucher': true,
    'settings': true,
  };

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

  // 🛠️ Open Customization Dialog
  void _showCustomizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Customize Home Icons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _visibleModules.keys.map((key) {
                    String title = key.replaceAll('_', ' ').toUpperCase();
                    return CheckboxListTile(
                      title: Text(title, style: const TextStyle(fontSize: 14)),
                      value: _visibleModules[key],
                      activeColor: Colors.amber.shade900,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          _visibleModules[key] = value ?? true;
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🔗 Navigation Methods
  void _openAddAccount() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen())).then((_) => _loadDashboardData());
  }

  void _openLedger() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LedgerScreen())).then((_) => _loadDashboardData());
  }

  void _openOrders() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersManagementScreen())).then((_) => _loadDashboardData());
  }

  void _openSaleBilling() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())).then((_) => _loadDashboardData());
  }

  void _openSalesReturn() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReturnScreen())).then((_) => _loadDashboardData());
  }

  void _openPurchase() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseScreen())).then((_) => _loadDashboardData());
  }

  void _openPurchaseReturn() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseReturnScreen())).then((_) => _loadDashboardData());
  }

  void _openInventory() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductInventoryScreen())).then((_) => _loadDashboardData());
  }

  void _openManufacturing(bool isMfg) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    if (isMfg) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManufacturingScreen())).then((_) => _loadDashboardData());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeh module sirf Manufacturing users ke liye hai!'), backgroundColor: Colors.red));
    }
  }

  void _openPayment() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen())).then((_) => _loadDashboardData());
  }

  void _openReceipt() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen())).then((_) => _loadDashboardData());
  }

  void _openGeneralVoucher() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const VoucherEntryScreen())).then((_) => _loadDashboardData());
  }

  void _openSettings() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadDashboardData());
  }

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
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): _openAddAccount,
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
                icon: const Icon(Icons.dashboard_customize),
                tooltip: 'Customize Home Icons',
                onPressed: _showCustomizeDialog,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: _openSettings,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          
          // 📱 MOBILE LEFT SIDEBAR (DRAWER)
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
                  leading: const Icon(Icons.person_add, color: Colors.teal),
                  title: const Text('Add Account / Party'),
                  onTap: _openAddAccount,
                ),
                ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.green),
                  title: const Text('Sale Billing'),
                  onTap: _openSaleBilling,
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_return, color: Colors.greenAccent),
                  title: const Text('Sales Return'),
                  onTap: _openSalesReturn,
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                  title: const Text('Purchase Entry'),
                  onTap: _openPurchase,
                ),
                ListTile(
                  leading: const Icon(Icons.keyboard_return, color: Colors.blueAccent),
                  title: const Text('Purchase Return'),
                  onTap: _openPurchaseReturn,
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.indigo),
                  title: const Text('Ledger & Parties'),
                  onTap: _openLedger,
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.amber),
                  title: const Text('Orders & Sales'),
                  onTap: _openOrders,
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.orange),
                  title: const Text('Inventory & Products'),
                  onTap: _openInventory,
                ),
                if (isManufacturing)
                  ListTile(
                    leading: const Icon(Icons.precision_manufacturing, color: Colors.deepPurple),
                    title: const Text('BOM & Production'),
                    onTap: () => _openManufacturing(true),
                  ),
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.red),
                  title: const Text('Payment Voucher'),
                  onTap: _openPayment,
                ),
                ListTile(
                  leading: const Icon(Icons.request_quote, color: Colors.teal),
                  title: const Text('Receipt Voucher'),
                  onTap: _openReceipt,
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt, color: Colors.brown),
                  title: const Text('General Voucher'),
                  onTap: _openGeneralVoucher,
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blueGrey),
                  title: const Text('Settings & Backup'),
                  onTap: _openSettings,
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
                      // ================= PC / DESKTOP LAYOUT =================
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
                                      _buildShortcutButton('Add Account [Ctrl+A]', Icons.person_add, Colors.teal, _openAddAccount),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Ledger [Ctrl+L]', Icons.account_balance_wallet, Colors.indigo, _openLedger),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Sale Bill [F8]', Icons.receipt, Colors.green, _openSaleBilling),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Sales Return', Icons.assignment_return, Colors.greenAccent, _openSalesReturn),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Purchase [Ctrl+P]', Icons.shopping_bag, Colors.blue, _openPurchase),
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Purchase Return', Icons.keyboard_return, Colors.blueAccent, _openPurchaseReturn),
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
                                      const SizedBox(height: 6),
                                      _buildShortcutButton('Settings', Icons.settings, Colors.blueGrey, _openSettings),
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
                      // ================= MOBILE LAYOUT =================
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildSummaryCard(isManufacturing),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.tune, color: Colors.brown),
                                      tooltip: 'Customize Icons',
                                      onPressed: _showCustomizeDialog,
                                    ),
                                    ToggleButtons(
                                      isSelected: [!_isGridView, _isGridView],
                                      onPressed: (index) {
                                        setState(() {
                                          _isGridView = index == 1;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      selectedColor: Colors.white,
                                      fillColor: Colors.amber.shade900,
                                      color: Colors.black87,
                                      constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                                      children: const [
                                        Icon(Icons.view_list, size: 18),
                                        Icon(Icons.grid_view, size: 18),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _isGridView 
                                  ? _buildMainActionsGrid(isManufacturing)
                                  : ListView(
                                      children: [
                                        _buildMainActionsList(isManufacturing),
                                      ],
                                    ),
                            ),
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
    List<Widget> tiles = [];

    if (_visibleModules['add_account']!) {
      tiles.add(_buildActionTile(icon: Icons.person_add, iconColor: Colors.teal, title: 'Add Account / Party', subtitle: 'Create new customer, supplier or ledger', onTap: _openAddAccount));
    }
    if (_visibleModules['sale_billing']!) {
      tiles.add(_buildActionTile(icon: Icons.receipt, iconColor: Colors.green, title: 'Sale Billing', subtitle: 'Create sale invoices & billing', onTap: _openSaleBilling));
    }
    if (_visibleModules['sales_return']!) {
      tiles.add(_buildActionTile(icon: Icons.assignment_return, iconColor: Colors.greenAccent, title: 'Sales Return', subtitle: 'Manage customer product returns / credit notes', onTap: _openSalesReturn));
    }
    if (_visibleModules['purchase']!) {
      tiles.add(_buildActionTile(icon: Icons.shopping_bag, iconColor: Colors.blue, title: 'Purchase Entry', subtitle: 'Manage supplier purchases & stock in', onTap: _openPurchase));
    }
    if (_visibleModules['purchase_return']!) {
      tiles.add(_buildActionTile(icon: Icons.keyboard_return, iconColor: Colors.blueAccent, title: 'Purchase Return', subtitle: 'Manage returns to suppliers / debit notes', onTap: _openPurchaseReturn));
    }
    if (_visibleModules['ledger']!) {
      tiles.add(_buildActionTile(icon: Icons.account_balance_wallet, iconColor: Colors.indigo, title: 'Ledger & Parties', subtitle: 'Manage customer/supplier ledger balances', onTap: _openLedger));
    }
    if (_visibleModules['orders']!) {
      tiles.add(_buildActionTile(icon: Icons.shopping_cart, iconColor: Colors.amber, title: 'Orders & Sales', subtitle: 'Book new orders, view history', onTap: _openOrders));
    }
    if (_visibleModules['inventory']!) {
      tiles.add(_buildActionTile(icon: Icons.inventory_2, iconColor: Colors.orange, title: 'Inventory & Products', subtitle: 'Manage chargers, batteries, accessories stock', onTap: _openInventory));
    }
    if (isManufacturing && _visibleModules['manufacturing']!) {
      tiles.add(_buildActionTile(icon: Icons.precision_manufacturing, iconColor: Colors.deepPurple, title: 'BOM & Production', subtitle: 'Manage bill of materials & production batches', onTap: () => _openManufacturing(true)));
    }
    if (_visibleModules['payment']!) {
      tiles.add(_buildActionTile(icon: Icons.payment, iconColor: Colors.red, title: 'Payment Voucher', subtitle: 'Record payments made', onTap: _openPayment));
    }
    if (_visibleModules['receipt']!) {
      tiles.add(_buildActionTile(icon: Icons.request_quote, iconColor: Colors.teal, title: 'Receipt Voucher', subtitle: 'Record money received', onTap: _openReceipt));
    }
    if (_visibleModules['general_voucher']!) {
      tiles.add(_buildActionTile(icon: Icons.note_alt, iconColor: Colors.brown, title: 'General Voucher', subtitle: 'Journal & general accounting entries', onTap: _openGeneralVoucher));
    }
    if (_visibleModules['settings']!) {
      tiles.add(_buildActionTile(icon: Icons.settings, iconColor: Colors.blueGrey, title: 'Settings & Backup', subtitle: 'Configure software & data backup', onTap: _openSettings));
    }

    List<Widget> spacedTiles = [];
    for (int i = 0; i < tiles.length; i++) {
      spacedTiles.add(tiles[i]);
      if (i < tiles.length - 1) spacedTiles.add(const SizedBox(height: 10));
    }

    return Column(children: spacedTiles);
  }

  Widget _buildMainActionsGrid(bool isManufacturing) {
    final List<Map<String, dynamic>> allItems = [
      {'key': 'add_account', 'icon': Icons.person_add, 'color': Colors.teal, 'title': 'Add Account', 'onTap': _openAddAccount},
      {'key': 'sale_billing', 'icon': Icons.receipt, 'color': Colors.green, 'title': 'Sale Billing', 'onTap': _openSaleBilling},
      {'key': 'sales_return', 'icon': Icons.assignment_return, 'color': Colors.greenAccent, 'title': 'Sales Return', 'onTap': _openSalesReturn},
      {'key': 'purchase', 'icon': Icons.shopping_bag, 'color': Colors.blue, 'title': 'Purchase', 'onTap': _openPurchase},
      {'key': 'purchase_return', 'icon': Icons.keyboard_return, 'color': Colors.blueAccent, 'title': 'Pur. Return', 'onTap': _openPurchaseReturn},
      {'key': 'ledger', 'icon': Icons.account_balance_wallet, 'color': Colors.indigo, 'title': 'Ledger', 'onTap': _openLedger},
      {'key': 'orders', 'icon': Icons.shopping_cart, 'color': Colors.amber, 'title': 'Orders', 'onTap': _openOrders},
      {'key': 'inventory', 'icon': Icons.inventory_2, 'color': Colors.orange, 'title': 'Inventory', 'onTap': _openInventory},
      {'key': 'manufacturing', 'icon': Icons.precision_manufacturing, 'color': Colors.deepPurple, 'title': 'BOM/Mfg', 'onTap': () => _openManufacturing(true)},
      {'key': 'payment', 'icon': Icons.payment, 'color': Colors.red, 'title': 'Payment', 'onTap': _openPayment},
      {'key': 'receipt', 'icon': Icons.request_quote, 'color': Colors.teal, 'title': 'Receipt', 'onTap': _openReceipt},
      {'key': 'general_voucher', 'icon': Icons.note_alt, 'color': Colors.brown, 'title': 'Gen Voucher', 'onTap': _openGeneralVoucher},
      {'key': 'settings', 'icon': Icons.settings, 'color': Colors.blueGrey, 'title': 'Settings', 'onTag': _openSettings},
    ];

    final List<Map<String, dynamic>> filteredItems = allItems.where((item) {
      if (item['key'] == 'manufacturing' && !isManufacturing) return false;
      return _visibleModules[item['key']] ?? true;
    }).toList();

    return GridView.builder(
      itemCount: filteredItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return InkWell(
          onTap: item['onTap'],
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'], color: item['color'], size: 36),
                const SizedBox(height: 8),
                Text(
                  item['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
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
