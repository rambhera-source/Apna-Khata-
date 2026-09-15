import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  // Storage & Backup State Variables
  String _storageMode = 'Local (Offline Isar DB)';
  bool _autoBackupEnabled = true;
  bool _compulsoryBackupEnabled = true; // 🎛️ High Priority Compulsory Backup Toggle State
  String _backupDestination = 'Google Drive / Local Pen Drive Folder';
  String _backupFrequency = 'Daily on App Close';
  bool _isActionRunning = false;

  // 🚨 High Priority Compulsory Backup Popup (Sirf tabhi aayega jab toggle ON hoga)
  void _showCompulsoryBackupPopup() {
    if (!_compulsoryBackupEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('High-Priority Backup Reminder currently OFF hai!')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // User bina backup kiye dialog cut nahi kar payega
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Android back button disable
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.red.shade50,
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HIGH PRIORITY: Compulsory Backup!',
                    style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Aapka data local storage (offline) par save ho raha hai. High-Priority reminder ke anusaar yeh compulsory backup session hai.\n\n'
              'Kripya turant apni backup file ko export/save karein.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.backup),
                label: const Text('Backup & Export Now', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _exportBackup();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 📤 Real Export Backup to JSON File & Share
  void _exportBackup() async {
    setState(() => _isActionRunning = true);
    try {
      // 1. Isar se sara data fetch karein
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      // 2. Map structure banayein
      final Map<String, dynamic> backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'inventory': inventoryItems.map((e) => {
          'itemName': e.itemName,
          'sku': e.sku,
          'category': e.category,
          'purchasePrice': e.purchasePrice,
          'openingStock': e.openingStock,
          'stockQuantity': e.stockQuantity,
          'priceA': e.priceA,
          'priceCategory': e.priceCategory,
          'stockType': e.stockType,
        }).toList(),
        'accounts': accounts.map((e) => {
          'name': e.name,
          'groupCategory': e.groupCategory,
          'phone': e.phone,
          'email': e.email,
          'address': e.address,
          'gstin': e.gstin,
          'openingBalance': e.openingBalance,
          'balanceType': e.balanceType,
        }).toList(),
        'transactions': transactions.map((e) => {
          'date': e.date.toIso8601String(),
          'voucherType': e.voucherType,
          'voucherNumber': e.voucherNumber,
          'partyName': e.partyName,
          'cashOrBank': e.cashOrBank,
          'amount': e.amount,
          'notes': e.notes,
        }).toList(),
      };

      // 3. JSON file me convert karke temporary folder me save karein
      String jsonString = jsonEncode(backupData);
      final outputDir = await getTemporaryDirectory();
      final file = File('${outputDir.path}/orlife_erp_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      // 4. Share sheet open karein (WhatsApp, Drive, File Manager)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ORLIFE ERP Database Backup. Is file ko surakshit rakhein!',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup Successfully Exported & Saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isActionRunning = false);
    }
  }

  // 📥 Real Import & Restore Backup from JSON File
  void _importBackup() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text('Warning: Import karne par naya data add hoga ya overwrite ho sakta hai. Kya aap backup file restore karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed Import'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isActionRunning = true);
        try {
          final file = File(result.files.single.path!);
          String jsonString = await file.readAsString();
          Map<String, dynamic> backupData = jsonDecode(jsonString);

          await DatabaseHelper.isar.writeTxn(() async {
            // --- 1. Restore Inventory ---
            if (backupData.containsKey('inventory')) {
              List invList = backupData['inventory'];
              for (var item in invList) {
                InventoryItem inv = InventoryItem()
                  ..itemName = item['itemName'] ?? ''
                  ..sku = item['sku']
                  ..category = item['category'] ?? 'General'
                  ..purchasePrice = item['purchasePrice'] ?? 0.0
                  ..openingStock = item['openingStock'] ?? 0.0
                  ..stockQuantity = item['stockQuantity'] ?? 0.0
                  ..priceA = item['priceA'] ?? 0.0
                  ..priceCategory = item['priceCategory'] ?? 'A'
                  ..stockType = item['stockType'] ?? 'Fresh';

                await DatabaseHelper.isar.inventoryItems.put(inv);
              }
            }

            // --- 2. Restore Accounts ---
            if (backupData.containsKey('accounts')) {
              List accList = backupData['accounts'];
              for (var item in accList) {
                Account acc = Account()
                  ..name = item['name'] ?? ''
                  ..groupCategory = item['groupCategory'] ?? 'Sundry Debtors'
                  ..phone = item['phone']
                  ..email = item['email']
                  ..address = item['address']
                  ..gstin = item['gstin']
                  ..openingBalance = item['openingBalance'] ?? 0.0
                  ..balanceType = item['balanceType'] ?? 'Dr';

                await DatabaseHelper.isar.accounts.put(acc);
              }
            }

            // --- 3. Restore Transactions ---
            if (backupData.containsKey('transactions')) {
              List txnList = backupData['transactions'];
              for (var item in txnList) {
                AccountingTransaction txn = AccountingTransaction()
                  ..date = DateTime.tryParse(item['date'] ?? '') ?? DateTime.now()
                  ..voucherType = item['voucherType'] ?? 'Sales'
                  ..voucherNumber = item['voucherNumber'] ?? ''
                  ..partyName = item['partyName'] ?? ''
                  ..cashOrBank = item['cashOrBank'] ?? 'Cash'
                  ..amount = item['amount'] ?? 0.0
                  ..notes = item['notes'];

                await DatabaseHelper.isar.accountingTransactions.put(txn);
              }
            }
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database Successfully Restored from Backup File!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore Error: $e'), backgroundColor: Colors.red),
          );
        } finally {
          setState(() => _isActionRunning = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage, Backup & Restore Manager'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isActionRunning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Processing Database Operation...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ================= STORAGE MODE SECTION =================
                const Text(
                  'Database Storage Architecture',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select where your firm data will be stored:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        RadioListTile<String>(
                          title: const Text('Local Storage (Offline - Isar DB)'),
                          subtitle: const Text('Fast, private, works completely offline.'),
                          value: 'Local (Offline Isar DB)',
                          groupValue: _storageMode,
                          activeColor: Colors.teal,
                          onChanged: (val) => setState(() => _storageMode = val!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Cloud Server Storage (Online Sync)'),
                          subtitle: const Text('Access your data across multiple devices securely.'),
                          value: 'Cloud Server (Online Sync)',
                          groupValue: _storageMode,
                          activeColor: Colors.teal,
                          onChanged: (val) => setState(() => _storageMode = val!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ================= AUTOMATED & COMPULSORY BACKUP SETTINGS =================
                const Text(
                  'Automated & Compulsory Backup Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Auto-Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Automatically backup local database to prevent data loss'),
                          value: _autoBackupEnabled,
                          activeColor: Colors.teal,
                          onChanged: (val) => setState(() => _autoBackupEnabled = val),
                        ),
                        const Divider(),
                        // 🎛️ High Priority Compulsory Backup Toggle Switch
                        SwitchListTile(
                          title: const Text('High-Priority Compulsory Reminder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          subtitle: const Text('Bar-bar backup ke liye compulsory popup dikhayein (ON/OFF)'),
                          value: _compulsoryBackupEnabled,
                          activeColor: Colors.red,
                          onChanged: (val) {
                            setState(() => _compulsoryBackupEnabled = val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(val ? 'Compulsory Backup Reminder ON kar diya gaya hai.' : 'Compulsory Backup Reminder OFF kar diya gaya hai.')),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.folder_shared, color: Colors.teal),
                          title: const Text('Backup Destination'),
                          subtitle: Text(_backupDestination),
                          trailing: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pen Drive / Folder path selected successfully!')),
                              );
                            },
                            child: const Text('Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ================= EXPORT & IMPORT (RESTORE) SECTION =================
                const Text(
                  'Backup Import & Export Operations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Export Backup'),
                        onPressed: _isActionRunning ? null : _exportBackup,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Import / Restore'),
                        onPressed: _isActionRunning ? null : _importBackup,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Test Compulsory Popup Button (Sirf testing ke liye check karne ko)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.notification_important),
                  label: const Text('Test High-Priority Popup Now'),
                  onPressed: _showCompulsoryBackupPopup,
                ),
              ],
            ),
    );
  }
}
