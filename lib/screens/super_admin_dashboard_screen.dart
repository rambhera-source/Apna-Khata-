import 'package:flutter/material.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  // 🏢 Registered Client Companies & Their Subscription Plans
  final List<Map<String, dynamic>> _clientCompanies = [
    {
      'firmName': 'ORLIFE Mobile Accessories',
      'owner': 'Admin',
      'mode': 'Manufacturing',
      'plan': 'Annual Enterprise',
      'status': 'Active',
      'expiry': '31 Dec 2026',
    },
    {
      'firmName': 'Chamunda Mobile (Jalore)',
      'owner': 'Ramesh Ji',
      'mode': 'Wholesale',
      'plan': 'Monthly Standard',
      'status': 'Active',
      'expiry': '15 Oct 2026',
    },
    {
      'firmName': 'Sharma Electronics',
      'owner': 'Sunil Sharma',
      'mode': 'Wholesale',
      'plan': 'Trial Plan',
      'status': 'Expired',
      'expiry': '01 Aug 2026',
    },
  ];

  // ➕ Nayi Company License Register Karne ka Dialog
  void _showAddCompanyDialog() {
    final nameController = TextEditingController();
    final ownerController = TextEditingController();
    String mode = 'Wholesale';
    String plan = 'Monthly Standard';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Company License'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Firm Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mode,
                items: ['Wholesale', 'Manufacturing'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => mode = val!,
                decoration: const InputDecoration(labelText: 'Business Mode', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: plan,
                items: ['Trial Plan', 'Monthly Standard', 'Annual Enterprise'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => plan = val!,
                decoration: const InputDecoration(labelText: 'Subscription Plan', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _clientCompanies.add({
                    'firmName': nameController.text.trim(),
                    'owner': ownerController.text.trim().isEmpty ? 'Owner' : ownerController.text.trim(),
                    'mode': mode,
                    'plan': plan,
                    'status': 'Active',
                    'expiry': '31 Dec 2027',
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Company license successfully register ho gaya!')),
                );
              }
            },
            child: const Text('Register License'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCompanies = _clientCompanies.length;
    int activeCount = _clientCompanies.where((c) => c['status'] == 'Active').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Master Control'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📊 Summary Metric Cards
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Companies', '$totalCompanies', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Active Licenses', '$activeCount', Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Registered Client Companies & Running Plans:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),

            // 📋 Client Companies List
            Expanded(
              child: ListView.builder(
                itemCount: _clientCompanies.length,
                itemBuilder: (context, index) {
                  final company = _clientCompanies[index];
                  bool isActive = company['status'] == 'Active';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                        child: Icon(Icons.business, color: isActive ? Colors.green.shade800 : Colors.red.shade800),
                      ),
                      title: Text(company['firmName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Owner: ${company['owner']} | Mode: ${company['mode']}\nPlan: ${company['plan']} (Exp: ${company['expiry']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isActive ? Colors.green : Colors.red),
                        ),
                        child: Text(
                          company['status'],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade800 : Colors.red.shade800),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // ➕ Floating Button to Add New Company License
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Company License'),
        onPressed: _showAddCompanyDialog,
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
