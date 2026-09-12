import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessNameController = TextEditingController();
  final _gstinController = TextEditingController();
  bool _isGstEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Database se purani settings load karna
  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    if (settings != null) {
      setState(() {
        _businessNameController.text = settings.businessName;
        _gstinController.text = settings.gstin ?? '';
        _isGstEnabled = settings.isGstEnabled;
      });
    }
  }

  // Settings save ya update karna
  Future<void> _saveSettings() async {
    final businessName = _businessNameController.text.trim();
    final gstin = _gstinController.text.trim();

    if (businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Business Name darj karein!')),
      );
      return;
    }

    final existing = await DatabaseHelper.isar.companySettings.where().findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existing != null) {
        existing.businessName = businessName;
        existing.gstin = gstin;
        existing.isGstEnabled = _isGstEnabled;
        await DatabaseHelper.isar.companySettings.put(existing);
      } else {
        final newSettings = CompanySettings()
          ..businessName = businessName
          ..gstin = gstin
          ..isGstEnabled = _isGstEnabled;
        await DatabaseHelper.isar.companySettings.put(newSettings);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Safaltapurvak Save Ho Gayi!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company & GST Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _businessNameController,
              decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gstinController,
              decoration: const InputDecoration(labelText: 'GSTIN Number (Optional if GST Off)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable GST Billing Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('ON rakhene par tax calculate hoga, OFF par simple bill banega'),
              value: _isGstEnabled,
              onChanged: (bool value) {
                setState(() {
                  _isGstEnabled = value;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: _saveSettings,
                child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
