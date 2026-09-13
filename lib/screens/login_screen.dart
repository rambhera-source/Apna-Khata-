import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart';

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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _signupPinController = TextEditingController();

  // 🛡️ Master Super Admin Credentials
  final String _masterAdminId = "Admin";
  final String _masterPin = "2029";
  final String _firmName = 'Orlife ERP';

  // 🟢 Login Logic
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

    // 1. 🛡️ Super Admin Check (ID: Admin, PIN: 2029)
    if (enteredId == _masterAdminId && enteredPin == _masterPin) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
      return;
    }

    // 2. 👤 Staff Database Check (Username & PIN matching)
    final staffUser = await DatabaseHelper.isar.userAccounts
        .filter()
        .usernameEqualTo(enteredId)
        .pinEqualTo(enteredPin)
        .findFirst();

    if (staffUser != null) {
      if (!mounted) return;
      if (staffUser.isApproved) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
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

  // 🟢 Signup Logic
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final pin = _signupPinController.text.trim();

    if (name.isEmpty || username.isEmpty || pin.length < 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya sabhi fields sahi bharein (PIN min 4 digits)!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Restrict staff from using 'Admin' as username
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
        const SnackBar(content: Text('Yeh Username/Mobile pehle se registered hai!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Save to Database with isApproved = false (Pending)
    await DatabaseHelper.isar.writeTxn(() async {
      final newUser = UserAccount()
        ..name = name
        ..username = username
        ..pin = pin
        ..role = 'Staff'
        ..isApproved = false;

      await DatabaseHelper.isar.userAccounts.put(newUser);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signup Request Submitted! Admin approval ke baad login kar payenge.'),
        backgroundColor: Colors.green,
      ),
    );

    // Switch back to login mode after successful signup
    setState(() {
      _isLoginMode = true;
      _nameController.clear();
      _usernameController.clear();
      _signupPinController.clear();
    });
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPinController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
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
                      child: Icon(_isLoginMode ? Icons.lock_outline : Icons.person_add, size: 35, color: Colors.teal),
                    ),
                    const SizedBox(height: 16),
                    
                    // Firm Title
                    Text(
                      _firmName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoginMode ? 'Secure Business Login' : 'Staff Account Request',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // ================= DYNAMIC FORM FIELDS =================
                    if (_isLoginMode) ...[
                      // LOGIN VIEW FIELDS (ID & PIN)
                      TextField(
                        controller: _loginIdController,
                        decoration: InputDecoration(
                          labelText: 'Admin ID / Username',
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
                      // SIGNUP VIEW FIELDS
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number / Username',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _signupPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Create Security PIN',
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
                          _isLoginMode = !_isLoginMode; // Mode switch karega
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'New User? Request Signup' : 'Already have an account? Login',
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
