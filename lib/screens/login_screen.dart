import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // ✅ Dashboard ka rasta yahan import kar diya gaya hai

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final String _correctPin = "1234"; // Aap apna default PIN ya password yahan change kar sakte hain
  final String _firmName = 'ORLIFE Mobile Accessories';

  void _handleLogin() {
    if (_pinController.text.trim() == _correctPin) {
      // ✅ PIN sahi hone par yeh code user ko seedha Dashboard screen par le jayega
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      // ❌ Galat PIN par error message dikhayega
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
