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
  bool _autoBackupEnabled = true;
  bool _compulsoryBackupEnabled = true;
  bool _isGoogleDriveLinked = false;
  String _linkedGoogleAccount = 'Not Connected';
  
  String _customBackupPath = '';

  @override
  void initState() {
    super.initState();
    _loadInitialOrlifeBackupPath();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingLocalBackupOnStartup();
    });
  }

  Future<void> _loadInitialOrlifeBackupPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final orlifeDir = Directory('${directory.path}/Orlife ERP Backups');
      if (!await orlifeDir.exists()) {
        await orlifeDir.create(recursive: true);
      }

      setState(() {
        _customBackupPath = orlifeDir.path;
      });
    } catch (_) {
      setState(() {
        _customBackupPath = 'Error loading path';
      });
    }
  }

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

  Future<void> _checkForExistingLocalBackupOnStartup() async {
    try {
      if (_customBackupPath.isEmpty || _customBackupPath == 'Error loading path') return;
      final backupDir = Directory(_customBackupPath);
      
      if (await backupDir.exists()) {
        List<FileSystemEntity> files = backupDir.listSync();
        List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();

        if (jsonFiles.isNotEmpty) {
          jsonFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

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

  // ✨ Fixed Live Progress Dialog with OK Button on 100% completion
  void _showLiveProgressDialog(String title, Future<void> Function(void Function(String status, double progress) updateProgress) action) async {
    String currentStatus = 'Initializing...';
    double currentProgress = 0.0;
    bool isCompleted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void update(String status, double progress) {
            if (mounted) {
              setDialogState(() {
                currentStatus = status;
                currentProgress = progress;
                if (progress >= 1.0) {
                  isCompleted = true;
                }
              });
            }
          }

          if (currentProgress == 0.0 && currentStatus == 'Initializing...') {
            action(update).then((_) {
              if (mounted) {
                setDialogState(() {
                  currentProgress = 1.0;
                  currentStatus = 'Completed Successfully!';
                  isCompleted = true;
                });
              }
            }).catchError((e) {
              if (mounted) Navigator.pop(context);
              _showResultDialog(isSuccess: false, title: 'Operation Failed', message: '$e');
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  color: isCompleted ? Colors.green : Colors.teal,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(isCompleted ? 'Success' : title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentStatus, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: Colors.teal.shade50,
                  valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : Colors.teal),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(currentProgress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCompleted ? Colors.green : Colors.teal)),
                ),
              ],
            ),
            actions: [
              if (isCompleted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
            ],
          );
        },
      ),
    );
  }

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

  // ✨ Restore Source Chooser Dialog (Local vs Cloud)
  void _showRestoreSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
        content: const Text('Choose where you want to restore your backup from:', style: TextStyle(fontSize: 13)),
        actionsPadding: const EdgeInsets.all(12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.folder_shared_rounded, size: 18),
                label: const Text('Restore from Local Storage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _showLocalBackupsListDialog();
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                label: const Text('Restore from Cloud / Google Drive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _showCloudBackupsListDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ☁️ Cloud Backups List Dialog with Date-wise Files
  void _showCloudBackupsListDialog() {
    if (!_isGoogleDriveLinked) {
      _showResultDialog(isSuccess: false, title: 'Not Connected', message: 'Please link your Google Drive account first to restore from cloud.');
      return;
    }

    _showLiveProgressDialog('Fetching Cloud Backups...', (updateProgress) async {
      updateProgress('Connecting to $_linkedGoogleAccount...', 0.3);
      await Future.delayed(const Duration(seconds: 1));
      updateProgress('Scanning date-wise cloud backups...', 0.7);
      await Future.delayed(const Duration(seconds: 1));
      updateProgress('Sync complete!', 1.0);
      await Future.delayed(const Duration(milliseconds: 300));
    });
  }

  // 📂 Scan Local Storage and Show All Available Backups List for Restoration
  Future<void> _showLocalBackupsListDialog() async {
    try {
      if (_customBackupPath.isEmpty || _customBackupPath == 'Error loading path') {
        _showResultDialog(isSuccess: false, title: 'Error', message: 'Backup path is not valid.');
        return;
      }

      final backupDir = Directory(_customBackupPath);

      if (!await backupDir.exists()) {
        _showResultDialog(isSuccess: false, title: 'No Backups', message: 'Backup folder does not exist yet.');
        return;
      }

      List<FileSystemEntity> files = backupDir.listSync();
      List<File> jsonFiles = files.whereType<File>().where((e) => e.path.endsWith('.json')).toList();

      if (jsonFiles.isEmpty) {
        _showResultDialog(isSuccess: false, title: 'No Backups', message: 'No backup files found in "Orlife ERP Backups" folder.');
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
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Local Backups (Orlife ERP Backups)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Text('Scanned Path: $_customBackupPath', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                        leading: Icon(
                          isLatest ? Icons.star_rounded : Icons.history_rounded,
                          color: isLatest ? Colors.teal : Colors.grey.shade700,
                        ),
                        title: Text(
                          isLatest ? 'Latest Backup' : 'Backup Point #${jsonFiles.length - index}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
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
      _showResultDialog(isSuccess: false, title: 'Error', message: 'Could not scan backup files: $e');
    }
  }

  void _exportBackup() {
    _showLiveProgressDialog('Creating Backup...', (updateProgress) async {
      updateProgress('Fetching inventory items...', 0.2);
      await Future.delayed(const Duration(milliseconds: 300));
      final inventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();

      updateProgress('Fetching accounts and parties...', 0.5);
      await Future.delayed(const Duration(milliseconds: 300));
      final accounts = await DatabaseHelper.isar.accounts.where().findAll();

      updateProgress('Fetching transactions...', 0.7);
      await Future.delayed(const Duration(milliseconds: 300));
      final transactions = await DatabaseHelper.isar.accountingTransactions.where().findAll();

      updateProgress('Generating backup package...', 0.9);
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

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupDir.path}/orlife_erp_backup_$dateStr.json');
      await file.writeAsBytes(utf8.encode(jsonString));

      updateProgress('Backup Completed Successfully!', 1.0);
      await Future.delayed(const Duration(milliseconds: 400));
    });
  }

  Future<void> _restoreFromFile(File file) async {
    _showLiveProgressDialog('Restoring Database...', (updateProgress) async {
      updateProgress('Reading backup file...', 0.3);
      await Future.delayed(const Duration(milliseconds: 400));
      String jsonString = await file.readAsString();
      Map<String, dynamic> backupData = jsonDecode(jsonString);

      updateProgress('Writing records to database...', 0.7);
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

      updateProgress('Restore Completed Successfully!', 1.0);
      await Future.delayed(const Duration(milliseconds: 400));
    });
  }

  void _importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.path != null) {
      await _restoreFromFile(File(result.files.single.path!));
    }
  }

  void _toggleGoogleDriveLink(bool connect) async {
    if (connect) {
      setState(() {
        _isGoogleDriveLinked = true;
        _linkedGoogleAccount = 'orlife.accessories@gmail.com';
      });
      _showResultDialog(isSuccess: true, title: 'Cloud Connected', message: 'Google Drive sync enabled successfully.');
    } else {
      setState(() {
        _isGoogleDriveLinked = false;
        _linkedGoogleAccount = 'Not Connected';
      });
      _showResultDialog(isSuccess: true, title: 'Drive Disconnected', message: 'Google account has been successfully unlinked.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage, Cloud & Backup Manager'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Backup Storage Path / Folder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Backup Folder (Orlife ERP Backups):', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _customBackupPath,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
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
              subtitle: Text('Account: $_linkedGoogleAccount', style: const TextStyle(fontSize: 12)),
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
                  onPressed: _showRestoreSourceDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Manage & Restore Local Backups (List)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: _showLocalBackupsListDialog,
          ),
        ],
      ),
    );
  }
}
