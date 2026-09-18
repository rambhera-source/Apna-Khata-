import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';
import 'add_product_screen.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _allInventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  
  String _selectedStockFilter = 'Fresh'; 
  final Set<String> _selectedCategories = {}; 
  bool _isStockAscending = true; 

  DateTime? _startDate;
  DateTime? _endDate;

  final Set<int> _selectedItemIds = {};
  bool _isSelectAll = false;

  final List<String> _priceCategories = List.generate(26, (index) => String.fromCharCode(65 + index));

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    _allInventoryItems = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _filterItems(_searchController.text);
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _allInventoryItems.where((item) {
        bool matchesQuery = item.itemName.toLowerCase().contains(query.toLowerCase()) ||
                            (item.sku != null && item.sku!.toLowerCase().contains(query.toLowerCase()));
        
        bool matchesStockType = true;
        if (_selectedStockFilter == 'Fresh') {
          matchesStockType = item.stockType == 'Fresh' || item.stockType == null || item.stockType!.isEmpty;
        } else if (_selectedStockFilter == 'Replacement') {
          matchesStockType = item.stockType == 'Replacement';
        }

        bool matchesCategory = true;
        if (_selectedCategories.isNotEmpty && !_selectedCategories.contains('All')) {
          matchesCategory = _selectedCategories.contains(item.category ?? 'General');
        }

        return matchesQuery && matchesStockType && matchesCategory;
      }).toList();

      _filteredItems.sort((a, b) {
        if (_isStockAscending) {
          return a.stockQuantity.compareTo(b.stockQuantity);
        } else {
          return b.stockQuantity.compareTo(a.stockQuantity);
        }
      });
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterItems(_searchController.text);
      });
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isSelectAll = value ?? false;
      if (_isSelectAll) {
        _selectedItemIds.clear();
        for (var item in _filteredItems) {
          _selectedItemIds.add(item.id);
        }
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  void _confirmBulkDelete() async {
    if (_selectedItemIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Products?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Delete ${_selectedItemIds.length} selected products?', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.isar.writeTxn(() async {
                for (int id in _selectedItemIds) {
                  await DatabaseHelper.isar.inventoryItems.delete(id);
                }
              });
              _selectedItemIds.clear();
              _loadInventory();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selected products deleted successfully!'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(InventoryItem item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Product?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Delete "${item.itemName}"?', style: const TextStyle(fontSize: 13)),
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
                await DatabaseHelper.isar.inventoryItems.delete(item.id);
              });
              _loadInventory();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory Management', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedItemIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Delete Selected',
              onPressed: _confirmBulkDelete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Search Product Name or SKU...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: _filterItems,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      value: _selectedStockFilter,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Stock', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'Fresh', child: Text('Fresh Stock', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'Replacement', child: Text('Replacement', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedStockFilter = val!;
                          _filterItems(_searchController.text);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.date_range, color: Colors.teal),
                  tooltip: 'Date Filter',
                  onPressed: _selectDateRange,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Checkbox(
                    value: _isSelectAll,
                    activeColor: Colors.teal,
                    visualDensity: VisualDensity.compact,
                    onChanged: _toggleSelectAll,
                  ),
                  const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                  const Spacer(),
                  Text('Total Items: ${_filteredItems.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No inventory items found.', style: TextStyle(color: Colors.grey, fontSize: 13)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        bool isSelected = _selectedItemIds.contains(item.id);

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddProductScreen(itemToEdit: item),
                                ),
                              );
                              _loadInventory();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.teal,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItemIds.add(item.id);
                                        } else {
                                          _selectedItemIds.remove(item.id);
                                          _isSelectAll = false;
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                        ),
                                        Text(
                                          'SKU: ${item.sku ?? "-"}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.category ?? "General",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '${item.stockQuantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                    tooltip: 'Delete Product',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () => _confirmDelete(item),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
          _loadInventory();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
