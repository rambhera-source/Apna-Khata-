import 'package:flutter/material.dart';
import 'package:accounting_app/models/user_model.dart';

class DashboardScreen extends StatefulWidget {
  final UserAccount currentUser;

  const DashboardScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.currentUser.name}'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 60, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              'Dashboard - ${widget.currentUser.role}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Business Type: ${widget.currentUser.businessType}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
