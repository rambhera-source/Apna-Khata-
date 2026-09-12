import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';
import '../models/party.dart';
import '../models/inventory_model.dart';
import 'searchable_field.dart'; // Ekdum sahi import path (screens folder ke liye)

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<Party> _parties = [];
  List<String> _partyNames = [];
  Party? _selectedSupplier;
  List<String> _availableItems = [];
  
  // Controllers
  final _supplierSearchController = TextEditingController();
  final _billNoController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String _stockType = 'fresh';
  bool _isGstEnabled = false;

  List<Map<String, dynamic>> _supplierHistoryList = [];
  final List<Map<String, dynamic>> _purchaseItems = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _supplierSearchController.dispose();
    _billNoController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final parties = await DatabaseHelper.isar.parties.where().findAll();
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    final inventoryStocks = await DatabaseHelper.isar.inventoryStocks.where().findAll();
    
    final Set<String> uniqueItems = inventoryStocks.map((e) => e.itemName).toSet();
    final List<String> partyNamesList = parties.map((e) => e.name).toList();
    
    setState(() {
      _parties = parties;
      _partyNames = partyNamesList;
      if (parties.isNotEmpty) {
        _selectedSupplier = parties.first;
        _supplierSearchController.text = parties.first.name;
      }
      _availableItems = uniqueItems.toList();
      if (settings != null) {
        _isGstEnabled = settings.isGstEnabled;
      }
    });
  }

  void _onItemNameSelected(String typedItem) {
    if (typedItem.length < 2 || _selectedSupplier == null) {
      setState(() => _supplierHistoryList = []);
      return;
    }

    setState(() {
      _supplierHistoryList = [
        {'date': '01/08/2026', 'billNo': 'SUP-901', 'name': typedItem, 'rate': 200.0},
        {'date': '15/07/2026', 'billNo': 'SUP-842', 'name': typedItem, 'rate': 195.0},
      ];
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addItemToPurchase() {
    final itemName = _itemController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (itemName.isEmpty || qty <= 0 || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya item name, qty aur purchase rate sahi se bharein!')),
      );
      return;
    }

    setState(() {
      _purchaseItems.add({
        'name': itemName,
        'qty': qty,
        'rate': rate,
        'total': qty * rate,
      });
      _itemController.clear();
      _qtyController.clear();
      _rateController.clear();
      _supplierHistoryList = [];
    });
  }

  Future<void> _savePurchase() async {
    final billNo = _billNoController.text.trim();

    if (_selectedSupplier == null || billNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Supplier aur Manual Bill Number darj karein!')),
      );
      return;
    }

    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam se kam ek item add karna anivarya hai!')),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var item in _purchaseItems) {
        String itemName = item['name'];
        double purchasedQty = item['qty'];

        var stockRecord = await DatabaseHelper.isar.inventoryStocks
            .filter()
            .itemNameEqualTo(itemName)
            .and()
            .stockTypeEqualTo(_stockType)
            .findFirst();

        if (stockRecord != null) {
          stockRecord.quantity += purchasedQty;
          await DatabaseHelper.isar.inventoryStocks.put(stockRecord);
        } else {
          var newStock = InventoryStock()
            ..itemName = itemName
            ..stockType = _stockType
            ..quantity = purchasedQty;
          await DatabaseHelper.isar.inventoryStocks.put(newStock);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase Bill ($billNo) Safaltapurvak Save Ho Gaya!')),
    );

    setState(() {
      _purchaseItems.clear();
      _billNoController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    double subTotal = _purchaseItems.fold(0, (sum, item) => sum + item['total']);
    double taxAmount = _isGstEnabled ? subTotal * 0.18 : 0.0;
    double grandTotal = subTotal + taxAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase / Inward Bill Entry'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SearchableField(
                    label: 'Select Supplier',
                    items: _partyNames,
                    controller: _supplierSearchController,
                    onSelected: (selectedName) {
                      final matchedParty = _parties.firstWhere(
                        (p) => p.name.toLowerCase() == selectedName.toLowerCase(),
                        orElse: () => _parties.first,
                      );
                      setState(() {
                        _selectedSupplier = matchedParty;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _billNoController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Bill No (Manual)', 
                      border: OutlineInputBorder(),
                      hintText: 'e.g. SUP-102',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [_stockType == 'fresh', _stockType == 'replacement'],
                  onPressed: (index) {
                    setState(() {
                      _stockType = index == 0 ? 'fresh' : 'replacement';
                    });
                  },
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Fresh')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Replace')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SEARCHABLE ITEM FIELD
            SearchableField(
              label: 'Item Name (Type to Search...)',
              items: _availableItems,
              controller: _itemController,
              onSelected: (selectedItem) {
                _onItemNameSelected(selectedItem);
                FocusScope.of(context).requestFocus(_qtyFocusNode);
              },
              onSubmitted: () {
                FocusScope.of(context).requestFocus(_qtyFocusNode);
              },
            ),

            // SCROLLABLE SUPPLIER HISTORY BOX
            if (_supplierHistoryList.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _supplierHistoryList.length,
                    itemBuilder: (context, index) {
                      final h = _supplierHistoryList[index];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _rateController.text = h['rate'].toString();
                          });
                          FocusScope.of(context).requestFocus(_qtyFocusNode);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${h['date']} | ${h['billNo']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              Expanded(
                                child: Text('  ${h['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              ),
                              Text('₹${h['rate']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    focusNode: _qtyFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_rateFocusNode);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    focusNode: _rateFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase Rate (₹)', border: OutlineInputBorder()),
                    onSubmitted: (_) {
                      _addItemToPurchase();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: _addItemToPurchase,
                  child: const Text('Add'),
                ),
              ],
            ),
            const Divider(height: 24),

            const Text('Items Added in Purchase:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _purchaseItems.isEmpty
                  ? const Center(child: Text('Abhi koi purchase item add nahi kiya gaya hai.'))
                  : ListView.builder(
                      itemCount: _purchaseItems.length,
                      itemBuilder: (context, index) {
                        final item = _purchaseItems[index];
                        return Card(
                          child: ListTile(
                            title: Text(item['name']),
                            subtitle: Text('Qty: ${item['qty']} | Rate: ₹${item['rate']}'),
                            trailing: Text('₹${item['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('SubTotal:'),
                    Text('₹${subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  if (_isGstEnabled)
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('GST (18% Auto):'),
                      Text('₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: _savePurchase,
                      child: const Text('Save Purchase & Update Stock', style: TextStyle(fontSize: 16)),
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
