import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart'; // चूंकि यह फाइल खुद 'dashboard/' फोल्डर के अंदर है, इसलिए यह ऐसे ही रहेगा
import '../login_screen.dart'; // ✅ Updated path for login screen in root screens folder

class SuperAdminDashboardScreen extends StatefulWidget {
  final UserAccount? currentUser;
  const SuperAdminDashboardScreen({super.key, this.currentUser});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  // 📋 Dynamic list including 'Demo Plan' as default
  final List<String> _availablePlans = ['Demo Plan', 'Basic Plan', 'Standard Plan', 'Premium ERP'];

  // ➕ Function to Add a New Custom Plan
  void _showCreatePlanDialog() {
    TextEditingController planNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Subscription Plan'),
          content: TextField(
            controller: planNameController,
            decoration: const InputDecoration(
              labelText: 'Plan Name (e.g., Gold ERP, Trial Pro)',
              border: OutlineInputBorder(),
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
                final newPlan = planNameController.text.trim();
                if (newPlan.isNotEmpty && !_availablePlans.contains(newPlan)) {
                  setState(() {
                    _availablePlans.add(newPlan);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Plan "$newPlan" successfully create ho gaya hai!')),
                  );
                }
              },
              child: const Text('Add Plan'),
            ),
          ],
        );
      },
    );
  }

  // ➕ Function for Super Admin to Create a New User Directly
  void _showCreateUserDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController pinController = TextEditingController();
    String selectedPlan = _availablePlans.first;
    TextEditingController validityController = TextEditingController(text: '2027-12-31');

    bool canManageOrders = true;
    bool canManageParties = true;
    bool canManageInventory = true;
    bool canViewReports = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Company / User'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Company / Full Name *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Number / Username *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'Security PIN (Min 4 digits) *', border: OutlineInputBorder(), counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    const Text('📦 Assign Plan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    DropdownButton<String>(
                      value: selectedPlan,
                      isExpanded: true,
                      items: _availablePlans.map((plan) {
                        return DropdownMenuItem(value: plan, child: Text(plan));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPlan = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: validityController,
                      decoration: const InputDecoration(labelText: 'Plan Validity Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const Text('🔒 Module-wise Permissions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    CheckboxListTile(
                      title: const Text('Orders & Sales Access'),
                      value: canManageOrders,
                      onChanged: (val) => setDialogState(() => canManageOrders = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Parties / Customers Access'),
                      value: canManageParties,
                      onChanged: (val) => setDialogState(() => canManageParties = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Inventory / Products Access'),
                      value: canManageInventory,
                      onChanged: (val) => setDialogState(() => canManageInventory = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Reports & Analytics Access'),
                      value: canViewReports,
                      onChanged: (val) => setDialogState(() => canViewReports = val ?? true),
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
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final username = usernameController.text.trim();
                    final pin = pinController.text.trim();

                    if (name.isEmpty || username.isEmpty || pin.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kripya sabhi mandatory fields sahi bharein!'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final existingUser = await DatabaseHelper.isar.userAccounts
                        .filter()
                        .usernameEqualTo(username)
                        .findFirst();

                    if (existingUser != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yeh Username/Mobile pehle se registered hai!'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    await DatabaseHelper.isar.writeTxn(() async {
                      final newUser = UserAccount()
                        ..name = name
                        ..username = username
                        ..pin = pin
                        ..role = 'Staff'
                        ..isApproved = true
                        ..subscriptionPlan = selectedPlan
                        ..validityDate = validityController.text.trim()
                        ..canManageOrders = canManageOrders
                        ..canManageParties = canManageParties
                        ..canManageInventory = canManageInventory
                        ..canViewReports = canViewReports;

                      await DatabaseHelper.isar.userAccounts.put(newUser);
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nayi company/user safaltapurvak create kar di gayi hai!'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🟢 Request Approve Karne ka Function
  Future<void> _approveRequest(UserAccount user) async {
    await DatabaseHelper.isar.writeTxn(() async {
      user.isApproved = true;
      user.subscriptionPlan = user.subscriptionPlan.isEmpty ? 'Demo Plan' : user.subscriptionPlan;
      user.validityDate = user.validityDate.isEmpty ? '2027-12-31' : user.validityDate;
      await DatabaseHelper.isar.userAccounts.put(user);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} ka account approve aur Demo Plan set kar diya gaya hai!')),
    );
  }

  // 🔴 Request Reject / Delete Function
  Future<void> _rejectRequest(UserAccount user) async {
    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.userAccounts.delete(user.id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} ki request reject kar di gayi hai.')),
    );
  }

  // ⚙️ Edit User Subscription & Permissions Dialog
  void _showUserDetailsAndSettings(UserAccount user) {
    String selectedPlan = _availablePlans.contains(user.subscriptionPlan) 
        ? user.subscriptionPlan 
        : _availablePlans.first;
        
    TextEditingController validityController = TextEditingController(
      text: user.validityDate.isEmpty ? '2027-12-31' : user.validityDate,
    );
    
    bool canManageOrders = user.canManageOrders;
    bool canManageParties = user.canManageParties;
    bool canManageInventory = user.canManageInventory;
    bool canViewReports = user.canViewReports;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('User Details: ${user.name}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Username / Mobile: ${user.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📦 Assign Plan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreatePlanDialog();
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Plan'),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: selectedPlan,
                      isExpanded: true,
                      items: _availablePlans.map((plan) {
                        return DropdownMenuItem(value: plan, child: Text(plan));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPlan = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: validityController,
                      decoration: const InputDecoration(labelText: 'Plan Validity Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const Text('🔒 Module-wise Permissions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    CheckboxListTile(
                      title: const Text('Orders & Sales Access'),
                      value: canManageOrders,
                      onChanged: (val) => setDialogState(() => canManageOrders = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Parties / Customers Access'),
                      value: canManageParties,
                      onChanged: (val) => setDialogState(() => canManageParties = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Inventory / Products Access'),
                      value: canManageInventory,
                      onChanged: (val) => setDialogState(() => canManageInventory = val ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Reports & Analytics Access'),
                      value: canViewReports,
                      onChanged: (val) => setDialogState(() => canViewReports = val ?? true),
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
                  onPressed: () async {
                    await DatabaseHelper.isar.writeTxn(() async {
                      user.subscriptionPlan = selectedPlan;
                      user.validityDate = validityController.text.trim();
                      user.canManageOrders = canManageOrders;
                      user.canManageParties = canManageParties;
                      user.canManageInventory = canManageInventory;
                      user.canViewReports = canViewReports;
                      await DatabaseHelper.isar.userAccounts.put(user);
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User settings aur permissions update ho gayi hain!')),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
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
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Create New Company/User',
              onPressed: _showCreateUserDialog,
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Create New Plan',
              onPressed: _showCreatePlanDialog,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending Requests'),
              Tab(icon: Icon(Icons.verified_user), text: 'Active Staff & Plans'),
            ],
          ),
        ),

        // 📱 LEFT SIDEBAR (DRAWER) FOR SUPER ADMIN PANEL
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.indigo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 26,
                      child: Icon(Icons.admin_panel_settings, color: Colors.indigo, size: 30),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Super Admin Control',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.currentUser?.name ?? 'Master Administrator',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Colors.indigo),
                title: const Text('Go to Dashboard'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DashboardScreen(currentUser: widget.currentUser),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.business_center, color: Colors.green),
                title: const Text('Create New Company'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateUserDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.teal),
                title: const Text('Create Subscription Plan'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePlanDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            // ================= TAB 1: PENDING SIGNUP REQUESTS =================
            StreamBuilder<List<UserAccount>>(
              stream: DatabaseHelper.isar.userAccounts
                  .filter()
                  .isApprovedEqualTo(false)
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                                Text(req.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Pending Review', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Username / Mobile: ${req.username}', style: const TextStyle(fontSize: 13)),
                            Text('Role: ${req.role}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                                  label: const Text('Approve'),
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

            // ================= TAB 2: ACTIVE STAFF, PLANS & PERMISSIONS =================
            StreamBuilder<List<UserAccount>>(
              stream: DatabaseHelper.isar.userAccounts
                  .filter()
                  .isApprovedEqualTo(true)
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final approvedList = snapshot.data ?? [];

                if (approvedList.isEmpty) {
                  return const Center(
                    child: Text('Abhi koi active approved staff nahi hai.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: approvedList.length,
                  itemBuilder: (context, index) {
                    final staff = approvedList[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: Icon(Icons.person, color: Colors.indigo.shade800),
                        ),
                        title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Mobile: ${staff.username}\nPlan: ${staff.subscriptionPlan.isEmpty ? "Demo Plan" : staff.subscriptionPlan} | Valid: ${staff.validityDate.isEmpty ? "N/A" : staff.validityDate}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.indigo),
                          tooltip: 'Manage Plan & Permissions',
                          onPressed: () => _showUserDetailsAndSettings(staff),
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
