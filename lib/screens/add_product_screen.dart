import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import 'product_history_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // 📝 Controllers for Adding Single Product
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController(text: 'Pcs');
  final _priceAController = TextEditingController(); // Purchase / Tier A price
  
  String _selectedStockType = 'Fresh'; // 'Fresh' ya 'Replacement'

  // 🔍 Filters for Inventory List
  String _searchQuery = '';
  final Set<String> _selectedCategories = {};
  String _stockTypeFilter = 'All';

  // 💾 Save Single Product to Isar Database
  Future<void> _saveProduct() async {
    if (_nameController.text.trim().isEmpty || _skuController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product Name aur SKU bharna zaroori hai!')),
      );
      return;
    }

    final newItem = InventoryItem()
      ..itemName = _nameController.text.trim()
      ..sku = _skuController.text.trim()
      ..category = _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim()
      ..stockQuantity = double.tryParse(_stockController.text) ?? 0.0
      ..unit = _unitController.text.trim()
      ..priceA = double.tryParse(_priceAController.text) ?? 0.0
      ..stockType = _selectedStockType;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.inventoryItems.put(newItem);
    });

    // Clear form fields after save
    _nameController.clear();
    _skuController.clear();
    _categoryController.clear();
    _stockController.clear();
    _priceAController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product successfully add ho gaya!')),
    );
    FocusScope.of(context).unfocus();
  }

  // Database se saari unique categories nikalne ke liye
  Future<List<String>> _fetchAllCategories() async {
    final allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    Set<String> categories = allProducts.map((p) => p.category).toSet();
    return categories.toList();
  }

  // 📋 Multi-Select Category Dialog
  void _showCategoryMultiSelectDialog(List<String> allCategories) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Product Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: allCategories.isEmpty
                    ? const Text('Koi category available nahi hai.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          String category = allCategories[index];
                          bool isSelected = _selectedCategories.contains(category);
                          return CheckboxListTile(
                            title: Text(category),
                            value: isSelected,
                            activeColor: Colors.teal,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _selectedCategories.clear());
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📊 Open Product Transaction History
  Future<void> _openProductHistory(InventoryItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductHistoryScreen(product: item)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Tab 1: Add Single Product, Tab 2: Inventory List & Filters
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory & Product Management'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.add_box), text: 'Add Single Product'),
              Tab(icon: Icon(Icons.inventory), text: 'Inventory List & Filter'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= TABA 1: ADD SINGLE PRODUCT =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Naya Product Add Karein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU Code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category (e.g., Chargers)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _unitController,
                          decoration: const InputDecoration(labelText: 'Unit (Pcs/Box)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceAController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase / Default Price (₹)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  // Stock Type Selection (Fresh vs Replacement)
                  Row(
                    children: [
                      const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Fresh'),
                        selected: _selectedStockType == 'Fresh',
                        selectedColor: Colors.green.shade100,
                        onSelected: (selected) => setState(() => _selectedStockType = 'Fresh'),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Replacement'),
                        selected: _selectedStockType == 'Replacement',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (selected) => setState(() => _selectedStockType = 'Replacement'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Product', style: TextStyle(fontSize: 16)),
                    onPressed: _saveProduct,
                  ),
                ],
              ),
            ),

            // ================= TAB 2: INVENTORY LIST & FILTERS =================
            Column(
              children: [
                // 🔍 Search Bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Product Name or SKU...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, color: Colors.teal),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.trim()),
                  ),
                ),

                // 📂 Multi-Category Dropdown Filter Button
                FutureBuilder<List<String>>(
                  future: _fetchAllCategories(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: InkWell(
                        onTap: () => _showCategoryMultiSelectDialog(categories),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedCategories.isEmpty
                                      ? 'Filter by Category: All Categories Selected (Tap)'
                                      : 'Selected Categories: ${_selectedCategories.join(', ')}',
                                  style: TextStyle(
                                    color: _selectedCategories.isEmpty ? Colors.grey.shade700 : Colors.teal.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.teal),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 🎛️ Fresh vs Replacement Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _stockTypeFilter == 'All',
                        selectedColor: Colors.teal.shade100,
                        onSelected: (selected) => setState(() => _stockTypeFilter = 'All'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Fresh'),
                        selected: _stockTypeFilter == 'Fresh',
                        selectedColor: Colors.green.shade100,
                        onSelected: (selected) => setState(() => _stockTypeFilter = 'Fresh'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Replacement'),
                        selected: _stockTypeFilter == 'Replacement',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (selected) => setState(() => _stockTypeFilter = 'Replacement'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 10),

                // 📦 Product List View with History & Edit
                Expanded(
                  child: StreamBuilder<List<InventoryItem>>(
                    stream: DatabaseHelper.isar.inventoryItems.watch(fireImmediately: true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('Koi product nahi mila! Tab 1 se naya product add karein.', style: TextStyle(color: Colors.grey)),
                        );
                      }

                      var products = snapshot.data!.where((item) {
                        bool matchesSearch = _searchQuery.isEmpty ||
                            item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            item.sku.toLowerCase().contains(_searchQuery.toLowerCase());

                        bool matchesCategory = _selectedCategories.isEmpty ||
                            _selectedCategories.contains(item.category);

                        String itemStockType = item.stockType.isEmpty ? 'Fresh' : item.stockType;
                        bool matchesStockType = _stockTypeFilter == 'All' ||
                            (itemStockType.toLowerCase() == _stockTypeFilter.toLowerCase());

                        return matchesSearch && matchesCategory && matchesStockType;
                      }).toList();

                      if (products.isEmpty) {
                        return const Center(
                          child: Text('Is filter ke anusaar koi product nahi mila!', style: TextStyle(color: Colors.grey)),
                        );
                      }

                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final item = products[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _openProductHistory(item), // Click on card opens History
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: item.stockType.toLowerCase() == 'replacement' ? Colors.orange.shade100 : Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.stockType.isEmpty ? 'Fresh' : item.stockType,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: item.stockType.toLowerCase() == 'replacement' ? Colors.orange.shade900 : Colors.green.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('SKU: ${item.sku} | Category: ${item.category}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Text('Stock: ${item.stockQuantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.teal)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
