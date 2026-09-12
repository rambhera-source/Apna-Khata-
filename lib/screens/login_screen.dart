import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'party_list_screen.dart'; // Abhi ke liye hum ise party list par bhejenge

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Username aur Password darj karein!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Database se user verify karein
    final user = await DatabaseHelper.loginUser(username, password);

    setState(() => _isLoading = false);

    if (user != null) {
      // User mil gaya, ab check karein ki uska business type kya hai
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome! Mode: ${user.businessType.toUpperCase()}')),
      );

      // Dashboards par redirect karne ka logic
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PartyListScreen()),
      );
    } else {
      // Agar pehli baar koi user nahi hai, toh testing ke liye ek default user bana sakte hain
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galat Username ya Password! Kripya dobara koshish karein.')),
      );
    }
  }

  // Testing ke liye ek default account create karne ka function
  void _createTestUser() async {
    await DatabaseHelper.addUser('admin', '12345', 'manufacturing');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test Admin User ban gaya! Username: admin, Password: 12345')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORLIFE Multi-Business Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SaaS Accounting Login',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login to Software', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            // Testing button taaki aap bina lamba database bane turant login kar sakein
            TextButton(
              onPressed: _createTestUser,
              child: const Text('Create Test User (Setup Helper)'),
            ),
          ],
        ),
      ),
    );
  }
}
