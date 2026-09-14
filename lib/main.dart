import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database/database_helper.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web par SQLite database run nahi hota, isliye sirf mobile par init hoga
  if (!kIsWeb) {
    await DatabaseHelper.initDB();
  }
  
  runApp(const AccountingApp());
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORLIFE Accounting SaaS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
