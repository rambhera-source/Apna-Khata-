import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart'; // ✅ Signup screen ka import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final String _masterPin = "1234"; // Master Super Admin PIN
  final String _firmName = 'Orlife ERP';

  Future<void> _handleLogin() async {
    final enteredPin = _pinController.text.trim();

    if (enteredPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya PIN darj karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 1. Check if Master Admin PIN is entered
    if (enteredPin == _masterPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
      return;
    }

    // 2. Check if entered PIN belongs to an Approved Staff User in Database
    final staffUser = await DatabaseHelper.isar.userAccounts
        .filter()
        .pinEqualTo(enteredPin)
        .findFirst();

    if (staffUser != null) {
      if (staffUser.isApproved) {
        // ✅ Approved Staff: Allow login to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // ⏳ Pending Approval: Block login and show warning
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aapka account abhi Admin approval ke liye pending hai!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // ❌ Invalid PIN
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Galat PIN! Kripya sahi PIN darj karein.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                    child: const Icon(Icons.lock_outline, size: 40, color: Colors.teal),
                  ),
                  const SizedBox(height: 16),
                  
                  // Firm Title
                  Text(
                    _firmName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Secure Business Login',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // PIN Input Field
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true, // PIN hide karne ke liye
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Enter Security PIN',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.vpn_key),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 20),

                  // Login Button
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
                  const SizedBox(height: 12),

                  // Signup Navigation Button for New Staff
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'New User? Request Signup',
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
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
}
