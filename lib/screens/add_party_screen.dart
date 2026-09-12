import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'http://www.flutter.dev/' as http; // Agar pincode API call karni ho (optional)
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/party.dart';

class AddPartyScreen extends StatefulWidget {
  const AddPartyScreen({super.key});

  @override
  State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  // Controllers for Professional Fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Detailed Address Controllers
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  final _gstinController = TextEditingController();
  final _balanceController = TextEditingController();

  // Professional Defaults
  String _partyType = 'Sundry Debtor'; // Sundry Debtor (Customer) or Sundry Creditor (Supplier)
  String _balanceType = 'Dr'; // Dr (Debit) or Cr (Credit)

  // Focus Nodes for Smooth Navigation
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _houseNoFocus = FocusNode();
  final FocusNode _streetFocus = FocusNode();
  final FocusNode _landmarkFocus = FocusNode();
  final FocusNode _pincodeFocus = FocusNode();
  final FocusNode _gstinFocus = FocusNode();
  final FocusNode _balanceFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _gstinController.dispose();
    _balanceController.dispose();
    
    _phoneFocus.dispose();
    _houseNoFocus.dispose();
    _streetFocus.dispose();
    _landmarkFocus.dispose();
    _pincodeFocus.dispose();
    _gstinFocus.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  // Pincode Lookup Function (Pincode daalte hi City & State auto-fill karne ke liye)
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
        // Fallback agar internet na ho
      }
    }
  }

  Future<void> _saveParty() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    
    // Structured Address combine karke ek professional address string banana
    final address = '${_houseNoController.text.trim()}, ${_streetController.text.trim()}, Landmark: ${_landmarkController.text.trim()}, City: ${_cityController.text.trim()}, State: ${_stateController.text.trim()} - Pincode: ${_pincodeController.text.trim()}';
    
    final gstin = _gstinController.text.trim();
    double openingBal = double.tryParse(_balanceController.text) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Party ka Naam (Name) likhein!')),
      );
      return;
    }

    // 🛑 DUPLICATE NAME CHECK (Same naam ki party dobara nahi banne degi)
    final existingParty = await DatabaseHelper.isar.parties
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .findFirst();

    if (existingParty != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: "$name" naam ki party pehle se bani hui hai!')),
      );
      return;
    }

    final newParty = Party()
      ..name = name
      ..phone = phone
      ..address = address
      ..partyType = _partyType // Sundry Debtor / Sundry Creditor
      ..gstin = gstin.isEmpty ? null : gstin
      ..openingBalance = openingBal
      ..balanceType = _balanceType; // Dr / Cr

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.parties.put(newParty);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Party "$name" safaltapurvak save ho gayi!')),
    );

    // Form clear kar dein
    _nameController.clear();
    _phoneController.clear();
    _houseNoController.clear();
    _streetController.clear();
    _landmarkController.clear();
    _pincodeController.clear();
    _cityController.clear();
    _stateController.clear();
    _gstinController.clear();
    _balanceController.clear();
    setState(() {
      _partyType = 'Sundry Debtor';
      _balanceType = 'Dr';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Professional Party (Ledger Master)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Party Type (Sundry Debtors / Sundry Creditors)
              Row(
                children: [
                  const Text('Party Group:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _partyType,
                      items: const [
                        DropdownMenuItem(value: 'Sundry Debtor', child: Text('Sundry Debtor (Customer)')),
                        DropdownMenuItem(value: 'Sundry Creditor', child: Text('Sundry Creditor (Supplier)')),
                      ],
                      onChanged: (val) => setState(() => _partyType = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Party Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Party / Business Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
              ),
              const SizedBox(height: 12),

              // 3. Phone Number
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_houseNoFocus),
              ),
              const SizedBox(height: 12),

              // 4. DETAILED ADDRESS SECTION
              const Text('Address Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 6),
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
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_gstinFocus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City / District', border: OutlineInputBorder()),
                      readOnly: false, // Auto-filled par edit bhi kar sakte hain
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _stateController,
                      decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                      readOnly: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. GSTIN Number
              TextField(
                controller: _gstinController,
                focusNode: _gstinFocus,
                decoration: const InputDecoration(
                  labelText: 'GSTIN Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long),
                  hintText: 'e.g. 36AAAAA0000A1Z5',
                ),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_balanceFocus),
              ),
              const SizedBox(height: 12),

              // 6. Opening Balance with Dr / Cr
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _balanceController,
                      focusNode: _balanceFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance (₹)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _saveParty(),
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
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saveParty,
                  child: const Text('Save Professional Party', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
