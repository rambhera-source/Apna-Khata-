import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Pincode fetch karne ke liye http package
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
  bool _isLoggedIn = false;
  bool _isSignupMode = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _addressController = TextEditingController();
  
  String _selectedBusinessMode = 'Wholesale';
  bool _isLoadingPincode = false;

  // 🌍 Pincode Auto-Fetch Function (India Post API)
  Future<void> _fetchCityStateByPincode(String pincode) async {
    if (pincode.length != 6) return;

    setState(() => _isLoadingPincode = true);

    try {
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _cityController.text = postOffice['District'] ?? postOffice['Region'] ?? '';
            _stateController.text = postOffice['State'] ?? '';
            _addressController.text = '${postOffice['Name']}, ${_cityController.text}, ${_stateController.text} - $pincode';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Galat Pincode! Kripya sahi PIN code darj karein.')),
          );
        }
      }
    } catch (e) {
      // Network error handling
    } finally {
      setState(() => _isLoadingPincode = false);
    }
  }

  void _submitAuth() {
    if (_isSignupMode) {
      if (_firmNameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kripya Firm Name, Phone, Email aur Password zaroor bharein!')),
        );
        return;
      }
    } else {
      if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kripya Email aur Password darj karein!')),
        );
        return;
      }
    }

    setState(() => _isLoggedIn = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSignupMode ? 'Account Created! Mode: $_selectedBusinessMode' : 'Login Successful!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.store, size: 50, color: Colors.teal),
                    const SizedBox(height: 8),
                    Text(
                      _isSignupMode ? 'Create ORLIFE Business Account' : 'Welcome Back to ORLIFE',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignupMode ? 'Enter your firm & business details' : 'Login to access your inventory hub',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // ================= SIGNUP FIELDS =================
                    if (_isSignupMode) ...[
                      TextField(
                        controller: _firmNameController,
                        decoration: const InputDecoration(labelText: 'Firm / Business Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ownerNameController,
                        decoration: const InputDecoration(labelText: 'Owner / Contact Person Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _gstController,
                        decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long)),
                      ),
                      const SizedBox(height: 12),
                      
                      // PINCODE FIELD WITH AUTO-FETCH
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'Pincode (Auto-Fill City/State)',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.pin_drop),
                                counterText: '',
                                suffixIcon: _isLoadingPincode
                                    ? const Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                if (value.length == 6) {
                                  _fetchCityStateByPincode(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CITY & STATE (Auto Filled)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'City / District', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _stateController,
                              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                      ),
                      const SizedBox(height: 16),

                      // Business Mode Selection
                      const Text('Select Business Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Wholesale', style: TextStyle(fontSize: 13)),
                              value: 'Wholesale',
                              groupValue: _selectedBusinessMode,
                              activeColor: Colors.teal,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _selectedBusinessMode = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Manufacturing', style: TextStyle(fontSize: 13)),
                              value: 'Manufacturing',
                              groupValue: _selectedBusinessMode,
                              activeColor: Colors.teal,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _selectedBusinessMode = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // COMMON FIELDS (Email & Password)
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitAuth,
                      child: Text(_isSignupMode ? 'Register & Setup Account' : 'Login', style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () => setState(() => _isSignupMode = !_isSignupMode),
                      child: Text(
                        _isSignupMode ? 'Already have an account? Login here' : 'New user? Create a Business Account (Sign Up)',
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

    // ================= DASHBOARD HUB =================
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
              accountName: Text(_firmNameController.text.isEmpty ? 'ORLIFE Mobile Accessories' : _firmNameController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountText: Text('Mode: $_selectedBusinessMode'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, color: Colors.teal, size: 40),
              ),
              decoration: const BoxDecoration(color: Colors.teal),
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
              'Welcome, ${_firmNameController.text.isEmpty ? 'Admin' : _firmNameController.text} ($_selectedBusinessMode Mode)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
