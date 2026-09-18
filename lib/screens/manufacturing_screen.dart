import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/inventory_model.dart';
import 'package:accounting_app/models/bom_model.dart';
import 'searchable_field.dart';

// ==========================================
// 1. PRODUCTION LOG MODEL FOR ISAR
// ==========================================
@collection
class ProductionLog {
  Id id = Isar.autoIncrement;
  late DateTime date;
  late String productionNumber;
  late String productName;
  late double quantity;
  late double totalCost;
  late double costPerPiece;
  String? notes;
}

class ManufacturingScreen extends StatefulWidget {
  const ManufacturingScreen({super.key});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen>
    with SingleTickerProviderStateMixin {
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
        title: const Text('Manufacturing & Production Dashboard', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.precision_manufacturing, size: 18), text: '1. Production Register'),
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: '2. BOM Master & Recipe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProductionHistoryTab(),
          BomMasterTab(),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: PRODUCTION HISTORY & NEW ENTRY
// ==========================================

class ProductionHistoryTab extends StatefulWidget {
  const ProductionHistoryTab({super.key});

  @override
  State<ProductionHistoryTab> createState() => _ProductionHistoryTabState();
}

class _ProductionHistoryTabState extends State<ProductionHistoryTab> {
  List<ProductionLog> _productionLogs = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProductionLogs();
  }

  Future<void> _loadProductionLogs() async {
    setState(() => _isLoading = true);
    var query = DatabaseHelper.isar.productionLogs.where();

    List<ProductionLog> results;
    if (_searchQuery.isNotEmpty) {
      results = await query.filter().productNameContains(_searchQuery, caseSensitive: false).sortByDateDesc().findAll();
    } else {
      results = await query.sortByDateDesc().findAll();
    }

    setState(() {
      _productionLogs = results;
      _isLoading = false;
    });
  }

