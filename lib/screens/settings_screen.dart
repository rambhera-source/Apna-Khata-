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

  // 🔥 Routes aur Salesmen ki list local state ke liye
  List<String> _routes = [];
  List<String> _salesmen = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Database se purani settings aur lists load karna
  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    if (settings != null) {
      setState(() {
        _businessNameController.text = settings.businessName;
        _gstinController.text = settings.gstin ?? '';
        _isGstEnabled = settings.isGstEnabled;
        _routes = List.from(settings.routes);
        _salesmen = List.from(settings.salesmen);
      });
    }
  }

  // Settings save ya update karna (Routes aur Salesmen ke saath)
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
        existing.routes = _routes;
        existing.salesmen = _salesmen;
        await DatabaseHelper.isar.companySettings.put(existing);
      } else {
        final newSettings = CompanySettings()
          ..businessName = businessName
          ..gstin = gstin
          ..isGstEnabled = _isGstEnabled
          ..routes = _routes
          ..salesmen = _salesmen;
        await DatabaseHelper.isar.companySettings.put(newSettings);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings Safaltapurvak Save Ho Gayi!'), backgroundColor: Colors.green),
    );
  }

  // 🚚 Route Add ya Edit karne ka Dialog
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
                _saveSettings(); // Auto save to DB
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // 👨‍💼 Salesman Add ya Edit karne ka Dialog
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
                _saveSettings(); // Auto save to DB
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
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
                onChanged: (bool value) {
                  setState(() {
                    _isGstEnabled = value;
                  });
                },
              ),
              const Divider(height: 32, thickness: 1),

              // 🚚 Routes Management Section
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
                                    setState(() {
                                      _routes.removeAt(index);
                                    });
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

              // 👨‍💼 Salesmen Management Section
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
                                    setState(() {
                                      _salesmen.removeAt(index);
                                    });
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
