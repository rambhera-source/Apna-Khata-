import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg; // Excel reading support
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'add_account_screen.dart';

class PartiesMasterScreen extends StatefulWidget {
  const PartiesMasterScreen({super.key});

  @override
  State<PartiesMasterScreen> createState() => _PartiesMasterScreenState();
}

class _PartiesMasterScreenState extends State<PartiesMasterScreen> {
  List<Account> _partiesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  // 📂 डेटाबेस से सभी अकाउंट्स/पार्टियों को लोड करना
  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _partiesList = accounts;
      _isLoading = false;
    });
  }

  // ⚠️ Delete Warning Popup (Yes/No)
  void _confirmDelete(Account party) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Party?'),
        content: Text('Kya aap sach mein "${party.name}" ko delete karna chahte hain? Yeh action wapas nahi liya ja sakta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.isar.writeTxn(() async {
                await DatabaseHelper.isar.accounts.delete(party.id);
              });
              _loadParties();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Party safely delete ho gayi!'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  // 📥 Download Excel Template Function
  Future<void> _downloadExcelTemplate() async {
    try {
      List<List<dynamic>> rows = [
        ['Party Name', 'Mobile Number', 'Account Group Category', 'Opening Balance', 'GSTIN Number', 'Pincode'],
        ['Ramesh Mobile Store', '9876543210', 'Sundry Debtor', '1500.0', '36AAAAA0000A1Z5', '500001'],
      ];

      String csvData = const ListToCsvConverter().convert(rows);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Party_Import_Template.csv');
      await file.writeAsString(csvData);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Yeh Parties Bulk Import karne ka Excel/CSV Template hai.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template download karne mein error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📊 Universal Excel & CSV Import with Progress Dialog & Error Report Generation
  Future<void> _importPartiesUniversal() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        List<List<dynamic>> rows = [];

        String extension = file.extension?.toLowerCase() ?? '';
        if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls') || extension == 'xlsx' || extension == 'xls') {
          // 📊 Handle Excel File (.xlsx / .xls)
          var bytes = file.bytes ?? await File(file.path!).readAsBytes();
          var excelFile = excel_pkg.Excel.decodeBytes(bytes);
          for (var table in excelFile.tables.keys) {
            var sheet = excelFile.tables[table];
            if (sheet != null) {
              for (var row in sheet.rows) {
                rows.add(row.map((cell) => cell?.value ?? '').toList());
              }
            }
            break; // First sheet only
          }
        } else {
          // 📄 Handle CSV / Text File
          String csvString = '';
          if (file.bytes != null) {
            csvString = utf8.decode(file.bytes!, allowMalformed: true);
          } else if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();
            csvString = utf8.decode(bytes, allowMalformed: true);
          }
          rows = const CsvToListConverter().convert(csvString);
        }

        if (rows.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file is empty or invalid!'), backgroundColor: Colors.orange),
          );
          return;
        }

        // 🔄 Show Processing Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Processing & Importing Parties...'),
              ],
            ),
          ),
        );

        int successCount = 0;
        List<List<dynamic>> failedRows = [];
        if (rows.isNotEmpty) {
          List<dynamic> header = List.from(rows[0]);
          header.add('Failure Reason');
          failedRows.add(header);
        }

        await DatabaseHelper.isar.writeTxn(() async {
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length < 3 || row[0].toString().trim().isEmpty) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Insufficient columns or empty Party Name');
              failedRows.add(failedRow);
              continue;
            }

            String name = row[0].toString().trim();
            String mobile = row[1].toString().trim();
            String groupCat = row[2].toString().trim().isNotEmpty ? row[2].toString().trim() : 'Sundry Debtor';
            double openingBal = row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0;
            String gstin = row.length > 4 ? row[4].toString().trim() : '';
            String pincode = row.length > 5 ? row[5].toString().trim() : '';

            // 1. Mandatory Fields Check
            if (name.isEmpty || mobile.isEmpty) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Mandatory field (Name/Mobile) is missing');
              failedRows.add(failedRow);
              continue;
            }

            // 2. Duplicate Check
            final existingByMobile = await DatabaseHelper.isar.accounts
                .filter()
                .phoneEqualTo(mobile)
                .findFirst();

            final existingByName = await DatabaseHelper.isar.accounts
                .filter()
                .nameEqualTo(name, caseSensitive: false)
                .findFirst();

            if (existingByMobile != null) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Duplicate Mobile Number already exists');
              failedRows.add(failedRow);
              continue;
            }

            if (existingByName != null) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Duplicate Party Name already exists');
              failedRows.add(failedRow);
              continue;
            }

            // 3. Save Account
            final account = Account()
              ..name = name
              ..phone = mobile
              ..groupCategory = groupCat
              ..openingBalance = openingBal
              ..balanceType = 'Dr'
              ..gstin = gstin.isEmpty ? null : gstin
              ..address = pincode.isNotEmpty ? 'Pincode: $pincode' : null;

            await DatabaseHelper.isar.accounts.put(account);
            successCount++;
          }
        });

        if (!mounted) return;
        Navigator.pop(context); // Close progress dialog
        _loadParties();

        // Agar koi fail records hain toh unki Error CSV file generate karein
        String? errorFilePath;
        if (failedRows.length > 1) {
          String errorCsvData = const ListToCsvConverter().convert(failedRows);
          final output = await getTemporaryDirectory();
          final errFile = File('${output.path}/Failed_Parties_Report.csv');
          await errFile.writeAsString(errorCsvData);
          errorFilePath = errFile.path;
        }

        // Show Process Report Dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Import Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successfully Imported: $successCount parties', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('❌ Failed / Skipped: ${failedRows.length > 1 ? failedRows.length - 1 : 0} parties', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                if (errorFilePath != null) ...[
                  const SizedBox(height: 12),
                  const Text('Kuch records duplicate ya invalid hone ki wajah se fail ho gaye hain. Aap failure report file download kar sakte hain.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              if (errorFilePath != null)
                TextButton.icon(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text('Download Error Report'),
                  onPressed: () {
                    Share.shareXFiles([XFile(errorFilePath!)], text: 'Yeh Bulk Import ki Failed Report hai.');
                  },
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✏️ Modify / Edit Party Dialog with Pincode Auto-Fill
  void _editParty(Account party) {
    final nameController = TextEditingController(text: party.name);
    final phoneController = TextEditingController(text: party.phone ?? '');
    final balanceController = TextEditingController(text: party.openingBalance.toString());
    final pincodeController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();

    // Pincode auto-fill function
    Future<void> lookupPincode(String pin) async {
      if (pin.length == 6) {
        try {
          final url = Uri.parse('https://api.postalpincode.in/pincode/$pin');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data[0]['Status'] == 'Success') {
              final postOffice = data[0]['PostOffice'][0];
              cityController.text = postOffice['District'] ?? '';
              stateController.text = postOffice['State'] ?? '';
            }
          }
        } catch (_) {}
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Party: ${party.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Party Name *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: balanceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Balance', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  controller: pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Pincode (Auto-fill City/State)', border: OutlineInputBorder(), counterText: ''),
                  onChanged: (val) {
                    if (val.length == 6) {
                      lookupPincode(val).then((_) => setDialogState(() {}));
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City / District', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: stateController, decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                String newName = nameController.text.trim();
                String newPhone = phoneController.text.trim();
                if (newName.isNotEmpty && newPhone.isNotEmpty) {
                  await DatabaseHelper.isar.writeTxn(() async {
                    party.name = newName;
                    party.phone = newPhone;
                    party.openingBalance = double.tryParse(balanceController.text) ?? party.openingBalance;
                    if (cityController.text.isNotEmpty) {
                      party.address = 'City: ${cityController.text}, State: ${stateController.text}, Pincode: ${pincodeController.text}';
                    }
                    await DatabaseHelper.isar.accounts.put(party);
                  });
                  Navigator.pop(context);
                  _loadParties();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Party successfully updated!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties & Accounts Master'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Excel/CSV Template',
            onPressed: _downloadExcelTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Bulk Import from Excel/CSV',
            onPressed: _importPartiesUniversal, // 🔥 Universal Excel & CSV Import
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Parties: ${_partiesList.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add New Party'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                    );
                    _loadParties();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _partiesList.isEmpty
                    ? const Center(
                        child: Text(
                          'Abhi tak koi party add nahi ki gayi hai.\nUpar "Add New Party" par click karein.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _partiesList.length,
                        itemBuilder: (context, index) {
                          final party = _partiesList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  party.name.isNotEmpty ? party.name[0].toUpperCase() : 'A',
                                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Group: ${party.groupCategory} | Phone: ${party.phone ?? 'N/A'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹ ${party.openingBalance} ${party.balanceType}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: party.balanceType == 'Dr' ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () => _editParty(party),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _confirmDelete(party),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
