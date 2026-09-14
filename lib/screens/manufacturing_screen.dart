import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/bom_model.dart';
import 'searchable_field.dart';

class ManufacturingScreen extends StatefulWidget {
  const ManufacturingScreen({super.key});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing & Production Dashboard'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.precision_manufacturing), text: '1. Production Entry'),
            Tab(icon: Icon(Icons.receipt_long), text: '2. BOM Recipe Builder'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProductionTab(),
          BomTab(),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: PRODUCTION ENTRY TAB
// ==========================================
class ProductionTab extends StatefulWidget {
  const ProductionTab({super.key});

  @override
  State<ProductionTab> createState() => _ProductionTabState();
}

class _ProductionTabState extends State<ProductionTab> {
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _extraExpenseController = TextEditingController(text: '0');
  
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
    setState(() { _isLoadingBOM = true; });
    _currentBOMList = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(productName)
        .findAll();
    setState(() { _isLoadingBOM = false; });
  }

  double get _totalMaterialCost {
    double productionQty = double.tryParse(_qtyController.text) ?? 1.0;
    double materialCostSum = 0;
    for (var bom in _currentBOMList) {
      InventoryItem? rawMaterial = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..priceA = 0.0,
      );
      materialCostSum += (bom.quantity * productionQty) * rawMaterial.priceA;
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

  Future<void> _confirmProduction() async {
    String finishedProduct = _productController.text.trim();
    double productionQty = double.tryParse(_qtyController.text) ?? 0.0;

    if (finishedProduct.isEmpty || productionQty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Product aur valid Quantity enter karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_currentBOMList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is product ka koi BOM (Recipe) nahi mila! Pehle Tab 2 mein BOM set karein.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Stock sufficiency check
    for (var bomItem in _currentBOMList) {
      double requiredTotalQty = bomItem.quantity * productionQty;
      InventoryItem? rawMaterial = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..stockQuantity = -1,
      );

      if (rawMaterial.stockQuantity == -1 || rawMaterial.stockQuantity < requiredTotalQty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock Kam Hai! "${bomItem.rawMaterialName}" ka stock insufficient hai.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    double finalUnitCost = _costPerPiece;

    await DatabaseHelper.isar.writeTxn(() async {
      for (var bomItem in _currentBOMList) {
        double requiredTotalQty = bomItem.quantity * productionQty;
        InventoryItem rawMaterial = _allProducts.firstWhere(
          (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        );
        rawMaterial.stockQuantity -= requiredTotalQty;
        if (rawMaterial.stockQuantity < 0) rawMaterial.stockQuantity = 0;
        await DatabaseHelper.isar.inventoryItems.put(rawMaterial);
      }

      InventoryItem? finishedItem = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == finishedProduct.toLowerCase(),
        orElse: () => InventoryItem(),
      );

      if (finishedItem.id != 0) {
        finishedItem.stockQuantity += productionQty;
        finishedItem.priceA = finalUnitCost;
        await DatabaseHelper.isar.inventoryItems.put(finishedItem);
      } else {
        final newItem = InventoryItem()
          ..itemName = finishedProduct
          ..stockQuantity = productionQty
          ..priceA = finalUnitCost;
        await DatabaseHelper.isar.inventoryItems.put(newItem);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Production Successful! Cost per piece: ₹${finalUnitCost.toStringAsFixed(2)}'), backgroundColor: Colors.green),
    );

    _productController.clear();
    _qtyController.text = '1';
    _extraExpenseController.text = '0';
    setState(() { _currentBOMList.clear(); });
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
    return Padding(
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
          const Text('BOM Recipe Breakdown & Material Cost:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
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
                          double totalNeeded = bom.quantity * productionQty;
                          
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
                              trailing: Text('₹${lineCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                            ),
                          );
                        },
                      ),
          ),
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
    );
  }
}

// ==========================================
// TAB 2: BOM RECIPE BUILDER TAB
// ==========================================
class BomTab extends StatefulWidget {
  const BomTab({super.key});

  @override
  State<BomTab> createState() => _BomTabState();
}

class _BomTabState extends State<BomTab> {
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

  Future<void> _loadData() async {
    _allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _allProductNames = _allProducts.map((p) => p.itemName).toSet().toList();
    setState(() {});
  }

  Future<void> _loadBomForSelectedProduct(String productName) async {
    if (productName.trim().isEmpty) return;
    _currentProductBomList = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(productName.trim())
        .findAll();
    setState(() {});
  }

  Future<void> _saveBom() async {
    final product = _productController.text.trim();
    final material = _materialController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final unit = _unitController.text.trim();

    if (product.isEmpty || material.isEmpty || qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Product, Raw Material aur Qty sahi se bharein!'), backgroundColor: Colors.red),
      );
      return;
    }

    final existingBom = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .finishedProductNameEqualTo(product)
        .and()
        .rawMaterialNameEqualTo(material)
        .findFirst();

    await DatabaseHelper.isar.writeTxn(() async {
      if (existingBom != null) {
        existingBom.quantity += qty;
        existingBom.unit = unit;
        await DatabaseHelper.isar.billOfMaterials.put(existingBom);
      } else {
        final bom = BillOfMaterials()
          ..finishedProductName = product
          ..rawMaterialName = material
          ..quantity = qty
          ..unit = unit;
        await DatabaseHelper.isar.billOfMaterials.put(bom);
      }
    });

    _materialController.clear();
    _qtyController.text = '1';
    _unitController.clear();
    await _loadBomForSelectedProduct(product);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BOM Recipe Updated Successfully!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _deleteBomItem(int id, String productName) async {
    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.billOfMaterials.delete(id);
    });
    await _loadBomForSelectedProduct(productName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BOM Item Removed!'), backgroundColor: Colors.orange),
    );
  }

  double get _totalEstimatedCostPerPiece {
    double totalCost = 0;
    for (var bom in _currentProductBomList) {
      InventoryItem? rawItem = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..priceA = 0.0,
      );
      totalCost += bom.quantity * rawItem.priceA;
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                            labelText: 'Unit (pcs/box)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveBom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Recipe Components:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
              Text('Est. Cost/Piece: ₹ ${_totalEstimatedCostPerPiece.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _currentProductBomList.isEmpty
                ? const Center(child: Text('Kripya upar finished product select karke raw materials add karein.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _currentProductBomList.length,
                    itemBuilder: (context, index) {
                      final bom = _currentProductBomList[index];
                      InventoryItem? rawItem = _allProducts.firstWhere(
                        (p) => p.itemName.toLowerCase() == bom.rawMaterialName.toLowerCase(),
                        orElse: () => InventoryItem()..priceA = 0.0,
                      );
                      double lineCost = bom.quantity * rawItem.priceA;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          title: Text(bom.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Required: ${bom.quantity} ${bom.unit} | Unit Rate: ₹${rawItem.priceA}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${lineCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
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
    );
  }
}
