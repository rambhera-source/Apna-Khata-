import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/account.dart'; // ✅ Correct Account Model
import '../models/settings_model.dart'; // ✅ For CompanySettings (Routes & Salesmen)

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  // 🔥 Route & Salesman Dropdown Variables & Lists
  List<String> _availableRoutes = [];
  List<String> _availableSalesmen = [];
  String? _selectedRoute;
  String? _selectedSalesman;

  final _gstinController = TextEditingController();
  final _balanceController = TextEditingController();
  
  final _creditLimitAmountController = TextEditingController();
  final _creditDaysController = TextEditingController();
  bool _isCreditControlEnabled = false;

  // 🔥 Portal Login Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPortalAccessEnabled = false;

  String _groupCategory = 'Sundry Debtor';
  final List<String> _groupCategories = [
    'Sundry Debtor',
    'Sundry Creditor',
    'Bank Account',
    'Cash-in-Hand',
    'Direct Expense',
    'Indirect Expense',
    'Direct Income',
    'Indirect Income',
  ];

  final List<String> _categoryList = List.generate(26, (index) => String.fromCharCode(65 + index));
  String _priceCategory = 'A'; 
  String _balanceType = 'Dr'; 

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _houseNoFocus = FocusNode();
  final FocusNode _streetFocus = FocusNode();
  final FocusNode _landmarkFocus = FocusNode();
  final FocusNode _pincodeFocus = FocusNode();
  final FocusNode _gstinFocus = FocusNode();
  final FocusNode _balanceFocus = FocusNode();
  final FocusNode _creditLimitFocus = FocusNode();
  final FocusNode _creditDaysFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadMasterData(); // 👈 Settings se Routes aur Salesmen load karna
  }

  // 📂 CompanySettings se Routes aur Salesmen ki list fetch karna
  Future<void> _loadMasterData() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    if (settings != null) {
      setState(() {
        _availableRoutes = List.from(settings.routes);
        _availableSalesmen = List.from(settings.salesmen);
      });
    }
  }

  // ⚡ Quick Add Dialog (Naya Route ya Salesman turant add karne ke liye)
  void _showQuickAddDialog(String titleType, Function(String) onAdded) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New $titleType'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: '$titleType Name', border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              String name = controller.text.trim();
              if (name.isNotEmpty) {
                final settings = await DatabaseHelper.isar.companySettings.where().findFirst() ?? CompanySettings();
                await DatabaseHelper.isar.writeTxn(() async {
                  if (titleType == 'Route') {
                    if (!settings.routes.contains(name)) settings.routes.add(name);
                  } else {
                    if (!settings.salesmen.contains(name)) settings.salesmen.add(name);
                  }
                  await DatabaseHelper.isar.companySettings.put(settings);
                });

                onAdded(name);
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _gstinController.dispose();
    _balanceController.dispose();
    _creditLimitAmountController.dispose();
    _creditDaysController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _houseNoFocus.dispose();
    _streetFocus.dispose();
    _landmarkFocus.dispose();
    _pincodeFocus.dispose();
    _gstinFocus.dispose();
    _balanceFocus.dispose();
    _creditLimitFocus.dispose();
    _creditDaysFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // 🌍 Pincode Auto-Fill Function
  Future<void> _lookupPincode(String pincode) async {
    if (pincode.length == 6) {
      try {
        final url = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data[0]['Status'] == 'Success') {
            final postOffice = data[0]['PostOffice'][0];
            setState(() {
              _cityController.text = postOffice['District'] ?? '';
              _stateController.text = postOffice['State'] ?? '';
            });
          }
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _saveAccount() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final address = '${_houseNoController.text.trim()}, ${_streetController.text.trim()}, Landmark: ${_landmarkController.text.trim()}, City: ${_cityController.text.trim()}, State: ${_stateController.text.trim()} - Pincode: ${_pincodeController.text.trim()}';
    
    final gstin = _gstinController.text.trim();
    double openingBal = double.tryParse(_balanceController.text) ?? 0.0;
    
    double creditLimitAmt = double.tryParse(_creditLimitAmountController.text) ?? 0.0;
    int creditDays = int.tryParse(_creditDaysController.text) ?? 0;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Account / Party ka Naam likhein!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 1️⃣ Check Existing Name
    final existingAccount = await DatabaseHelper.isar.accounts
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .findFirst();

    if (existingAccount != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: "$name" naam ka account pehle se bana hua hai!'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2️⃣ 🔥 Check Existing Mobile Number (1 Mobile = 1 Account Check)
    if (phone.isNotEmpty) {
      final existingByPhone = await DatabaseHelper.isar.accounts
          .filter()
          .phoneEqualTo(phone)
          .findFirst();

      if (existingByPhone != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Mobile number "$phone" pehle se "${existingByPhone.name}" ke paas registered hai!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final newAccount = Account()
      ..name = name
      ..groupCategory = _groupCategory
      ..phone = phone.isEmpty ? null : phone
      ..email = email.isEmpty ? null : email
      ..address = (_groupCategory == 'Sundry Debtor' || _groupCategory == 'Sundry Creditor') ? address : null
      ..route = _selectedRoute
      ..salesman = _selectedSalesman
      ..gstin = gstin.isEmpty ? null : gstin
      ..priceCategory = _priceCategory
      ..creditLimitAmount = creditLimitAmt
      ..creditDaysLimit = creditDays
      ..isCreditControlEnabled = _isCreditControlEnabled
      ..openingBalance = openingBal
      ..balanceType = _balanceType
      ..isPortalAccessEnabled = _isPortalAccessEnabled
      ..loginUsername = username.isEmpty ? null : username
      ..loginPassword = password.isEmpty ? null : password;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.accounts.put(newAccount);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account "$name" safaltapurvak save ho gaya!'), backgroundColor: Colors.green),
    );

    // Reset Form
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _houseNoController.clear();
    _streetController.clear();
    _landmarkController.clear();
    _pincodeController.clear();
    _cityController.clear();
    _stateController.clear();
    _gstinController.clear();
    _balanceController.clear();
    _creditLimitAmountController.clear();
    _creditDaysController.clear();
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _groupCategory = 'Sundry Debtor';
      _balanceType = 'Dr';
      _priceCategory = 'A';
      _isCreditControlEnabled = false;
      _isPortalAccessEnabled = false;
      _selectedRoute = null;
      _selectedSalesman = null;
    });

    // Pop and return name if opened from Sales/Purchase
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    bool isParty = (_groupCategory == 'Sundry Debtor' || _groupCategory == 'Sundry Creditor');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account & Client Portal Setup'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Group Category Dropdown
              DropdownButtonFormField<String>(
                value: _groupCategory,
                items: _groupCategories.map((group) {
                  return DropdownMenuItem(value: group, child: Text(group, style: const TextStyle(fontWeight: FontWeight.bold)));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _groupCategory = val!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Account Group Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category, color: Colors.teal),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Account Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account / Business Name *', 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.business),
                  hintText: 'e.g. Ramesh Shop, HDFC Bank, Rent Account',
                ),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
              ),
              const SizedBox(height: 12),

              // 3. Phone & Email
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                      onSubmitted: (_) => isParty ? FocusScope.of(context).requestFocus(_houseNoFocus) : FocusScope.of(context).requestFocus(_balanceFocus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Address & Price Tier
              if (isParty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Address Details & Logistics:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        value: _priceCategory,
                        items: _categoryList.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text('Tier $cat'));
                        }).toList(),
                        onChanged: (val) => setState(() => _priceCategory = val!),
                        decoration: const InputDecoration(labelText: 'Price Tier', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _houseNoController,
                        focusNode: _houseNoFocus,
                        decoration: const InputDecoration(labelText: 'House / Shop No', border: OutlineInputBorder()),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_streetFocus),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _streetController,
                        focusNode: _streetFocus,
                        decoration: const InputDecoration(labelText: 'Street / Area', border: OutlineInputBorder()),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_landmarkFocus),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _landmarkController,
                        focusNode: _landmarkFocus,
                        decoration: const InputDecoration(labelText: 'Landmark', border: OutlineInputBorder()),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_pincodeFocus),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        focusNode: _pincodeFocus,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder(), counterText: ''),
                        onChanged: (val) {
                          if (val.length == 6) {
                            _lookupPincode(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City / District', border: OutlineInputBorder())),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder())),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔥 Route Dropdown with Quick Add Button
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: (_availableRoutes.contains(_selectedRoute)) ? _selectedRoute : null,
                        hint: const Text('Select Route / Area'),
                        isExpanded: true,
                        items: _availableRoutes.map((route) {
                          return DropdownMenuItem(value: route, child: Text(route));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRoute = val),
                        decoration: const InputDecoration(
                          labelText: 'Route / Area',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.alt_route, color: Colors.teal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal, size: 30),
                      tooltip: 'Add New Route',
                      onPressed: () {
                        _showQuickAddDialog('Route', (newRoute) {
                          setState(() {
                            _availableRoutes.add(newRoute);
                            _selectedRoute = newRoute;
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔥 Salesman Dropdown with Quick Add Button
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: (_availableSalesmen.contains(_selectedSalesman)) ? _selectedSalesman : null,
                        hint: const Text('Select Salesman / User'),
                        isExpanded: true,
                        items: _availableSalesmen.map((salesman) {
                          return DropdownMenuItem(value: salesman, child: Text(salesman));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedSalesman = val),
                        decoration: const InputDecoration(
                          labelText: 'Assigned Salesman / User',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_pin, color: Colors.teal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal, size: 30),
                      tooltip: 'Add New Salesman',
                      onPressed: () {
                        _showQuickAddDialog('Salesman', (newSalesman) {
                          setState(() {
                            _availableSalesmen.add(newSalesman);
                            _selectedSalesman = newSalesman;
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _gstinController,
                  focusNode: _gstinFocus,
                  decoration: const InputDecoration(labelText: 'GSTIN Number (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long)),
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(_balanceFocus),
                ),
                const SizedBox(height: 12),
              ],

              // 5. Opening Balance
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _balanceController,
                      focusNode: _balanceFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Opening Balance (₹)', border: OutlineInputBorder()),
                      onSubmitted: (_) => isParty ? FocusScope.of(context).requestFocus(_creditLimitFocus) : _saveAccount(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _balanceType,
                      items: const [
                        DropdownMenuItem(value: 'Dr', child: Text('Dr (Debit)')),
                        DropdownMenuItem(value: 'Cr', child: Text('Cr (Credit)')),
                      ],
                      onChanged: (val) => setState(() => _balanceType = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6. Credit Control
              if (_groupCategory == 'Sundry Debtor') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    border: Border.all(color: Colors.teal.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Credit Control & Overdue Limit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
                          Switch(
                            value: _isCreditControlEnabled,
                            activeColor: Colors.teal,
                            onChanged: (val) {
                              setState(() {
                                _isCreditControlEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const Text('Restrict new billing if credit limit or overdue days exceed.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _creditLimitAmountController,
                              focusNode: _creditLimitFocus,
                              keyboardType: TextInputType.number,
                              enabled: _isCreditControlEnabled,
                              decoration: const InputDecoration(labelText: 'Credit Limit (₹)', border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(_creditDaysFocus),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _creditDaysController,
                              focusNode: _creditDaysFocus,
                              keyboardType: TextInputType.number,
                              enabled: _isCreditControlEnabled,
                              decoration: const InputDecoration(labelText: 'Max Overdue Days', border: OutlineInputBorder(), hintText: 'e.g. 45', fillColor: Colors.white, filled: true),
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(_usernameFocus),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 7. 🔥 CLIENT PORTAL LOGIN SETUP SECTION
              if (isParty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    border: Border.all(color: Colors.indigo.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Client Portal Login Access', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 15)),
                          Switch(
                            value: _isPortalAccessEnabled,
                            activeColor: Colors.indigo,
                            onChanged: (val) {
                              setState(() {
                                _isPortalAccessEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const Text('Allow this party to log in and view their Ledger, Invoices & Returns.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              enabled: _isPortalAccessEnabled,
                              decoration: const InputDecoration(labelText: 'Login Username', border: OutlineInputBorder(), fillColor: Colors.white, filled: true, hintText: 'Phone / User ID'),
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: _isPortalAccessEnabled,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Login Password', border: OutlineInputBorder(), fillColor: Colors.white, filled: true, hintText: 'Secret Password'),
                              onSubmitted: (_) => _saveAccount(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _saveAccount,
                  child: const Text('Save Account & Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
