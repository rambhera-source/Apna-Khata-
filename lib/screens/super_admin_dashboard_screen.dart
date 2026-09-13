import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/user_request_model.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  
  // 🟢 Request Approve Karne ka Function
  Future<void> _approveRequest(UserRequest request) async {
    await DatabaseHelper.isar.writeTxn(() async {
      request.status = 'Approved';
      await DatabaseHelper.isar.userRequests.put(request);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${request.firmName} ka account approve kar diya gaya hai!')),
    );
    setState(() {});
  }

  // 🔴 Request Reject Karne ka Function
  Future<void> _rejectRequest(UserRequest request) async {
    await DatabaseHelper.isar.writeTxn(() async {
      request.status = 'Rejected';
      await DatabaseHelper.isar.userRequests.put(request);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${request.firmName} ki request reject kar di gayi hai.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Super Admin Master Control'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending Approvals'),
              Tab(icon: Icon(Icons.business), text: 'Active Companies'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= TAB 1: PENDING SIGNUP REQUESTS =================
            StreamBuilder<List<UserRequest>>(
              stream: DatabaseHelper.isar.userRequests
                  .filter()
                  .statusEqualTo('Pending')
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return const Center(
                    child: Text('Koi nayi signup request pending nahi hai.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(req.firmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Pending Review', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Owner: ${req.ownerName} | Phone: ${req.phone}', style: const TextStyle(fontSize: 13)),
                            Text('Email: ${req.email} | Mode: ${req.businessMode}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('Location: ${req.city}, ${req.state} (${req.pincode})', style: const TextStyle(fontSize: 12)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Reject'),
                                  onPressed: () => _rejectRequest(req),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve & Grant Access'),
                                  onPressed: () => _approveRequest(req),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ================= TAB 2: ACTIVE & APPROVED COMPANIES =================
            StreamBuilder<List<UserRequest>>(
              stream: DatabaseHelper.isar.userRequests
                  .filter()
                  .statusEqualTo('Approved')
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                final approvedList = snapshot.data ?? [];

                if (approvedList.isEmpty) {
                  return const Center(
                    child: Text('Abhi koi active approved company nahi hai.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: approvedList.length,
                  itemBuilder: (context, index) {
                    final comp = approvedList[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(Icons.store, color: Colors.green.shade800),
                        ),
                        title: Text(comp.firmName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Owner: ${comp.ownerName} | Mode: ${comp.businessMode}\nEmail: ${comp.email}'),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
