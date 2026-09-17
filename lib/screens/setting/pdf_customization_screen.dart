import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/pdf_settings_model.dart';

class PdfCustomizationScreen extends StatefulWidget {
  const PdfCustomizationScreen({super.key});

  @override
  State<PdfCustomizationScreen> createState() => _PdfCustomizationScreenState();
}

class _PdfCustomizationScreenState extends State<PdfCustomizationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subHeadingController = TextEditingController();
  
  bool _showSku = true;
  bool _showGstin = true;
  String _selectedThemeColor = 'Teal';
  String _selectedPageSize = 'A4';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.isar.pdfSettingsModels.get(1);
    if (settings != null) {
      _titleController.text = settings.companyCustomTitle;
      _subHeadingController.text = settings.subHeading;
      _showSku = settings.showSku;
      _showGstin = settings.showGstin;
      _selectedThemeColor = settings.themeColorName;
      _selectedPageSize = settings.pageSize;
    } else {
      _titleController.text = 'ORLIFE Mobile Accessories';
      _subHeadingController.text = 'Wholesale & Retail Mobile Parts & Accessories';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final newSettings = PdfSettingsModel()
      ..id = 1
      ..companyCustomTitle = _titleController.text.trim()
      ..subHeading = _subHeadingController.text.trim()
      ..showSku = _showSku
      ..showGstin = _showGstin
      ..themeColorName = _selectedThemeColor
      ..pageSize = _selectedPageSize;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.pdfSettingsModels.put(newSettings);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF Settings saved successfully!'), backgroundColor: Colors.teal),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Invoice Customization'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const Text('Customize Header & Titles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Company Title on PDF', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subHeadingController,
                    decoration: const InputDecoration(labelText: 'Sub-heading / Tagline', border: OutlineInputBorder(), isDense: true),
                  ),
                  const Divider(height: 30),
                  
                  const Text('Column & Field Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  SwitchListTile(
                    title: const Text('Show Product SKU in Table', style: TextStyle(fontSize: 13)),
                    value: _showSku,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => _showSku = val),
                  ),
                  SwitchListTile(
                    title: const Text('Show Company GSTIN', style: TextStyle(fontSize: 13)),
                    value: _showGstin,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => _showGstin = val),
                  ),
                  const Divider(height: 30),

                  const Text('PDF Page Format / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPageSize,
                    items: ['A4', 'Letter', 'A5', 'Thermal 3-Inch'].map((size) => DropdownMenuItem(value: size, child: Text(size))).toList(),
                    onChanged: (val) => setState(() => _selectedPageSize = val!),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),

                  const Text('PDF Theme Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedThemeColor,
                    items: ['Teal', 'Amber', 'Blue', 'Indigo'].map((color) => DropdownMenuItem(value: color, child: Text(color))).toList(),
                    onChanged: (val) => setState(() => _selectedThemeColor = val!),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saveSettings,
                    child: const Text('Save PDF Customization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
