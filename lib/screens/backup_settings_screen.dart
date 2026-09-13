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
  String _backupDestination = 'Google Drive / Local Pen Drive Folder';
  String _backupFrequency = 'Daily on App Close';
  bool _isActionRunning = false;

  // 📤 Export Backup to File / Pen Drive
  void _exportBackup() async {
    setState(() => _isActionRunning = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate file export process
    setState(() => _isActionRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup File Successfully Exported & Saved to Pen Drive/Folder!')),
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
      await Future.delayed(const Duration(seconds: 2)); // Simulate restore process
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

          // ================= AUTOMATED BACKUP SECTION =================
          const Text(
            'Automated Backup System',
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
                  ListTile(
                    leading: const Icon(Icons.schedule, color: Colors.teal),
                    title: const Text('Backup Frequency'),
                    subtitle: Text(_backupFrequency),
                    trailing: DropdownButton<String>(
                      value: _backupFrequency,
                      items: ['Daily on App Close', 'Every 3 Days', 'Weekly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _backupFrequency = val!),
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
              // 📤 Export Button
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
              // 📥 Import Button
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

          // Instant Manual Backup Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isActionRunning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.backup),
            label: Text(_isActionRunning ? 'Processing...' : 'Backup Now (Save to Pen Drive / Drive)', style: const TextStyle(fontSize: 15)),
            onPressed: _isActionRunning ? null : _exportBackup,
          ),
        ],
      ),
    );
  }
}
