import 'package:flutter/material.dart';
import 'product_inventory_screen.dart';
import 'purchase_screen.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggedIn = false; // Check karega ki user logged in hai ya nahi
  bool _isSignupMode = false; // Toggle karne ke liye (Login vs Signup)

  // Controllers for Form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Handle Login or Signup submission
  void _submitAuth() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Email aur Password bharein!')),
      );
      return;
    }

    // Success hone par user ko Dashboard par bhej denge
    setState(() {
      _isLoggedIn = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSignupMode ? 'Account Successfully Created!' : 'Login Successful!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agar user logged in nahi hai, toh Login/Signup Form dikhao
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.store, size: 60, color: Colors.teal),
                    const SizedBox(height: 12),
                    Text(
                      _isSignupMode ? 'Create New Account' : 'Welcome to ORLIFE',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignupMode ? 'Sign up to get started' : 'Login to your account',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Name field sirf Signup ke time dikhegi
                    if (_isSignupMode) ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitAuth,
                      child: Text(_isSignupMode ? 'Sign Up' : 'Login', style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 12),

                    // Switch between Login and Signup mode
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignupMode = !_isSignupMode;
                        });
                      },
                      child: Text(
                        _isSignupMode ? 'Already have an account? Login here' : 'New user? Create an account (Sign Up)',
                        style: const TextStyle(color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ==========================================
    // AGAR USER LOGGED IN HAI, TOH MAIN DASHBOARD DIKHAO
    // ==========================================
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE Business Hub - Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              setState(() {
                _isLoggedIn = false; // Logout karke wapas login screen par le aayega
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('ORLIFE Mobile Accessories', style: TextStyle(fontWeight: FontWeight.bold)),
              accountText: Text('Admin Dashboard'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, color: Colors.teal, size: 40),
              ),
              decoration: BoxDecoration(color: Colors.teal),
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
            const Text(
              'Welcome to ORLIFE Management System',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
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
                    title: 'Sales Invoice',
                    icon: Icons.sell,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen())),
                  ),
                  _buildDashboardCard(
                    context,
                    title: 'Settings',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
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
