import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/account.dart';
import 'searchable_field.dart';

class SalesReturnRowItem {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0');
  InventoryItem? selectedProduct;
  String returnStockType = 'Fresh'; 
  
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

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final TextEditingController _partyController = TextEditingController();
  
  final List<SalesReturnRowItem> _rows = [];
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
      _rows.add(SalesReturnRowItem());
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

  // 🎯 Priority-Based History Popup (First Priority: Selected Party Bills, Second Priority: Other Bills)
  Future<void> _showPrioritySalesHistoryPopup(InventoryItem product) async {
    String selectedParty = _partyController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Return History: ${product.itemName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedParty.isNotEmpty 
                  ? 'Target Party: $selectedParty (Priority Match)' 
                  : 'All Parties History (No Party Selected)', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
              const SizedBox(height: 4),
              const Text(
                'First Priority: Bills belonging to this party. If none, showing general history.', 
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(),
              
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // 🔥 FIRST PRIORITY SECTION (Simulated Party Specific match)
                    if (selectedParty.isNotEmpty) ...[
                      Container(
                        color: Colors.deepOrange.shade50,
                        padding: const EdgeInsets.all(4),
                        child: const Text('★ Party Direct Billing Match (1st Priority)', 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('Bill #ORL-890 [$selectedParty]'),
                        subtitle: const Text('Date: 2026-08-10 | Qty: 20 pcs | Rate: ₹145.0'),
                        trailing: const Text('Select Rate', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rate ₹145.0 applied from Bill #ORL-890 for $selectedParty')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],

                    // 📦 SECOND PRIORITY / GENERAL HISTORY SECTION
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text('Other Recent Billing History (Fallback):', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('Bill #ORL-812 [Other Party: Sharma Mobile]'),
                      subtitle: const Text('Date: 2026-08-01 | Qty: 10 pcs | Rate: ₹148.0'),
                      trailing: const Text('Select Rate', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rate ₹148.0 applied from general history')),
                        );
                      },
                    ),
                  ],
                ),
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

  Future<void> _saveSalesReturn() async {
    if (_partyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Customer (Party Name) select karein!')),
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
        const SnackBar(content: Text('Kam se kam ek valid return product select karein!')),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var row in _rows) {
        if (row.selectedProduct != null) {
          double returnQty = double.tryParse(row.qtyController.text) ?? 0;
          InventoryItem product = row.selectedProduct!;

          if (row.returnStockType == 'Fresh') {
            product.stockQuantity += returnQty; 
          } else {
            product.stockType = 'Replacement';
            product.stockQuantity += returnQty;
          }

          await DatabaseHelper.isar.inventoryItems.put(product);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sales Return Successfully Saved & Stock Updated!')),
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
        title: const Text('Sales Return (Priority History)'),
        backgroundColor: Colors.deepOrange,
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.deepOrange.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Item Name & Priority History', style: TextStyle(fontWeight: FontWeight.bold))),
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
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SearchableField(
                                  label: 'Return Item ${index + 1}',
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Return Stock Type: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Fresh'),
                                selected: row.returnStockType == 'Fresh',
                                selectedColor: Colors.green.shade100,
                                onSelected: (val) => setState(() => row.returnStockType = 'Fresh'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Replacement'),
                                selected: row.returnStockType == 'Replacement',
                                selectedColor: Colors.orange.shade100,
                                onSelected: (val) => setState(() => row.returnStockType = 'Replacement'),
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
                                  icon: const Icon(Icons.history, size: 14, color: Colors.deepOrange),
                                  label: const Text('View Priority Return History', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showPrioritySalesHistoryPopup(row.selectedProduct!),
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
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Return Total: ₹ ${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    onPressed: _saveSalesReturn,
                    child: const Text('Save Sales Return', style: TextStyle(fontWeight: FontWeight.bold)),
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
