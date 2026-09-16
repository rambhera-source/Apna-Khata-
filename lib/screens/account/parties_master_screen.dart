import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/transaction_model.dart';
import 'add_account_screen.dart';

class PartiesMasterScreen extends StatefulWidget {
  const PartiesMasterScreen({super.key});

  @override
  State<PartiesMasterScreen> createState() => _PartiesMasterScreenState();
}

class _PartiesMasterScreenState extends State<PartiesMasterScreen> {
  List<Account> _partiesList = [];
  bool _isLoading = true;

  // 🔥 Selection State Management
  final Set<int> _selectedPartyIds = {};
  bool _isSelectAll = false;

  // 🔥 Category Filter Variable
  String _selectedCategoryFilter = 'All';
  final List<String> _filterCategories = [
    'All',
    'Sundry Debtor',
    'Sundry Creditor',
    'Bank Account',
    'Cash-in-Hand',
    'Direct Expense',
    'Indirect Expense',
    'Direct Income',
    'Indirect Income',
  ];

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    setState(() {
      _partiesList = accounts;
      _isLoading = false;
      _selectedPartyIds.clear();
      _isSelectAll = false;
    });
  }

  // 🛡️ Helper to check if a party has any recorded transactions
  Future<bool> _hasTransactions(String partyName) async {
    final txns = await DatabaseHelper.isar.accountingTransactions
        .filter()
        .partyNameContains(partyName, caseSensitive: false)
        .findAll();
    return txns.isNotEmpty;
  }

  // 🗑️ Bulk Delete with Transaction Safety Check
  void _confirmBulkDelete() async {
    if (_selectedPartyIds.isEmpty) return;

    // Filter out parties that have transactions
    List<Account> deletableParties = [];
    List<String> skippedParties = [];

    for (int id in _selectedPartyIds) {
      final party = _partiesList.firstWhere((p) => p.id == id);
      bool hasTxn = await _hasTransactions(party.name);
      if (hasTxn) {
        skippedParties.add(party.name);
      } else {
        deletableParties.add(party);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Parties?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete ${deletableParties.length} selected parties?', style: const TextStyle(fontSize: 13)),
            if (skippedParties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Skipped: ${skippedParties.length} party/parties have existing transactions and cannot be deleted.',
                style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (deletableParties.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseHelper.isar.writeTxn(() async {
                  for (var party in deletableParties) {
                    await DatabaseHelper.isar.accounts.delete(party.id);
                  }
                });
                _loadParties();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected safe parties deleted successfully!'), backgroundColor: Colors.red),
                );
              },
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  // 🗑️ Single Delete with Transaction Safety Check
  void _confirmDelete(Account party) async {
    bool hasTxn = await _hasTransactions(party.name);

    if (!mounted) return;

    if (hasTxn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Cannot Delete Party', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text('Transaction available! "${party.name}" ke naam par transactions maujood hain. Aap is account ko delete nahi kar sakte.', style: const TextStyle(fontSize: 13)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Party?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Delete "${party.name}"?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(60, 32)),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.isar.writeTxn(() async {
                await DatabaseHelper.isar.accounts.delete(party.id);
              });
              _loadParties();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedParties() async {
    if (_selectedPartyIds.isEmpty) return;

    try {
      List<List<dynamic>> rows = [
        ['Party Name', 'Mobile Number', 'Group Category', 'Opening Balance', 'Balance Type', 'GSTIN', 'Address']
      ];

      for (var party in _partiesList) {
        if (_selectedPartyIds.contains(party.id)) {
          rows.add([
            party.name,
            party.phone ?? '',
            party.groupCategory,
            party.openingBalance,
            party.balanceType,
            party.gstin ?? '',
            party.address ?? ''
          ]);
        }
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Selected_Parties_Export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Exported ${_selectedPartyIds.length} Parties from ORLIFE ERP.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
          var bytes = file.bytes ?? await File(file.path!).readAsBytes();
          var excelFile = excel_pkg.Excel.decodeBytes(bytes);
          for (var table in excelFile.tables.keys) {
            var sheet = excelFile.tables[table];
            if (sheet != null) {
              for (var row in sheet.rows) {
                rows.add(row.map((cell) => cell?.value ?? '').toList());
              }
            }
            break;
          }
        } else {
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

            if (name.isEmpty || mobile.isEmpty) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Mandatory field (Name/Mobile) is missing');
              failedRows.add(failedRow);
              continue;
            }

            final existingByMobile = await DatabaseHelper.isar.accounts
                .filter()
                .phoneEqualTo(mobile)
                .findFirst();

            final existingByName = await DatabaseHelper.isar.accounts
                .filter()
                .nameEqualTo(name, caseSensitive: false)
                .findFirst();

            if (existingByMobile != null || existingByName != null) {
              var failedRow = List.from(row);
              while (failedRow.length < rows[0].length) failedRow.add('');
              failedRow.add('Duplicate record already exists');
              failedRows.add(failedRow);
              continue;
            }

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
        Navigator.pop(context);
        _loadParties();

        String? errorFilePath;
        if (failedRows.length > 1) {
          String errorCsvData = const ListToCsvConverter().convert(failedRows);
          final output = await getTemporaryDirectory();
          final errFile = File('${output.path}/Failed_Parties_Report.csv');
          await errFile.writeAsString(errorCsvData);
          errorFilePath = errFile.path;
        }

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

  @override
  Widget build(BuildContext context) {
    final filteredParties = _selectedCategoryFilter == 'All'
        ? _partiesList
        : _partiesList.where((p) => p.groupCategory == _selectedCategoryFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties & Accounts Master'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedPartyIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              tooltip: 'Export Selected',
              onPressed: _exportSelectedParties,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Delete Selected',
              onPressed: _confirmBulkDelete,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Excel/CSV Template',
            onPressed: _downloadExcelTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Bulk Import from Excel/CSV',
            onPressed: _importPartiesUniversal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                Checkbox(
                  value: _isSelectAll,
                  activeColor: Colors.teal,
                  onChanged: (bool? value) {
                    setState(() {
                      _isSelectAll = value ?? false;
                      if (_isSelectAll) {
                        _selectedPartyIds.addAll(filteredParties.map((p) => p.id));
                      } else {
                        _selectedPartyIds.clear();
                      }
                    });
                  },
                ),
                const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryFilter,
                      isDense: true,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12),
                      items: _filterCategories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat == 'All' ? '📂 All (${_partiesList.length})' : '📂 $cat', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategoryFilter = val!;
                          _selectedPartyIds.clear();
                          _isSelectAll = false;
                        });
                      },
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(90, 32)),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 11)),
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
                : filteredParties.isEmpty
                    ? const Center(
                        child: Text(
                          'Is category mein koi party nahi mili.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = filteredParties[index];
                          bool isSelected = _selectedPartyIds.contains(party.id);

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.teal,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedPartyIds.add(party.id);
                                        } else {
                                          _selectedPartyIds.remove(party.id);
                                          _isSelectAll = false;
                                        }
                                      });
                                    },
                                  ),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      party.name.isNotEmpty ? party.name[0].toUpperCase() : 'A',
                                      style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text('${party.groupCategory} | Ph: ${party.phone ?? 'N/A'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${party.openingBalance} ${party.balanceType}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: party.balanceType == 'Dr' ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 16),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                                      );
                                      _loadParties();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
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
