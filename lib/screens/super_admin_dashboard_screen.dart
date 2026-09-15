import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _selectedIndex = 0;
  List<UserAccount> _registeredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegisteredCompanies();
  }

  Future<void> _loadRegisteredCompanies() async {
    try {
      final users = await DatabaseHelper.isar.userAccounts.where().findAll();
      if (mounted) {
        setState(() {
          _registeredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForIndex(_selectedIndex)),
        backgroundColor: const Color(0xFF1B365D),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B365D)),
              accountName: Text('Super Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('admin@orlife.erp'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, size: 35, color: Color(0xFF1B365D)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard Overview'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Registered Companies / Users'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_membership),
              title: const Text('Subscription Plans'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('System Settings'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.teal),
              title: const Text('Open Main App (Accounts)', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: _buildBodyContent(),
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0: return 'Super Admin Dashboard';
      case 1: return 'Registered Companies & Parties';
      case 2: return 'Software Subscription Plans';
      case 3: return 'System Settings';
      default: return 'Super Admin';
    }
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return _buildCompaniesListScreen();
      case 2:
        return _buildPlansScreen();
      case 3:
        return _buildSettingsScreen();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome, Master Admin!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Total Companies', '${_registeredUsers.length}', Icons.business, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Active Plans', 'All Enabled', Icons.check_circle, Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCompaniesListScreen() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_registeredUsers.isEmpty) {
      return const Center(child: Text('Abhi tak koi nayi company/user register nahi hui hai.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _registeredUsers.length,
      itemBuilder: (context, index) {
        final user = _registeredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.isApproved ? Colors.green.shade100 : Colors.orange.shade100,
              child: Icon(
                user.isApproved ? Icons.verified : Icons.pending,
                color: user.isApproved ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Mobile ID: ${user.username} | Type: ${user.businessType ?? "General"}'),
            trailing: Switch(
              value: user.isApproved,
              activeColor: Colors.green,
              onChanged: (val) async {
                await DatabaseHelper.isar.writeTxn(() async {
                  user.isApproved = val;
                  await DatabaseHelper.isar.userAccounts.put(user);
                });
                _loadRegisteredCompanies();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlansScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Available Software Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
        const SizedBox(height: 12),
        _buildPlanCard('Basic Retailer Plan', '₹ 4,999 / year', ['Single Device', 'Inventory & Billing', 'Basic Reports'], Colors.teal),
        const SizedBox(height: 12),
        _buildPlanCard('Advanced Manufacturing ERP', '₹ 9,999 / year', ['Multi-User Support', 'BOM & Production', 'Advanced Accounts & Ledger', 'Priority Support'], Colors.indigo),
      ],
    );
  }

  Widget _buildPlanCard(String title, String price, List<String> features, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const Divider(height: 20),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(f, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Master Admin Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Allow Direct New User Signups'),
          subtitle: const Text('If disabled, new users require manual approval'),
          value: true,
          onChanged: (val) {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Change Master Admin Password'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature coming soon!')));
          },
        ),
      ],
    );
  }
}
