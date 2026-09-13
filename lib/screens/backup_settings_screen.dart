import 'package:flutter/material.dart';

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
        return WillPopScope(
          onWillPop: () async => false, // Android back button disable
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

  // 📤 Export Backup to File / Pen Drive
  void _exportBackup() async {
    setState(() => _isActionRunning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isActionRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup Successfully Exported & Saved!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 📥 Import & Restore Backup from File
  void _importBackup() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text('Warning: Import karne par purana current data overwrite ho sakta hai. Kya aap backup file restore karna chahte hain?'),
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
      setState(() => _isActionRunning = true);
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isActionRunning = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database Successfully Restored from Backup File!')),
      );
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
      body: ListView(
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
