import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _allInventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  String _selectedStockFilter = 'All'; // 'All', 'Fresh', 'Replacement'

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

        return matchesQuery && matchesStockType;
      }).toList();
    });
  }

  // ➕ Add or Edit Product Dialog (Fixed Save & Added Category & Price Category)
  void _showAddEditProductDialog({InventoryItem? itemToEdit}) {
    final TextEditingController nameController = TextEditingController(text: itemToEdit?.itemName ?? '');
    final TextEditingController skuController = TextEditingController(text: itemToEdit?.sku ?? '');
    final TextEditingController categoryController = TextEditingController(text: itemToEdit?.category ?? '');
    final TextEditingController qtyController = TextEditingController(text: itemToEdit?.stockQuantity.toString() ?? '0');
    final TextEditingController priceController = TextEditingController(text: itemToEdit?.priceA.toString() ?? '0');
    
    String stockType = itemToEdit?.stockType ?? 'Fresh';
    String priceCategory = itemToEdit?.priceCategory ?? 'A';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(itemToEdit == null ? 'Add New Inventory Item' : 'Edit Item Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU / Model Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category (e.g. Charger, Battery)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock Qty *', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (₹) *', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Price Category (A to Z) Dropdown
                DropdownButtonFormField<String>(
                  value: _priceCategories.contains(priceCategory) ? priceCategory : 'A',
                  items: _priceCategories.map((cat) => DropdownMenuItem(value: cat, child: Text('Price Tier $cat'))).toList(),
                  onChanged: (val) => setDialogState(() => priceCategory = val!),
                  decoration: const InputDecoration(labelText: 'Price Category (A - Z)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Stock Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Fresh'),
                      selected: stockType == 'Fresh',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) => setDialogState(() => stockType = 'Fresh'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Replacement'),
                      selected: stockType == 'Replacement',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (val) => setDialogState(() => stockType = 'Replacement'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                String name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kripya Item ka Naam bharein!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                await DatabaseHelper.isar.writeTxn(() async {
                  InventoryItem item = itemToEdit ?? InventoryItem();
                  item.itemName = name;
                  item.sku = skuController.text.trim();
                  item.category = categoryController.text.trim();
                  item.stockQuantity = double.tryParse(qtyController.text) ?? 0.0;
                  item.priceA = double.tryParse(priceController.text) ?? 0.0;
                  item.stockType = stockType;
                  item.priceCategory = priceCategory;

                  await DatabaseHelper.isar.inventoryItems.put(item);
                });

                if (!mounted) return;
                Navigator.pop(context);
                _loadInventory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventory Successfully Saved!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // 📦 Bulk Entry Dialog Feature
  void _showBulkEntryDialog() {
    final List<Map<String, dynamic>> bulkRows = [
      {'name': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController(text: '0'), 'category': TextEditingController()}
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Product Entry'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ek sath kai products add karein:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bulkRows.length,
                    itemBuilder: (context, index) {
                      final row = bulkRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row['name'],
                                decoration: InputDecoration(labelText: 'Item ${index + 1} Name', border: const OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: row['qty'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: row['price'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  bulkRows.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Row'),
                    onPressed: () {
                      setDialogState(() {
                        bulkRows.add({
                          'name': TextEditingController(),
                          'qty': TextEditingController(text: '1'),
                          'price': TextEditingController(text: '0'),
                          'category': TextEditingController()
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                await DatabaseHelper.isar.writeTxn(() async {
                  for (var row in bulkRows) {
                    String name = (row['name'] as TextEditingController).text.trim();
                    if (name.isNotEmpty) {
                      InventoryItem item = InventoryItem()
                        ..itemName = name
                        ..stockQuantity = double.tryParse((row['qty'] as TextEditingController).text) ?? 0.0
                        ..priceA = double.tryParse((row['price'] as TextEditingController).text) ?? 0.0
                        ..stockType = 'Fresh'
                        ..priceCategory = 'A';
                      await DatabaseHelper.isar.inventoryItems.put(item);
                    }
                  }
                });

                if (!mounted) return;
                Navigator.pop(context);
                _loadInventory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bulk Inventory Successfully Saved!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save All'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _showBulkEntryDialog,
            tooltip: 'Bulk Entry',
          ),
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => _showAddEditProductDialog(),
            tooltip: 'Add New Product',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search Bar & Filter Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Product or SKU...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    onChanged: _filterItems,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStockFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Stock')),
                      DropdownMenuItem(value: 'Fresh', child: Text('Fresh Stock')),
                      DropdownMenuItem(value: 'Replacement', child: Text('Replacement')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStockFilter = val!;
                        _filterItems(_searchController.text);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Inventory List Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Item Name / Category / SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
            ),

            // Inventory Items List
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No inventory items found.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        bool isReplacement = item.stockType == 'Replacement';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                 flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          if (item.category != null && item.category!.isNotEmpty)
                                            Text('${item.category} | ', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                          if (item.sku != null && item.sku!.isNotEmpty)
                                            Text('SKU: ${item.sku} | ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isReplacement ? Colors.orange.shade100 : Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isReplacement ? 'Replacement' : 'Fresh',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isReplacement ? Colors.orange.shade800 : Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${item.stockQuantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '₹${item.priceA.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                        onPressed: () => _showAddEditProductDialog(itemToEdit: item),
                                        tooltip: 'Edit Item',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () async {
                                          await DatabaseHelper.isar.writeTxn(() async {
                                            await DatabaseHelper.isar.inventoryItems.delete(item.id);
                                          });
                                          _loadInventory();
                                        },
                                        tooltip: 'Delete Item',
                                      ),
                                    ],
                                  ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