  void _openNewProductionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NewProductionDialog(),
    ).then((value) {
      if (value == true) {
        _loadProductionLogs();
      }
    });
  }

  void _openEditProductionDialog(ProductionLog log) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditProductionDialog(productionLog: log),
    ).then((value) {
      if (value == true) {
        _loadProductionLogs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _loadProductionLogs();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Production'),
                    onPressed: _openNewProductionDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _productionLogs.isEmpty
                    ? const Center(child: Text('Koi production record nahi mila.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _productionLogs.length,
                        itemBuilder: (context, index) {
                          final log = _productionLogs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            child: ListTile(
                              dense: true,
                              title: Text('${log.productionNumber} - ${log.productName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Date: ${DateFormat('dd-MM-yyyy').format(log.date)} | Qty: ${log.quantity} | Cost/Pc: ₹${log.costPerPiece.toStringAsFixed(2)}'),
                              trailing: Text('₹${log.totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                              onTap: () => _openEditProductionDialog(log),
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

// ==========================================
// NEW PRODUCTION DIALOG WITH KEYBOARD FOCUS
// ==========================================

class NewProductionDialog extends StatefulWidget {
  const NewProductionDialog({super.key});

  @override
  State<NewProductionDialog> createState() => _NewProductionDialogState();
}

class _NewProductionDialogState extends State<NewProductionDialog> {
  DateTime _productionDate = DateTime.now();
  late final TextEditingController _productionNoController;
  String _selectedBomProduct = '';
  List<String> _availableBomProducts = [];
  List<BillOfMaterials> _currentBOMList = [];
  List<InventoryItem> _allProducts = [];

  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _extraExpenseController = TextEditingController(text: '0');

  // Focus Nodes
  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _bomDropdownFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _saveButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _productionNoController = TextEditingController();
    _generateNextProductionNumber();
    _loadData();
  }

  // Auto-increment Production Number starting from 1 (e.g., 001, 002...)
  Future<void> _generateNextProductionNumber() async {
    final count = await DatabaseHelper.isar.productionLogs.count();
    int nextId = count + 1;
    String formattedNo = nextId.toString().padLeft(3, '0'); // 001, 002...
    setState(() {
      _productionNoController.text = formattedNo;
    });
  }

  @override
  void dispose() {
    _productionNoController.dispose();
    _qtyController.dispose();
    _extraExpenseController.dispose();
    _dateFocusNode.dispose();
    _bomDropdownFocusNode.dispose();
    _qtyFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _allProducts = await DatabaseHelper.isar.inventoryItems.where().findAll();
    final boms = await DatabaseHelper.isar.billOfMaterials.where().findAll();
    setState(() {
      _availableBomProducts = boms.map((b) => b.productName).toSet().toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dateFocusNode);
    });
  }

  Future<void> _onBomSelected(String productName) async {
    setState(() {
      _selectedBomProduct = productName;
    });
    _currentBOMList = await DatabaseHelper.isar.billOfMaterials
        .filter()
        .productNameEqualTo(productName)
        .findAll();
    setState(() {});
  }

  double get _totalMaterialCost {
    double qty = double.tryParse(_qtyController.text) ?? 1.0;
    double sum = 0;
    for (var bom in _currentBOMList) {
      InventoryItem item = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.materialName.toLowerCase(),
        orElse: () => InventoryItem()..priceA = 0.0,
      );
      sum += (bom.quantity * qty) * item.priceA;
    }
    return sum;
  }

  double get _grandTotalCost => _totalMaterialCost + (double.tryParse(_extraExpenseController.text) ?? 0.0);
  double get _costPerPiece {
    double qty = double.tryParse(_qtyController.text) ?? 1.0;
    return qty > 0 ? _grandTotalCost / qty : 0.0;
  }

  Future<void> _saveProduction() async {
    if (_selectedBomProduct.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya BOM Recipe select karein!'), backgroundColor: Colors.red));
      return;
    }
    double qty = double.tryParse(_qtyController.text) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid Qty enter karein!'), backgroundColor: Colors.red));
      return;
    }

    for (var bom in _currentBOMList) {
      double needed = bom.quantity * qty;
      InventoryItem raw = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == bom.materialName.toLowerCase(),
        orElse: () => InventoryItem()..stockQuantity = -1,
      );
      if (raw.stockQuantity < needed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock Kam Hai: ${bom.materialName}'), backgroundColor: Colors.red));
        return;
      }
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var bom in _currentBOMList) {
        double needed = bom.quantity * qty;
        InventoryItem raw = _allProducts.firstWhere((p) => p.itemName.toLowerCase() == bom.materialName.toLowerCase());
        raw.stockQuantity -= needed;
        await DatabaseHelper.isar.inventoryItems.put(raw);
      }

      InventoryItem finished = _allProducts.firstWhere(
        (p) => p.itemName.toLowerCase() == _selectedBomProduct.toLowerCase(),
        orElse: () => InventoryItem(),
      );

      if (finished.id != 0) {
        finished.stockQuantity += qty;
        finished.priceA = _costPerPiece;
        await DatabaseHelper.isar.inventoryItems.put(finished);
      } else {
        final newFi = InventoryItem()
          ..itemName = _selectedBomProduct
          ..stockQuantity = qty
          ..priceA = _costPerPiece;
        await DatabaseHelper.isar.inventoryItems.put(newFi);
      }

      final log = ProductionLog()
        ..date = _productionDate
        ..productionNumber = _productionNoController.text
        ..productName = _selectedBomProduct
        ..quantity = qty
        ..totalCost = _grandTotalCost
        ..costPerPiece = _costPerPiece;

      await DatabaseHelper.isar.productionLogs.put(log);
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 15),
            Text('Production Saved Successfully!'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Production Entry', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Production Number (Non-Editable / Fixed starting from 001)
              TextField(
                readOnly: true,
                controller: _productionNoController,
                decoration: const InputDecoration(labelText: 'Production Number (Auto)', border: OutlineInputBorder(), isDense: true, fillColor: Colors.black12, filled: true),
              ),
              const SizedBox(height: 10),

              // Date Picker
              InkWell(
                focusNode: _dateFocusNode,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _productionDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _productionDate = picked);
                  FocusScope.of(context).requestFocus(_bomDropdownFocusNode);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Production Date', border: OutlineInputBorder(), isDense: true),
                  child: Text(DateFormat('dd-MM-yyyy').format(_productionDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),

              // BOM Recipe Selector
              DropdownButtonFormField<String>(
                focusNode: _bomDropdownFocusNode,
                value: _selectedBomProduct.isNotEmpty ? _selectedBomProduct : null,
                items: _availableBomProducts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _onBomSelected(val);
                    FocusScope.of(context).requestFocus(_qtyFocusNode);
                  }
                },
                decoration: const InputDecoration(labelText: 'Select BOM Recipe *', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),

              // Finished Product Name (Non-Editable)
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _selectedBomProduct),
                decoration: const InputDecoration(labelText: 'Finished Product (Auto)', border: OutlineInputBorder(), isDense: true, fillColor: Colors.black12, filled: true),
              ),
              const SizedBox(height: 10),

              // Quantity
              TextField(
                focusNode: _qtyFocusNode,
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_saveButtonFocusNode),
              ),
              const SizedBox(height: 10),
              Text('Cost/Piece: ₹${_costPerPiece.toStringAsFixed(2)} | Total: ₹${_grandTotalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          focusNode: _saveButtonFocusNode,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: _saveProduction,
          child: const Text('Save Production'),
        ),
      ],
    );
  }
}

