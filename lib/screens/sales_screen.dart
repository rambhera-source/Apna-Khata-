import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/account.dart';
import 'searchable_field.dart'; // Aapka reusable searchable field widget

class SalesRowItem {
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

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _partyController = TextEditingController();
  Account? _selectedParty;
  
  // List of active rows for continuous billing
  final List<SalesRowItem> _rows = [];
  List<String> _allProductNames = [];
  List<InventoryItem> _allProducts = [];
  List<String> _allParties = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Start with one empty row
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
      _rows.add(SalesRowItem());
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
        title: const Text('Sales Invoice Entry'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Party Selection Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SearchableField(
                  label: 'Select Customer (Party Name) *',
                  items: _allParties,
                  controller: _partyController,
                  onSelected: (selected) {
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.teal.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 40),
                ],
              ),
            ),

            // Continuous Rows List
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        // 1. Searchable Product Field
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
                              // Automatically add a new row if this is the last row and item is selected
                              if (index == _rows.length - 1) {
                                _addNewRow();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // 2. Quantity Field
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

                        // 3. Rate / Price Field
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

                        // 4. Line Total Amount
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              '₹${row.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),

                        // 5. Delete Row Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removeRow(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer & Grand Total
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total: ₹ ${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sales Bill Successfully Saved!')),
                      );
                    },
                    child: const Text('Save Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
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
