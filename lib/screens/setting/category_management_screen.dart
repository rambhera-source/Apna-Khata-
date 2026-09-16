import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../database/database_helper.dart';
import '../../models/settings_model.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  Map<String, List<String>> _productCategoriesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    Map<String, List<String>> loadedMap = {};

    if (settings != null && settings.productCategories.isNotEmpty) {
      for (var catStr in settings.productCategories) {
        try {
          var decoded = jsonDecode(catStr);
          if (decoded is Map) {
            String mainCat = decoded['main'] ?? 'General';
            List<String> subs = List<String>.from(decoded['subs'] ?? []);
            loadedMap[mainCat] = subs;
          }
        } catch (_) {
          loadedMap[catStr] = [];
        }
      }
    } else {
      loadedMap = {
        'Accessories': ['Chargers', 'Cables', 'Power Banks', 'Neckbands'],
        'Spare Parts': ['Batteries', 'Displays', 'Touch Glass'],
      };
    }

    setState(() {
      _productCategoriesMap = loadedMap;
      _isLoading = false;
    });
  }

  Future<void> _saveCategoriesToDb() async {
    List<String> encodedCategories = _productCategoriesMap.entries.map((entry) {
      return jsonEncode({'main': entry.key, 'subs': entry.value});
    }).toList();

    final existing = await DatabaseHelper.isar.companySettings.where().findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existing != null) {
        existing.productCategories = encodedCategories;
        await DatabaseHelper.isar.companySettings.put(existing);
      } else {
        final newSettings = CompanySettings()
          ..businessName = 'ORLIFE'
          ..productCategories = encodedCategories;
        await DatabaseHelper.isar.companySettings.put(newSettings);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Categories Updated Successfully!'), backgroundColor: Colors.green),
    );
  }

  void _showAddCategoryDialog() {
    String? selectedExistingMain = _productCategoriesMap.keys.isNotEmpty ? _productCategoriesMap.keys.first : null;
    bool isCreatingNewMain = false;
    
    final newMainController = TextEditingController();
    final subController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Category & Sub-Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCreatingNewMain ? 'Create New Main Category' : 'Select Main Category',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            isCreatingNewMain = !isCreatingNewMain;
                          });
                        },
                        child: Text(isCreatingNewMain ? 'Use Existing' : '+ New Main', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isCreatingNewMain)
                    TextField(
                      controller: newMainController,
                      decoration: const InputDecoration(
                        labelText: 'New Main Category e.g. Accessories',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedExistingMain,
                      items: _productCategoriesMap.keys.map((main) => DropdownMenuItem(value: main, child: Text(main))).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedExistingMain = val;
                        });
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subController,
                    decoration: const InputDecoration(
                      labelText: 'Sub-Category Name e.g. Chargers',
                      hintText: 'e.g. Cables, Batteries',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  String mainCategory = isCreatingNewMain ? newMainController.text.trim() : (selectedExistingMain ?? '');
                  String subCategory = subController.text.trim();

                  if (mainCategory.isNotEmpty) {
                    setState(() {
                      if (!_productCategoriesMap.containsKey(mainCategory)) {
                        _productCategoriesMap[mainCategory] = [];
                      }
                      if (subCategory.isNotEmpty && !_productCategoriesMap[mainCategory]!.contains(subCategory)) {
                        _productCategoriesMap[mainCategory]!.add(subCategory);
                      }
                    });
                    _saveCategoriesToDb();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSubCategoryDialog(String mainCategory) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Sub-Category to "$mainCategory"'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Sub-Category e.g. Chargers', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              String subName = controller.text.trim();
              if (subName.isNotEmpty) {
                setState(() {
                  if (_productCategoriesMap[mainCategory] == null) {
                    _productCategoriesMap[mainCategory] = [];
                  }
                  if (!_productCategoriesMap[mainCategory]!.contains(subName)) {
                    _productCategoriesMap[mainCategory]!.add(subName);
                  }
                });
                _saveCategoriesToDb();
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Product Categories & Sub-Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Category', style: TextStyle(fontSize: 11)),
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _productCategoriesMap.isEmpty
                        ? const Center(child: Text('Koi category add nahi ki gayi hai.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _productCategoriesMap.keys.length,
                            itemBuilder: (context, index) {
                              String mainCat = _productCategoriesMap.keys.elementAt(index);
                              List<String> subCats = _productCategoriesMap[mainCat] ?? [];

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(mainCat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton.icon(
                                                style: TextButton.styleFrom(foregroundColor: Colors.teal, visualDensity: VisualDensity.compact),
                                                icon: const Icon(Icons.add, size: 14),
                                                label: const Text('Add Sub', style: TextStyle(fontSize: 11)),
                                                onPressed: () => _showSubCategoryDialog(mainCat),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                                onPressed: () {
                                                  setState(() => _productCategoriesMap.remove(mainCat));
                                                  _saveCategoriesToDb();
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 8),
                                      subCats.isEmpty
                                          ? const Padding(
                                              padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                                              child: Text('No sub-categories added yet.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            )
                                          : Wrap(
                                              spacing: 4,
                                              runSpacing: 2,
                                              children: List.generate(subCats.length, (subIndex) {
                                                return Chip(
                                                  label: Text(subCats[subIndex], style: const TextStyle(fontSize: 11)),
                                                  backgroundColor: Colors.teal.shade50,
                                                  deleteIcon: const Icon(Icons.close, size: 12),
                                                  onDeleted: () {
                                                    setState(() {
                                                      _productCategoriesMap[mainCat]!.removeAt(subIndex);
                                                    });
                                                    _saveCategoriesToDb();
                                                  },
                                                );
                                              }),
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
            ),
    );
  }
}
