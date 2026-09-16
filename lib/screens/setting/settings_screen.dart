import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../database/database_helper.dart';
import '../../models/settings_model.dart';
import 'category_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isGstEnabled = false;

  List<String> _routes = [];
  List<double> _taxSlabs = [];
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
        _isGstEnabled = settings.isGstEnabled;
        _routes = List.from(settings.routes);
            
        _taxSlabs = settings.taxSlabs.isNotEmpty
            ? List<double>.from(settings.taxSlabs)
            : [0.0, 5.0, 12.0, 18.0, 28.0];
        
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
    } else {
      setState(() {
        _taxSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];
      });
    }
  }

  Future<void> _saveSettings() async {
    List<String> encodedCharges = _extraCharges.map((map) => jsonEncode(map)).toList();

    final existing = await DatabaseHelper.isar.companySettings.where().findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existing != null) {
        existing.isGstEnabled = _isGstEnabled;
        existing.routes = _routes;
        // salesmen को यहाँ से हटा दिया गया है
        existing.taxSlabs = _taxSlabs;                   
        existing.extraCharges = encodedCharges;
        await DatabaseHelper.isar.companySettings.put(existing);
      } else {
        final newSettings = CompanySettings()
          ..businessName = 'ORLIFE'
          ..isGstEnabled = _isGstEnabled
          ..routes = _routes
          ..taxSlabs = _taxSlabs
          ..extraCharges = encodedCharges;
        await DatabaseHelper.isar.companySettings.put(newSettings);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Safaltapurvak Save Ho Gayi!'), backgroundColor: Colors.green),
    );
  }

  void _showTaxDialog({double? taxToEdit, int? index}) {
    final controller = TextEditingController(text: taxToEdit != null ? taxToEdit.toString() : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(taxToEdit == null ? 'Add Tax Slab (%)' : 'Edit Tax Slab'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tax Percentage e.g. 18', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              double? val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                setState(() {
                  if (taxToEdit == null) {
                    if (!_taxSlabs.contains(val)) _taxSlabs.add(val);
                  } else {
                    _taxSlabs[index!] = val;
                  }
                  _taxSlabs.sort();
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
                      DropdownMenuItem(value: 'Add', child: Text('Add (+) [Bill mein Jhudega]', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                      DropdownMenuItem(value: 'Less', child: Text('Less (-) [Bill se Ghatega]', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
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
        title: const Text('GST & Master Setup'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: SwitchListTile(
                    title: const Text('Enable GST Billing Mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    subtitle: const Text('ON rakhne par tax calculate hoga', style: TextStyle(fontSize: 11)),
                    value: _isGstEnabled,
                    activeColor: Colors.teal,
                    onChanged: (bool value) {
                      setState(() => _isGstEnabled = value);
                      _saveSettings();
                    },
                  ),
                ),
              ),
              const Divider(height: 32, thickness: 1),

              Card(
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.category, color: Colors.teal),
                  title: const Text('Manage Product Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Main categories aur sub-categories manage karein', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                    );
                  },
                ),
              ),

              const Divider(height: 32, thickness: 1),

              // Tax Slabs Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Tax Slabs (GST %)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(80, 32)),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Tax Slab', style: TextStyle(fontSize: 11)),
                    onPressed: () => _showTaxDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(_taxSlabs.length, (index) {
                  return Chip(
                    label: Text('${_taxSlabs[index]}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.indigo.shade100,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() => _taxSlabs.removeAt(index));
                      _saveSettings();
                    },
                  );
                }),
              ),

              const Divider(height: 32, thickness: 1),

              // Routes Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Routes / Areas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(80, 32)),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Route Add Karein', style: TextStyle(fontSize: 11)),
                    onPressed: () => _showRouteDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _routes.isEmpty
                  ? const Text('Koi route add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            title: Text(_routes[index], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                  onPressed: () => _showRouteDialog(routeToEdit: _routes[index], index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
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

              // Extra Charges Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extra Charges & Discounts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(80, 32)),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Charge', style: TextStyle(fontSize: 11)),
                    onPressed: () => _showExtraChargeDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _extraCharges.isEmpty
                  ? const Text('Koi extra charge add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _extraCharges.length,
                      itemBuilder: (context, index) {
                        final charge = _extraCharges[index];
                        bool isAdd = charge['type'] == 'Add';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            title: Text(charge['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Type: ${charge['type']} | Mode: ${charge['mode']} | Value: ${charge['value']}', style: const TextStyle(fontSize: 10)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(isAdd ? '+ Add' : '- Less', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  backgroundColor: isAdd ? Colors.green : Colors.red,
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.teal),
                                  onPressed: () => _showExtraChargeDialog(chargeToEdit: charge, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                  onPressed: () => setState(() => _extraCharges.removeAt(index)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
