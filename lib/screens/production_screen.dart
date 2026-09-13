import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';
import '../models/bom_model.dart'; // Aapka BOM model jahan BillOfMaterials defined hai
import 'searchable_field.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  
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
    // Saare products ki list jinka BOM ban sakta hai
    _finishedProductNames = _allProducts.map((p) => p.itemName).toSet().toList();
    setState(() {});
  }

  // Jab user finished product select kare, toh uska BOM load karo
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

  // 🏭 Confirm Production & Update Inventory (Deduct Raw Materials, Add Finished Goods)
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
        const SnackBar(content: Text('Is product ka koi BOM (Recipe) nahi mila! Pehle BOM set karein.')),
      );
      return;
    }

    // Check karein ki kya saare raw materials ka stock kaafi hai ya nahi
    for (var bomItem in _currentBOMList) {
      double requiredTotalQty = bomItem.quantityRequired * productionQty;
      
      InventoryItem? rawMaterial = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        orElse: () => InventoryItem()..stockQuantity = -1,
      );

      if (rawMaterial.stockQuantity == -1 || rawMaterial.stockQuantity < requiredTotalQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock Kam Hai! Raw Material: "${bomItem.rawMaterialName}" ka stock insufficient hai.')),
        );
        return;
      }
    }

    // Isar Database Transaction (Raw Materials Minus & Finished Product Plus)
    await DatabaseHelper.isar.writeTxn(() async {
      // 1. Raw Materials Minus karo
      for (var bomItem in _currentBOMList) {
        double requiredTotalQty = bomItem.quantityRequired * productionQty;
        
        InventoryItem rawMaterial = _allProducts.firstWhere(
          (p) => p.itemName.toLowerCase() == bomItem.rawMaterialName.toLowerCase(),
        );

        rawMaterial.stockQuantity -= requiredTotalQty;
        if (rawMaterial.stockQuantity < 0) rawMaterial.stockQuantity = 0;
        await DatabaseHelper.isar.inventoryItems.put(rawMaterial);
      }

      // 2. Finished Product Stock mein Plus karo
      InventoryItem? finishedItem = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == finishedProduct.toLowerCase(),
        orElse: () => InventoryItem(),
      );

      if (finishedItem.id != 0) {
        finishedItem.stockQuantity += productionQty;
        await DatabaseHelper.isar.inventoryItems.put(finishedItem);
      } else {
        // Agar inventory mein finished product ki pehle se entry nahi thi, toh nayi entry bana do
        final newItem = InventoryItem()
          ..itemName = finishedProduct
          ..stockQuantity = productionQty
          ..priceA = 0.0;
        await DatabaseHelper.isar.inventoryItems.put(newItem);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Production Successful! $productionQty pcs of "$finishedProduct" added to stock.')),
    );

    // Reset fields
    _productController.clear();
    _qtyController.text = '1';
    setState(() {
      _currentBOMList.clear();
    });
    
    // Refresh local product list
    _loadInventoryData();
  }

  @override
  void dispose() {
    _productController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production & Assembly Entry'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Finished Product & Quantity Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Production Quantity (Kitne piece banane hain?) *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // BOM Recipe Preview Header
            const Text(
              'Required Raw Materials (BOM Recipe Preview):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
            ),
            const SizedBox(height: 6),

            // BOM List View
            Expanded(
              child: _isLoadingBOM
                  ? const Center(child: CircularProgressIndicator())
                  : _currentBOMList.isEmpty
                      ? const Center(
                          child: Text(
                            'Kripya upar koi valid Finished Product select karein jiska BOM set ho.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _currentBOMList.length,
                          itemBuilder: (context, index) {
                            final bom = _currentBOMList[index];
                            double multiplier = double.tryParse(_qtyController.text) ?? 1.0;
                            double totalNeeded = bom.quantityRequired * multiplier;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(bom.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Per Unit Req: ${bom.quantityRequired} ${bom.unit}'),
                                trailing: Text(
                                  'Total: $totalNeeded ${bom.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Confirm Production Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ).wrap(
                ElevatedButton(
                  onPressed: _confirmProduction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Production & Update Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
