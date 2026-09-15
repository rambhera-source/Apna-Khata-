import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../database/database_helper.dart';
import '../../models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessNameController = TextEditingController();
  final _gstinController = TextEditingController();
  bool _isGstEnabled = false;

  List<String> _routes = [];
  List<String> _salesmen = [];
  
  // Advanced Extra Charges List (Map structure)
  List<Map<String, dynamic>> _extraCharges = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    if (settings != null) {
      setState(() {
        _businessNameController.text = settings.businessName;
        _gstinController.text = settings.gstin ?? '';
        _isGstEnabled = settings.isGstEnabled;
        _routes = List.from(settings.routes);
        _salesmen = List.from(settings.salesmen);
        
        // Safely decode JSON strings back to Maps
        _extraCharges = settings.extraCharges.map((itemStr) {
          try {
            return Map<String, dynamic>.from(jsonDecode(itemStr));
          } catch (_) {
            return {'name': itemStr, 'type': 'Add', 'mode': 'Fixed', 'value': 0.0};
          }
        }).toList();

        if (_extraCharges.isEmpty) {
          _extraCharges = [
            {'name': 'Packing Charge', 'type': 'Add', 'mode': 'Fixed', 'value': 0.0},
            {'name': 'Special Discount', 'type': 'Less', 'mode': 'Fixed', 'value': 0.0},
          ];
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final businessName = _businessNameController.text.trim();
    final gstin = _gstinController.text.trim();

    if (businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Business Name darj karein!')),
      );
      return;
    }

    // Convert Map list to JSON String list for Isar DB storage
    List<String> encodedCharges = _extraCharges.map((map) => jsonEncode(map)).toList();

    final existing = await DatabaseHelper.isar.companySettings.where().findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existing != null) {
        existing.businessName = businessName;
        existing.gstin = gstin;
        existing.isGstEnabled = _isGstEnabled;
        existing.routes = _routes;
        existing.salesmen = _salesmen;
        existing.extraCharges = encodedCharges;
        await DatabaseHelper.isar.companySettings.put(existing);
      } else {
        final newSettings = CompanySettings()
          ..businessName = businessName
          ..gstin = gstin
          ..isGstEnabled = _isGstEnabled
          ..routes = _routes
          ..salesmen = _salesmen
          ..extraCharges = encodedCharges;
        await DatabaseHelper.isar.companySettings.put(newSettings);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Safaltapurvak Save Ho Gayi!'), backgroundColor: Colors.green),
    );
  }

  void _showRouteDialog({String? routeToEdit, int? index}) {
    final controller = TextEditingController(text: routeToEdit ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(routeToEdit == null ? 'Add New Route' : 'Edit Route'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Route / Area Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () {
              String name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (routeToEdit == null) {
                    _routes.add(name);
                  } else {
                    _routes[index!] = name;
                  }
                });
                _saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSalesmanDialog({String? salesmanToEdit, int? index}) {
    final controller = TextEditingController(text: salesmanToEdit ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(salesmanToEdit == null ? 'Add New Salesman' : 'Edit Salesman'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Salesman / User Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () {
              String name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (salesmanToEdit == null) {
                    _salesmen.add(name);
                  } else {
                    _salesmen[index!] = name;
                  }
                });
                _saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExtraChargeDialog({Map<String, dynamic>? chargeToEdit, int? index}) {
    final nameController = TextEditingController(text: chargeToEdit != null ? chargeToEdit['name'] : '');
    final valueController = TextEditingController(text: chargeToEdit != null ? chargeToEdit['value'].toString() : '0');
    
    String selectedType = chargeToEdit != null ? chargeToEdit['type'] : 'Add'; 
    String selectedMode = chargeToEdit != null ? chargeToEdit['mode'] : 'Fixed'; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(chargeToEdit == null ? 'Add Extra Charge / Discount' : 'Edit Charge'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Charge / Discount Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'Add', child: Text('Add (+) [Bill mein Jhudega]', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'Less', child: Text('Less (-) [Bill se Ghatega]', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) => setDialogState(() => selectedType = val!),
                    decoration: const InputDecoration(labelText: 'Calculation Type', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMode,
                    items: const [
                      DropdownMenuItem(value: 'Fixed', child: Text('Fixed Amount (₹)')),
                      DropdownMenuItem(value: 'Percentage', child: Text('Percentage (%)')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedMode = val!),
                    decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: selectedMode == 'Fixed' ? 'Default Amount (₹)' : 'Default Percentage (%)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  String name = nameController.text.trim();
                  double val = double.tryParse(valueController.text) ?? 0.0;
                  if (name.isNotEmpty) {
                    setState(() {
                      final newItem = {
                        'name': name,
                        'type': selectedType,
                        'mode': selectedMode,
                        'value': val,
                      };
                      if (chargeToEdit == null) {
                        _extraCharges.add(newItem);
                      } else {
                        _extraCharges[index!] = newItem;
                      }
                    });
                    _saveSettings();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company, GST & Master Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                subtitle: const Text('ON rakhne par tax calculate hoga, OFF par simple bill banega'),
                value: _isGstEnabled,
                onChanged: (bool value) => setState(() => _isGstEnabled = value),
              ),
              const Divider(height: 32, thickness: 1),

              // Routes Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Routes / Areas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Route'),
                    onPressed: () => _showRouteDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _routes.isEmpty
                  ? const Text('Koi route add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            title: Text(_routes[index]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  onPressed: () => _showRouteDialog(routeToEdit: _routes[index], index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _routes.removeAt(index));
                                    _saveSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              const Divider(height: 32, thickness: 1),

              // Salesmen Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Salesmen / Users', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Salesman'),
                    onPressed: () => _showSalesmanDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _salesmen.isEmpty
                  ? const Text('Koi salesman add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _salesmen.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            title: Text(_salesmen[index]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  onPressed: () => _showSalesmanDialog(salesmanToEdit: _salesmen[index], index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _salesmen.removeAt(index));
                                    _saveSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              const Divider(height: 32, thickness: 1),

              // Extra Charges & Discounts Master Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Extra Charges & Discounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Charge'),
                    onPressed: () => _showExtraChargeDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _extraCharges.isEmpty
                  ? const Text('Koi extra charge add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _extraCharges.length,
                      itemBuilder: (context, index) {
                        final charge = _extraCharges[index];
                        bool isAdd = charge['type'] == 'Add';
                        return Card(
                          child: ListTile(
                            title: Text(charge['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Type: ${charge['type']} | Mode: ${charge['mode']} | Value: ${charge['value']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(isAdd ? '+ Add' : '- Less', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  backgroundColor: isAdd ? Colors.green : Colors.red,
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
                                  onPressed: () => _showExtraChargeDialog(chargeToEdit: charge, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _extraCharges.removeAt(index));
                                    _saveSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: _saveSettings,
                  child: const Text('Save All Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
