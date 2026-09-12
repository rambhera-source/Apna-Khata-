import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/party.dart';
import '../models/inventory_model.dart';
import 'searchable_field.dart'; // Ekdum sahi import path (screens folder ke liye)

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  List<Party> _parties = [];
  List<String> _partyNames = [];
  Party? _selectedParty;
  List<String> _availableItems = [];
  
  // Controllers
  final _partySearchController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();

  String _stockType = 'fresh';
  List<Map<String, dynamic>> _partySalesHistory = [];
  final List<Map<String, dynamic>> _returnItems = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _partySearchController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final parties = await DatabaseHelper.isar.parties.where().findAll();
    final inventoryStocks = await DatabaseHelper.isar.inventoryStocks.where().findAll();
    
    final Set<String> uniqueItems = inventoryStocks.map((e) => e.itemName).toSet();
    final List<String> partyNamesList = parties.map((e) => e.name).toList();

    setState(() {
      _parties = parties;
      _partyNames = partyNamesList;
      if (parties.isNotEmpty) {
        _selectedParty = parties.first;
        _partySearchController.text = parties.first.name;
      }
      _availableItems = uniqueItems.toList();
    });
  }

  void _onItemNameSelected(String typedItem) {
    if (typedItem.length < 2 || _selectedParty == null) {
      setState(() => _partySalesHistory = []);
      return;
    }

    setState(() {
      _partySalesHistory = [
        {'date': '10/08/2026', 'billNo': 'INV/040', 'name': typedItem, 'rate': 250.0},
        {'date': '25/07/2026', 'billNo': 'INV/025', 'name': typedItem, 'rate': 250.0},
      ];
    });
  }

  void _addItemToList() {
    final itemName = _itemController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (itemName.isEmpty || qty <= 0 || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya item name, qty aur rate sahi se bharein!')),
      );
      return;
    }

    setState(() {
      _returnItems.add({
        'name': itemName,
        'qty': qty,
        'rate': rate,
        'total': qty * rate,
      });
      _itemController.clear();
      _qtyController.clear();
      _rateController.clear();
      _partySalesHistory = [];
    });
  }

  Future<void> _saveSalesReturn() async {
    if (_returnItems.isEmpty || _selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer select karein aur return item add karein!')),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var item in _returnItems) {
        String itemName = item['name'];
        double returnQty = item['qty'];

        var stockRecord = await DatabaseHelper.isar.inventoryStocks
            .filter()
            .itemNameEqualTo(itemName)
            .and()
            .stockTypeEqualTo(_stockType)
            .findFirst();

        if (stockRecord != null) {
          stockRecord.quantity += returnQty;
          await DatabaseHelper.isar.inventoryStocks.put(stockRecord);
        } else {
          var newStock = InventoryStock()
            ..itemName = itemName
            ..stockType = _stockType
            ..quantity = returnQty;
          await DatabaseHelper.isar.inventoryStocks.put(newStock);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sales Return Safaltapurvak Save Ho Gaya aur Stock Update Ho Gaya!')),
    );

    setState(() {
      _returnItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    double grandTotal = _returnItems.fold(0, (sum, item) => sum + item['total']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Return (Customer Return)'),
        backgroundColor: Colors.orange,
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
                  child: SearchableField(
                    label: 'Select Customer',
                    items: _partyNames,
                    controller: _partySearchController,
                    onSelected: (selectedName) {
                      final matchedParty = _parties.firstWhere(
                        (p) => p.name.toLowerCase() == selectedName.toLowerCase(),
                        orElse: () => _parties.first,
                      );
                      setState(() {
                        _selectedParty = matchedParty;
                      });
                    },
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
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Fresh (Good)')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Replace (Bad)')),
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

            // SCROLLABLE HISTORY BOX
            if (_partySalesHistory.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _partySalesHistory.length,
                    itemBuilder: (context, index) {
                      final h = _partySalesHistory[index];
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
                              Text('${h['date']} | ${h['billNo']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
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
                    decoration: const InputDecoration(labelText: 'Return Quantity', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()),
                    onSubmitted: (_) {
                      _addItemToList();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: _addItemToList,
                  child: const Text('Add'),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Returned Items List:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _returnItems.isEmpty
                  ? const Center(child: Text('Abhi koi return item add nahi kiya gaya hai.'))
                  : ListView.builder(
                      itemCount: _returnItems.length,
                      itemBuilder: (context, index) {
                        final item = _returnItems[index];
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
                    const Text('Total Return Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      onPressed: _saveSalesReturn,
                      child: const Text('Save Sales Return & Update Stock', style: TextStyle(fontSize: 16)),
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
