import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database/database_helper.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web par SQLite/Isar database run nahi hota, isliye sirf mobile/desktop par init hoga
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
      debugShowCheckedModeBanner: false,
      
      // 📊 BUSY ACCOUNTING SOFTWARE STYLE GLOBAL THEME
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B365D), // Professional Corporate Navy/Blue (Busy Style)
          primary: const Color(0xFF1B365D),
          secondary: const Color(0xFFD97706), // Amber/Orange highlight
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F4F8), // Soft light-grey accounting background
        
        // 1. App Bar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B365D),
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),

        // 2. Input / Text Fields Theme (Compact & Sharp like Busy/Tally)
        inputDecorationTheme: InputDecorationTheme(
          isDense: true, 
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4), // Sharp professional borders
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF1B365D), width: 1.5),
          ),
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),

        // 3. Elevated Buttons Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B365D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),

        // 4. Card Theme (Fixed from CardThemeData to CardTheme)
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        ),
      ),
      
      home: const LoginScreen(),
    );
  }
}
