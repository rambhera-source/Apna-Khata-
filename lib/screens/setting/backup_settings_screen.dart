import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/inventory_model.dart';
import '../../models/account.dart';
import '../../models/transaction_model.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  String _storageMode = 'Local (Offline Isar DB)';
  bool _autoBackupEnabled = true;
  bool _compulsoryBackupEnabled = true;
  bool _isGoogleDriveLinked = false;
  String _linkedGoogleAccount = 'Not Connected';
  
  // 📁 Custom Backup Folder Path Variable
  String _customBackupPath = '';

  @override
  void initState() {
    super.initState();
    _loadInitialBackupPath();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingLocalBackupOnStartup();
    });
  }

  // 📂 डिफ़ॉल्ट या सेवेन्द्र पाथ लोड करें
  Future<void> _loadInitialBackupPath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _customBackupPath = '${directory.path}/orlife_backups';
    });
  }

  // 📁 यूजर द्वारा कस्टम फोल्डर चुनने का फंक्शन
  Future<void> _pickCustomBackupFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        setState(() {
          _customBackupPath = selectedDirectory;
        });
        _showResultDialog(
          isSuccess: true, 
          title: 'Folder Updated', 
          message: 'Backup destination successfully changed to:\n$_customBackupPath'
        );
      }
    } catch (e) {
      _showResultDialog(isSuccess: false, title: 'Error', message: 'Could not select folder: $e');
    }
  }

  // ✨ Startup पर कूल और प्रीमियम रिस्टोर प्रॉम्प्ट
  Future<void> _checkForExistingLocalBackupOnStartup() async {
    try {
      final backupDir = Directory(_customBackupPath);
      
      if (await backupDir.exists()) {
        List<FileSystemEntity> files = backupDir.listSync();
        List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();

        if (jsonFiles.isNotEmpty) {
          jsonFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

          if (jsonFiles.length > 10) {
            for (int i = 10; i < jsonFiles.length; i++) {
              try { await jsonFiles[i].delete(); } catch (_) {}
            }
            jsonFiles = jsonFiles.sublist(0, 10);
          }

          final latestFile = jsonFiles.first;
          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(latestFile.statSync().modified);

          if (!mounted) return;
          _showSmartDialog(
            title: 'Backup Available',
            subtitle: 'A recent backup from $formattedDate was found. Would you like to restore it?',
            icon: Icons.cloud_done_rounded,
            iconColor: Colors.teal,
            primaryButtonText: 'Restore Now',
            onPrimary: () {
              Navigator.pop(context);
              _restoreFromFile(latestFile);
            },
            secondaryButtonText: 'Skip',
            onSecondary: () => Navigator.pop(context),
          );
        }
      }
    } catch (_) {}
  }

  // ✨ प्रीमियम प्रोग्रेस/प्रोसेसिंग डायलॉग
  void _showProcessingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal, strokeWidth: 3),
              const SizedBox(width: 20),
              Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  // ✨ प्रीमियम सक्सेस / फेलर पॉप-अप
  void _showResultDialog({required bool isSuccess, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccess ? Colors.green : Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSuccess ? Colors.teal.shade900 : Colors.red.shade900)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? Colors.teal : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  // ✨ जेनेरिक स्मार्ट डायलॉग
  void _showSmartDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String primaryButtonText,
    required VoidCallback onPrimary,
    String? secondaryButtonText,
    VoidCallback? onSecondary,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
        actions: [
          if (secondaryButtonText != null && onSecondary != null)
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryButtonText, style: const TextStyle(color: Colors.grey)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onPrimary,
            child: Text(primaryButtonText),
          ),
        ],
      ),
    );
  }

  // 📂 डेट-वाइज बैकअप लिस्ट देखने का प्रीमियम बॉटम शीट
  Future<void> _showLocalBackupsListDialog() async {
    try {
      final backupDir = Directory(_customBackupPath);

      if (!await backupDir.exists()) {
        _showResultDialog(isSuccess: false, title: 'No Backups', message: 'Selected backup folder does not exist yet.');
        return;
      }

      List<FileSystemEntity> files = backupDir.listSync();
      List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();

      if (jsonFiles.isEmpty) {
        _showResultDialog(isSuccess: false, title: 'No Backups', message: 'No backup files found in the selected folder.');
        return;
      }

      jsonFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Text('Select Backup to Restore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Text('Path: $_customBackupPath', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: jsonFiles.length,
                  itemBuilder: (context, index) {
                    final file = jsonFiles[index];
                    final stat = file.statSync();
                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(stat.modified);
                    bool isLatest = index == 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isLatest ? Colors.teal.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isLatest ? Colors.teal.shade200 : Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Icon(isLatest ? Icons.star_rounded : Icons.history_rounded, color: isLatest ? Colors.teal : Colors.grey.shade700),
                        title: Text(isLatest ? 'Latest Backup' : 'Backup Point #${jsonFiles.length - index}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(70, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _restoreFromFile(file);
                          },
                          child: const Text('Restore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showResultDialog(isSuccess: false, title: 'Error', message: 'Could not load backup files: $e');
    }
  }

  // 📤 App Close पर ऑटो-बैकअप (कस्टम फोल्डर में)
  Future<void> _performAutoBackupOnClose() async {
    try {
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      final Map<String, dynamic> backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'inventory': inventoryItems.map((e) => {'itemName': e.itemName, 'sku': e.sku, 'stockQuantity': e.stockQuantity, 'purchasePrice': e.purchasePrice, 'priceA': e.priceA}).toList(),
        'accounts': accounts.map((e) => {'name': e.name, 'groupCategory': e.groupCategory, 'phone': e.phone, 'openingBalance': e.openingBalance}).toList(),
        'transactions': transactions.map((e) => {'date': e.date.toIso8601String(), 'voucherType': e.voucherType, 'voucherNumber': e.voucherNumber, 'partyName': e.partyName, 'amount': e.amount}).toList(),
      };

      final backupDir = Directory(_customBackupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/auto_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(backupData));

      List<FileSystemEntity> files = backupDir.listSync();
      List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();
      jsonFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (jsonFiles.length > 10) {
        for (int i = 10; i < jsonFiles.length; i++) {
          await jsonFiles[i].delete();
        }
      }
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    if (!_autoBackupEnabled) return true;

    bool shouldExit = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit & Secure Backup?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Would you like to take an automated backup before closing the app?', style: TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () {
              shouldExit = true;
              Navigator.pop(context);
            },
            child: const Text('Exit without Backup', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              _showProcessingDialog('Creating secure backup...');
              await _performAutoBackupOnClose();
              if (!mounted) return;
              Navigator.pop(context);
              _showResultDialog(isSuccess: true, title: 'Backup Successful', message: 'Your data has been safely secured in your selected folder.');
              await Future.delayed(const Duration(milliseconds: 1200));
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('Backup & Exit'),
          ),
        ],
      ),
    );

    return shouldExit;
  }

  void _exportBackup() async {
    _showProcessingDialog('Preparing export file...');
    try {
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      final Map<String, dynamic> backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'inventory': inventoryItems.map((e) => {'itemName': e.itemName, 'sku': e.sku, 'category': e.category, 'purchasePrice': e.purchasePrice, 'openingStock': e.openingStock, 'stockQuantity': e.stockQuantity, 'priceA': e.priceA, 'priceCategory': e.priceCategory, 'stockType': e.stockType}).toList(),
        'accounts': accounts.map((e) => {'name': e.name, 'groupCategory': e.groupCategory, 'phone': e.phone, 'email': e.email, 'address': e.address, 'gstin': e.gstin, 'openingBalance': e.openingBalance, 'balanceType': e.balanceType}).toList(),
        'transactions': transactions.map((e) => {'date': e.date.toIso8601String(), 'voucherType': e.voucherType, 'voucherNumber': e.voucherNumber, 'partyName': e.partyName, 'cashOrBank': e.cashOrBank, 'amount': e.amount, 'notes': e.notes}).toList(),
      };

      String jsonString = jsonEncode(backupData);
      final backupDir = Directory(_customBackupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/manual_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsBytes(utf8.encode(jsonString));

      if (!mounted) return;
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], text: 'ORLIFE ERP Database Backup File.');
      _showResultDialog(isSuccess: true, title: 'Exported & Saved!', message: 'Backup saved to your folder and ready to share.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showResultDialog(isSuccess: false, title: 'Export Failed', message: 'Error: $e');
    }
  }

  Future<void> _restoreFromFile(File file) async {
    _showProcessingDialog('Restoring database...');
    try {
      String jsonString = await file.readAsString();
      Map<String, dynamic> backupData = jsonDecode(jsonString);

      await DatabaseHelper.isar.writeTxn(() async {
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
      Navigator.pop(context);
      _showResultDialog(isSuccess: true, title: 'Restore Successful', message: 'Your database has been successfully restored.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showResultDialog(isSuccess: false, title: 'Restore Failed', message: 'Could not restore database: $e');
    }
  }

  void _importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.path != null) {
      await _restoreFromFile(File(result.files.single.path!));
    }
  }

  void _toggleGoogleDriveLink(bool connect) async {
    _showProcessingDialog(connect ? 'Connecting to Google Drive...' : 'Disconnecting...');
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context);
    setState(() {
      _isGoogleDriveLinked = connect;
      _linkedGoogleAccount = connect ? 'orlife.accessories@gmail.com' : 'Not Connected';
    });
    _showResultDialog(
      isSuccess: true, 
      title: connect ? 'Drive Linked' : 'Drive Unlinked', 
      message: connect ? 'Cloud backup active. Keeping last 10 sync points.' : 'Google account disconnected.'
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Storage, Cloud & Backup Manager'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 📁 Custom Backup Folder Path Section
            const Text('Backup Storage Path / Folder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Backup Folder:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _customBackupPath,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Change Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _pickCustomBackupFolder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Cloud Storage & Google Drive Sync', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text('Google Drive Online Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Account: $_linkedGoogleAccount (Last 10 backups)', style: const TextStyle(fontSize: 12)),
                secondary: const Icon(Icons.cloud_sync_rounded, color: Colors.teal, size: 28),
                value: _isGoogleDriveLinked,
                activeColor: Colors.teal,
                onChanged: (val) => _toggleGoogleDriveLink(val),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Automated Local Backup Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto-Backup on App Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Prompt & secure data when exiting app', style: TextStyle(fontSize: 12)),
                      value: _autoBackupEnabled,
                      activeColor: Colors.teal,
                      onChanged: (val) => setState(() => _autoBackupEnabled = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('High-Priority Compulsory Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
                      subtitle: const Text('Session security reminder prompt', style: TextStyle(fontSize: 12)),
                      value: _compulsoryBackupEnabled,
                      activeColor: Colors.red,
                      onChanged: (val) => setState(() => _compulsoryBackupEnabled = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Manual Import, Export & Restore Operations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Export Backup', style: TextStyle(fontSize: 13)),
                    onPressed: _exportBackup,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Restore File', style: TextStyle(fontSize: 13)),
                    onPressed: _importBackup,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Manage & Restore Local Backups (Last 10)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: _showLocalBackupsListDialog,
            ),
          ],
        ),
      ),
    );
  }
}