// ==========================================
// EDIT / MODIFY PRODUCTION DIALOG
// ==========================================

class EditProductionDialog extends StatefulWidget {
  final ProductionLog productionLog;
  const EditProductionDialog({super.key, required this.productionLog});

  @override
  State<EditProductionDialog> createState() => _EditProductionDialogState();
}

class _EditProductionDialogState extends State<EditProductionDialog> {
  late TextEditingController _qtyController;
  double _currentCostPerPiece = 0.0;
  double _currentTotalCost = 0.0;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.productionLog.quantity.toString());
    _currentCostPerPiece = widget.productionLog.costPerPiece;
    _currentTotalCost = widget.productionLog.totalCost;
  }

  void _recalculate(String val) {
    double qty = double.tryParse(val) ?? 1.0;
    double oldQty = widget.productionLog.quantity;
    if (oldQty > 0) {
      double unitCost = widget.productionLog.totalCost / oldQty;
      setState(() {
        _currentCostPerPiece = unitCost;
        _currentTotalCost = unitCost * qty;
      });
    }
  }

  Future<void> _updateProduction() async {
    double newQty = double.tryParse(_qtyController.text) ?? 0.0;
    if (newQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid Qty enter karein!'), backgroundColor: Colors.red));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      widget.productionLog.quantity = newQty;
      widget.productionLog.totalCost = _currentTotalCost;
      widget.productionLog.costPerPiece = _currentCostPerPiece;
      await DatabaseHelper.isar.productionLogs.put(widget.productionLog);
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 15),
            Text('Production Updated Successfully!'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modify Production (${widget.productionLog.productionNumber})', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${widget.productionLog.productName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Modify Quantity *', border: OutlineInputBorder(), isDense: true),
              onChanged: _recalculate,
            ),
            const SizedBox(height: 10),
            Text('Updated Cost/Pc: ₹${_currentCostPerPiece.toStringAsFixed(2)} | Total: ₹${_currentTotalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: _updateProduction,
          child: const Text('Update'),
        ),
      ],
    );
  }
}

// ==========================================
// TAB 2: BOM MASTER & RECIPE BUILDER
// ==========================================

class BomMasterTab extends StatefulWidget {
  const BomMasterTab({super.key});

