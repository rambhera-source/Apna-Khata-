import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/user_model.dart';
import 'package:accounting_app/screens/dashboard/dashboard_screen.dart';                 // ✅ Updated package import for dashboard
import 'package:accounting_app/screens/dashboard/super_admin_dashboard_screen.dart'; // ✅ Updated package import for super admin dashboard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginMode = true; // True = Login View, False = Signup View

  // Controllers for Login (ID and PIN)
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPinController = TextEditingController();
  
  // Controllers for Signup
  final TextEditingController _nameController = TextEditingController(); // Full Name / Owner Name
  final TextEditingController _firmNameController = TextEditingController(); // Firm Name
  final TextEditingController _usernameController = TextEditingController(); // Mobile Number
  final TextEditingController _gstController = TextEditingController(); // GST Number
  final TextEditingController _pincodeController = TextEditingController(); // Pincode
  final TextEditingController _cityController = TextEditingController(); // City (Auto-filled)
  final TextEditingController _stateController = TextEditingController(); // State (Auto-filled)
  final TextEditingController _addressController = TextEditingController(); // Detailed Address
  final TextEditingController _signupPinController = TextEditingController(); // Security PIN

  // Business Type Selection for Signup ('Manufacturing' or 'Wholesaler / Retailer')
  String _selectedBusinessType = 'Wholesaler / Retailer';

  // 🛡️ Master Super Admin Credentials
  final String _masterAdminId = "Admin";
  final String _masterPin = "2029";

  // 🔥 Manufacturing Company Credentials (Factory & BOM Unit)
  final String _factoryAdminId = "admin";
  final String _factoryPin = "4995";

  final String _firmBrandName = 'Orlife ERP';

  // 🌍 Function to Auto-fetch City & State from Pincode
  Future<void> _lookupPincode(String pincode) async {
    if (pincode.length != 6) return;
    try {
      final response = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          setState(() {
            _cityController.text = postOffice['District'] ?? '';
            _stateController.text = postOffice['State'] ?? '';
          });
        }
      }
    } catch (e) {
      // Handle network error silently or show a small hint
    }
  }

  // 🟢 Login Logic with Role-Based Redirection
  Future<void> _handleLogin() async {
    final enteredId = _loginIdController.text.trim();
    final enteredPin = _loginPinController.text.trim();

    if (enteredId.isEmpty || enteredPin.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Admin ID aur PIN dono darj karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 1. 🛡️ Super Admin Check (ID: Admin, PIN: 2029) - Case-insensitive match for Admin
    if (enteredId.toLowerCase() == _masterAdminId.toLowerCase() && enteredPin == _masterPin) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
      );
      return;
    }

    // 2. 🔥 Manufacturing Company Check (ID: admin, PIN: 4995) [Factory & BOM Unit]
    if (enteredId.toLowerCase() == _factoryAdminId.toLowerCase() && enteredPin == _factoryPin) {
      if (!mounted) return;
      final factoryUser = UserAccount()
        ..name = 'Factory Admin'
        ..username = 'admin'
        ..role = 'Admin'
        ..businessType = 'Manufacturing'
        ..isApproved = true;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(currentUser: factoryUser)),
      );
      return;
    }

    // 3. 👤 Staff / User Database Check
    final staffUser = await DatabaseHelper.isar.userAccounts
        .filter()
        .usernameEqualTo(enteredId)
        .pinEqualTo(enteredPin)
        .findFirst();

    if (staffUser != null) {
      if (!mounted) return;
      if (staffUser.isApproved) {
        if (staffUser.role == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
          );
        } else {
          // ✅ Passing currentUser to Dashboard so businessType & permissions apply correctly
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(currentUser: staffUser)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aapka account abhi Admin approval ke liye pending hai!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Galat Admin ID ya PIN! Kripya sahi jankari bharein.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🟢 Signup Logic with All Professional Fields
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final firmName = _firmNameController.text.trim();
    final username = _usernameController.text.trim(); // Mobile Number
    final gst = _gstController.text.trim();
    final pincode = _pincodeController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final address = _addressController.text.trim();
    final pin = _signupPinController.text.trim();

    if (name.isEmpty || firmName.isEmpty || username.isEmpty || pincode.isEmpty || pin.length < 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya sabhi mandatory fields (Name, Firm, Mobile, Pincode, PIN) bharein!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (username.toLowerCase() == 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeh username allowed nahi hai!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Check if user already exists
    final existingUser = await DatabaseHelper.isar.userAccounts
        .filter()
        .usernameEqualTo(username)
        .findFirst();

    if (existingUser != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeh Mobile Number pehle se registered hai!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Save to Database with isApproved = false (Pending)
    await DatabaseHelper.isar.writeTxn(() async {
      final newUser = UserAccount()
        ..name = name
        ..username = username // Mobile number
        ..pin = pin
        ..role = 'Staff'
        ..isApproved = false
        ..businessType = _selectedBusinessType; // Manufacturing or Wholesaler / Retailer

      await DatabaseHelper.isar.userAccounts.put(newUser);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signup Request Submitted! Admin approval ke baad login kar payenge.'),
        backgroundColor: Colors.green,
      ),
    );

    // Switch back to login mode after successful signup & clear controllers
    setState(() {
      _isLoginMode = true;
      _nameController.clear();
      _firmNameController.clear();
      _usernameController.clear();
      _gstController.clear();
      _pincodeController.clear();
      _cityController.clear();
      _stateController.clear();
      _addressController.clear();
      _signupPinController.clear();
    });
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPinController.dispose();
    _nameController.dispose();
    _firmNameController.dispose();
    _usernameController.dispose();
    _gstController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _signupPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / Icon
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(_isLoginMode ? Icons.lock_outline : Icons.business, size: 35, color: Colors.teal),
                    ),
                    const SizedBox(height: 16),
                    
                    // Firm Title
                    Text(
                      _firmBrandName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoginMode ? 'Secure Business Login' : 'New ERP Business Signup',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // ================= DYNAMIC FORM FIELDS =================
                    if (_isLoginMode) ...[
                      // LOGIN VIEW FIELDS (ID & PIN)
                      TextField(
                        controller: _loginIdController,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number / Admin ID',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Enter Security PIN / Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.vpn_key),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _handleLogin,
                          child: const Text('Login to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      // ================= SIGNUP VIEW FIELDS =================
                      const Text('Select Business Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBusinessType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Wholesaler / Retailer', child: Text('Wholesaler / Retailer (Trading & Khata)')),
                          DropdownMenuItem(value: 'Manufacturing', child: Text('Manufacturing (Factory & BOM)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBusinessType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _firmNameController,
                        decoration: InputDecoration(
                          labelText: 'Firm / Company Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Owner / Contact Person Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number (Login ID) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _gstController,
                        decoration: InputDecoration(
                          labelText: 'GST Number (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.receipt_long),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'Pincode *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.pin_drop),
                                counterText: '',
                              ),
                              onChanged: (val) {
                                if (val.length == 6) {
                                  _lookupPincode(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _stateController,
                        decoration: InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.map),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Complete Address / Location',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _signupPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Create Security PIN (Min 4 digits) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _handleSignup,
                          child: const Text('Submit Request to Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Toggle Button between Login and Signup
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'New Business? Register Here' : 'Already registered? Login here',
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
