import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/bom_model.dart';
import 'searchable_field.dart';

class BomScreen extends StatefulWidget {
  const BomScreen({super.key});

  @override
  State<BomScreen> createState() => _BomScreenState();
}

class _BomScreenState extends State<BomScreen> {
  // Controllers for BOM Entry Form
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _unitController = TextEditingController(text: 'pcs');

  List<InventoryItem> _allProducts = [];
  List<String> _allProductNames = [];
  List<BillOfMaterials> _currentProductBomList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load Inventory items for Searchable fields
  Future<void> _loadData() async {
    _allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _allProductNames = _allProducts.map((p) => p.itemName).toSet().toList();
    setState(() {});
  }

  // Fetch existing BOM list when a finished product is selected or typed
  Future<void> _loadBomForSelectedProduct(String productName) async {
    if (productName.trim().isEmpty) return;
    
    _currentProductBomList = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(productName.trim())
        .findAll();
    setState(() {});
  }

  // 💾 Save or Update BOM Item
  Future<void> _saveBom() async {
    final product = _productController.text.trim();
    final material = _materialController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final unit = _unitController.text.trim();

    if (product.isEmpty || material.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Product, Raw Material aur Qty sahi se bharein!')),
      );
      return;
    }

    // CHECK: Duplicate combination check
    final existingBom = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(product)
        .and()
        .rawMaterialNameEqualTo(material)
        .findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existingBom != null) {
        existingBom.quantityRequired += qty;
        await DatabaseHelper.isar.billOfMaterials.put(existingBom);
      } else {
        final bom = BillOfMaterials()
          ..finishedProductName = product
          ..rawMaterialName = material
          ..quantityRequired = qty
          ..unit = unit;
        await DatabaseHelper.isar.billOfMaterials.put(bom);
      }
    });

    // Reset Material fields (Keep product name so user can add more raw materials easily)
    _materialController.clear();
    _qtyController.text = '1';

    // Refresh list
    await _loadBomForSelectedProduct(product);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BOM Recipe Updated Successfully!')),
    );
  }

  // 🗑️ Delete a raw material row from BOM
  Future<void> _deleteBomItem(int id, String productName) async {
    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.billOfMaterials.delete(id);
    });
    await _loadBomForSelectedProduct(productName);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BOM Item Removed!')),
    );
  }

  // 🧮 Calculate total base cost per single piece of finished product from inventory rates
  double get _totalEstimatedCostPerPiece {
    double totalCost = 0;
    for (var bom in _currentProductBomList) {
      InventoryItem? rawItem = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..priceA = 0.0,
      );
      totalCost += bom.quantityRequired * rawItem.priceA;
    }
    return totalCost;
  }

  @override
  void dispose() {
    _productController.dispose();
    _materialController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM (Bill of Materials / Recipe) Builder'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Finished Product Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: SearchableField(
                  label: 'Select / Type Finished Product Name *',
                  items: _allProductNames,
                  controller: _productController,
                  onSelected: (selectedName) {
                    _loadBomForSelectedProduct(selectedName);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Raw Material Addition Form with Search
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    SearchableField(
                      label: 'Select Raw Material / Component *',
                      items: _allProductNames,
                      controller: _materialController,
                      onSelected: (selectedMaterial) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty Required *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _unitController,
                            decoration: const InputDecoration(
                              labelText: 'Unit (pcs/box/mtr)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ).wrap(
                            ElevatedButton(
                              onPressed: _saveBom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Recipe List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Text(
                  'Current Recipe Components:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                ),
                Text(
                  'Est. Cost/Piece: ₹ ${_totalEstimatedCostPerPiece.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Recipe Items ListView
            Expanded(
              child: _currentProductBomList.isEmpty
                  ? const Center(
                      child: Text(
                        'Kripya upar finished product select karke raw materials add karein.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currentProductBomList.length,
                      itemBuilder: (context, index) {
                        const bom = _currentProductBomList[index];
                        
                        // Find rate from inventory
                        InventoryItem? rawItem = _allProducts.firstWhere(
                          (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
                          orElse: () => InventoryItem()..priceA = 0.0,
                        );
                        double lineCost = bom.quantityRequired * rawItem.priceA;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: ListTile(
                            dense: true,
                            title: Text(bom.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Required: ${bom.quantityRequired} ${bom.unit} | Unit Rate: ₹${rawItem.priceA}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${lineCost.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                  onPressed: () => _deleteBomItem(bom.id, bom.finishedProductName),
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
