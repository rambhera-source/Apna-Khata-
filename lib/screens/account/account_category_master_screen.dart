import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account_category_model.dart';

class AccountCategoryMasterScreen extends StatefulWidget {
  const AccountCategoryMasterScreen({super.key});

  @override
  State<AccountCategoryMasterScreen> createState() => _AccountCategoryMasterScreenState();
}

class _AccountCategoryMasterScreenState extends State<AccountCategoryMasterScreen> {
  List<AccountCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseHelper.isar.accountCategoryModels.where().findAll();
    
    // If empty, insert default standard categories automatically
    if (categories.isEmpty) {
      final defaults = [
        'Sundry Debtor',
        'Sundry Creditor',
        'Bank Account',
        'Cash-in-Hand',
        'Direct Expense',
        'Indirect Expense',
        'Direct Income',
        'Indirect Income'
      ];
      
      await DatabaseHelper.isar.writeTxn(() async {
        for (var name in defaults) {
          final cat = AccountCategoryModel()..categoryName = name..allowedUsers = [];
          await DatabaseHelper.isar.accountCategoryModels.put(cat);
        }
      });
      final reloaded = await DatabaseHelper.isar.accountCategoryModels.where().findAll();
      setState(() {
        _categories = reloaded;
        _isLoading = false;
      });
    } else {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  void _showAddEditCategoryDialog({AccountCategoryModel? categoryToEdit}) {
    final controller = TextEditingController(text: categoryToEdit?.categoryName ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(categoryToEdit == null ? 'Add New Account Category' : 'Edit Category Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              String name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.isar.writeTxn(() async {
                  if (categoryToEdit == null) {
                    final newCat = AccountCategoryModel()
                      ..categoryName = name
                      ..allowedUsers = [];
                    await DatabaseHelper.isar.accountCategoryModels.put(newCat);
                  } else {
                    categoryToEdit.categoryName = name;
                    await DatabaseHelper.isar.accountCategoryModels.put(categoryToEdit);
                  }
                });
                _loadCategories();
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Categories Master'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(cat.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Allowed Users: ${cat.allowedUsers.isEmpty ? "All / Global" : cat.allowedUsers.join(", ")}', style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
                            onPressed: () => _showAddEditCategoryDialog(categoryToEdit: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper.isar.writeTxn(() async {
                                await DatabaseHelper.isar.accountCategoryModels.delete(cat.id);
                              });
                              _loadCategories();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