  @override
  State<BomMasterTab> createState() => _BomMasterTabState();
}

class _BomMasterTabState extends State<BomMasterTab> {
  List<String> _uniqueBomProducts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBomMasterList();
  }

  Future<void> _loadBomMasterList() async {
    setState(() => _isLoading = true);
    final boms = await DatabaseHelper.isar.billOfMaterials.where().findAll();
    var products = boms.map((b) => b.productName).toSet().toList();
    if (_searchQuery.isNotEmpty) {
      products = products.where((p) => p.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    setState(() {
      _uniqueBomProducts = products;
      _isLoading = false;
    });
  }

  void _openAddBomDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddEditBomDialog(),
    ).then((value) {
      if (value == true) _loadBomMasterList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search BOM Recipes',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _loadBomMasterList();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add New BOM'),
                    onPressed: _openAddBomDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _uniqueBomProducts.isEmpty
                    ? const Center(child: Text('Koi BOM Recipe nahi mili.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _uniqueBomProducts.length,
                        itemBuilder: (context, index) {
                          String productName = _uniqueBomProducts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            child: ListTile(
                              dense: true,
                              title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {},
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

// ==========================================
// ADD NEW BOM POP-UP FORM WITH INVENTORY SELECTION
// ==========================================

class AddEditBomDialog extends StatefulWidget {
  const AddEditBomDialog({super.key});

  @override
  State<AddEditBomDialog> createState() => _AddEditBomDialogState();
}

class _AddEditBomDialogState extends State<AddEditBomDialog> {
  final TextEditingController _productController = TextEditingController();
  List<InventoryItem> _allInventory = [];
  List<String> _inventoryNames = [];
  List<Map<String, dynamic>> _bomRows = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    _allInventory = await DatabaseHelper.isar.inventoryItems.where().findAll();
    _inventoryNames = _allInventory.map((i) => i.itemName).toSet().toList();
    setState(() {});
  }

  void _addRow() {
    setState(() {
      _bomRows.add({
        'materialController': TextEditingController(),
        'qtyController': TextEditingController(text: '1'),
        'unitController': TextEditingController(text: 'pcs'),
      });
    });
  }

  Future<void> _saveBomMaster() async {
    String productName = _productController.text.trim();
    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Unique BOM Name / Product enter karein!'), backgroundColor: Colors.red));
      return;
    }

    final existing = await DatabaseHelper.isar.billOfMaterials.filter().productNameEqualTo(productName).findFirst();
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Is naam ka BOM pehle se mojood hai!'), backgroundColor: Colors.red));
      return;
    }

    if (_bomRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kam se kam ek Raw Material add karein!'), backgroundColor: Colors.orange));
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var row in _bomRows) {
        String material = row['materialController'].text.trim();
        double qty = double.tryParse(row['qtyController'].text) ?? 0.0;
        String unit = row['unitController'].text.trim();

        if (material.isNotEmpty && qty > 0) {
          final bom = BillOfMaterials()
            ..productName = productName
            ..materialName = material
            ..quantity = qty
            ..unit = unit;
          await DatabaseHelper.isar.billOfMaterials.put(bom);
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BOM Created Successfully!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New BOM Recipe', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableField(
                label: 'Finished Product Name (Unique) *',
                items: _inventoryNames,
                controller: _productController,
                onSelected: (_) {},
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Raw Materials / Components:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Row'),
                    onPressed: _addRow,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._bomRows.asMap().entries.map((entry) {
                int idx = entry.key;
                var row = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchableField(
                          label: 'Material',
                          items: _inventoryNames,
                          controller: row['materialController'],
                          onSelected: (_) {},
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: row['qtyController'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: row['unitController'],
                          decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => setState(() => _bomRows.removeAt(idx)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
          onPressed: _saveBomMaster,
          child: const Text('Save BOM'),
        ),
      ],
    );
  }
}
