import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/bom_model.dart';
import 'searchable_field.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _extraExpenseController = TextEditingController(text: '0'); // Labor / Extra Cost
  
  List<String> _finishedProductNames = [];
  List<InventoryItem> _allProducts = [];
  List<BillOfMaterials> _currentBOMList = [];
  bool _isLoadingBOM = false;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    _allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _finishedProductNames = _allProducts.map((p) => p.itemName).toSet().toList();
    setState(() {});
  }

  Future<void> _fetchBOMForProduct(String productName) async {
    setState(() {
      _isLoadingBOM = true;
    });

    _currentBOMList = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(productName)
        .findAll();

    setState(() {
      _isLoadingBOM = false;
    });
  }

  // 🧮 Calculate Total Material Cost for Production Batch
  double get _totalMaterialCost {
    double productionQty = double.tryParse(_qtyController.text) ?? 1.0;
    double materialCostSum = 0;

    for (var bom in _currentBOMList) {
      // Inventory se raw material ka current rate nikalein
      InventoryItem? rawMaterial = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..priceA = 0.0,
      );
      double unitRate = rawMaterial.priceA; // Material ka purchase/unit rate
      materialCostSum += (bom.quantityRequired * productionQty) * unitRate;
    }
    return materialCostSum;
  }

  double get _grandTotalCost {
    double extraExpense = double.tryParse(_extraExpenseController.text) ?? 0.0;
    return _totalMaterialCost + extraExpense;
  }

  double get _costPerPiece {
    double productionQty = double.tryParse(_qtyController.text) ?? 1.0;
    if (productionQty <= 0) return 0.0;
    return _grandTotalCost / productionQty;
  }

  // 🏭 Confirm Production & Save Cost Price to Inventory
  Future<void> _confirmProduction() async {
    String finishedProduct = _productController.text.trim();
    double productionQty = double.tryParse(_qtyController.text) ?? 0.0;

    if (finishedProduct.isEmpty || productionQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Product aur valid Quantity enter karein!')),
      );
      return;
    }

    if (_currentBOMList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is product ka koi BOM (Recipe) nahi mila!')),
      );
      return;
    }

    // Stock check
    for (var bomItem in _currentBOMList) {
      double requiredTotalQty = bomItem.quantityRequired * productionQty;
      InventoryItem? rawMaterial = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..stockQuantity = -1,
      );

      if (rawMaterial.stockQuantity == -1 || rawMaterial.stockQuantity < requiredTotalQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock Kam Hai! "${bomItem.rawMaterialName}" ka stock insufficient hai.')),
        );
        return;
      }
    }

    double finalUnitCost = _costPerPiece; // Yeh naya calculated Cost Price hai per piece ka

    // Database Transaction
    await DatabaseHelper.isar.writeTxn(() async {
      // 1. Deduct Raw Materials
      for (var bomItem in _currentBOMList) {
        double requiredTotalQty = bomItem.quantityRequired * productionQty;
        InventoryItem rawMaterial = _allProducts.firstWhere(
          (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        );
        rawMaterial.stockQuantity -= requiredTotalQty;
        if (rawMaterial.stockQuantity < 0) rawMaterial.stockQuantity = 0;
        await DatabaseHelper.isar.inventoryItems.put(rawMaterial);
      }

      // 2. Add Finished Product & Update Cost Price (priceA / costPrice)
      InventoryItem? finishedItem = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == finishedProduct.toLowerCase(),
        orElse: () => InventoryItem(),
      );

      if (finishedItem.id != 0) {
        finishedItem.stockQuantity += productionQty;
        finishedItem.priceA = finalUnitCost; // Latest calculated cost price update kar diya
        await DatabaseHelper.isar.inventoryItems.put(finishedItem);
      } else {
        final newItem = InventoryItem()
          ..itemName = finishedProduct
          ..stockQuantity = productionQty
          ..priceA = finalUnitCost;
        await DatabaseHelper.isar.inventoryItems.put(newItem);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Production Successful! Cost per piece: ₹${finalUnitCost.toStringAsFixed(2)}')),
    );

    _productController.clear();
    _qtyController.text = '1';
    _extraExpenseController.text = '0';
    setState(() {
      _currentBOMList.clear();
    });
    
    _loadInventoryData();
  }

  @override
  void dispose() {
    _productController.dispose();
    _qtyController.dispose();
    _extraExpenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production & Costing Entry'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    SearchableField(
                      label: 'Select Finished Product to Build *',
                      items: _finishedProductNames,
                      controller: _productController,
                      onSelected: (selectedName) {
                        _fetchBOMForProduct(selectedName);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Production Qty (Pieces) *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _extraExpenseController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Extra Expense / Labor (₹)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'BOM Recipe Breakdown & Material Cost:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: _isLoadingBOM
                  ? const Center(child: CircularProgressIndicator())
                  : _currentBOMList.isEmpty
                      ? const Center(child: Text('Kripya valid Finished Product select karein.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _currentBOMList.length,
                          itemBuilder: (context, index) {
                            final bom = _currentBOMList[index];
                            double productionQty = double.tryParse(_qtyController.text) ?? 1.0;
                            double totalNeeded = bom.quantityRequired * productionQty;
                            
                            // Get unit rate from inventory
                            InventoryItem? rawMaterial = _allProducts.firstWhere(
                              (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
                              orElse: () => InventoryItem()..priceA = 0.0,
                            );
                            double lineCost = totalNeeded * rawMaterial.priceA;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                dense: true,
                                title: Text(bom.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Req: $totalNeeded ${bom.unit} | Rate: ₹${rawMaterial.priceA}'),
                                trailing: Text(
                                  '₹${lineCost.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // 💰 Cost Summary Footer Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Material Cost Subtotal:', style: TextStyle(fontSize: 13)),
                      Text('₹ ${_totalMaterialCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total Production Cost:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('₹ ${_grandTotalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cost Price Per Piece:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('₹ ${_costPerPiece.toStringAsFixed(2)} / pc', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: _confirmProduction,
                      child: const Text('Confirm Production & Update Cost / Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
