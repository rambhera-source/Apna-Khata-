import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/account.dart';
import 'searchable_field.dart';

class PurchaseRowItem {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0');
  InventoryItem? selectedProduct;
  
  double get totalAmount {
    double q = double.tryParse(qtyController.text) ?? 0;
    double r = double.tryParse(rateController.text) ?? 0;
    return q * r;
  }

  void dispose() {
    searchController.dispose();
    qtyController.dispose();
    rateController.dispose();
  }
}

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final TextEditingController _partyController = TextEditingController();
  
  final List<PurchaseRowItem> _rows = [];
  List<String> _allProductNames = [];
  List<InventoryItem> _allProducts = [];
  List<String> _allParties = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _addNewRow();
  }

  Future<void> _loadData() async {
    _allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _allProductNames = _allProducts.map((p) => p.itemName).toList();

    final parties = await DatabaseHelper.isar.accounts.where().findAll();
    _allParties = parties.map((a) => a.name).toList();
    setState(() {});
  }

  void _addNewRow() {
    setState(() {
      _rows.add(PurchaseRowItem());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
      if (_rows.isEmpty) {
        _addNewRow();
      }
    });
  }

  double get _grandTotal {
    double total = 0;
    for (var row in _rows) {
      total += row.totalAmount;
    }
    return total;
  }

  Future<void> _showPurchaseHistoryPopup(InventoryItem product) async {
    String partyName = _partyController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase History: ${product.itemName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partyName.isNotEmpty ? 'Supplier: $partyName' : 'All Suppliers History', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Purchase Bill #PUR-501'),
                subtitle: const Text('Date: 2026-09-02\nQty: 100 pcs | Rate: ₹110.0'),
                trailing: const Icon(Icons.open_in_new, color: Colors.blue),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Purchase Bill #PUR-501...')),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePurchaseBill() async {
    if (_partyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Supplier (Party Name) select karein!')),
      );
      return;
    }

    bool hasValidItem = false;
    for (var row in _rows) {
      if (row.selectedProduct != null && row.totalAmount > 0) {
        hasValidItem = true;
        break;
      }
    }

    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam se kam ek valid product select karein!')),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var row in _rows) {
        if (row.selectedProduct != null) {
          double purchasedQty = double.tryParse(row.qtyController.text) ?? 0;
          InventoryItem product = row.selectedProduct!;
          product.stockQuantity += purchasedQty;
          double newRate = double.tryParse(row.rateController.text) ?? product.priceA;
          if (newRate > 0) product.priceA = newRate;
          await DatabaseHelper.isar.inventoryItems.put(product);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase Bill Successfully Saved & Stock Updated!')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _partyController.dispose();
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Bill Entry'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SearchableField(
                  label: 'Select Supplier (Party Name) *',
                  items: _allParties,
                  controller: _partyController,
                  onSelected: (selected) {
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.blue.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Item Name & History', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SearchableField(
                                  label: 'Item ${index + 1}',
                                  items: _allProductNames,
                                  controller: row.searchController,
                                  onSelected: (selectedItemName) {
                                    final match = _allProducts.firstWhere(
                                      (p) => p.itemName.toLowerCase() == selectedItemName.toLowerCase(),
                                      orElse: () => InventoryItem(),
                                    );
                                    setState(() {
                                      row.selectedProduct = match.id != 0 ? match : null;
                                      if (row.selectedProduct != null) {
                                        row.rateController.text = row.selectedProduct!.priceA.toString();
                                      }
                                    });
                                    if (index == _rows.length - 1) {
                                      _addNewRow();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: row.qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12)),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: row.rateController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12)),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    '₹${row.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _removeRow(index),
                              ),
                            ],
                          ),
                          if (row.selectedProduct != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 25),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.history, size: 14, color: Colors.blue),
                                  label: const Text('View Last Purchase Rate & Bill History', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                  onPressed: () => _showPurchaseHistoryPopup(row.selectedProduct!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: _savePurchaseBill,
                    child: const Text('Save Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
