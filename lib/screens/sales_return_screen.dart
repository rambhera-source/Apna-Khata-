import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/party.dart';
import '../models/inventory_model.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  List<Party> _parties = [];
  Party? _selectedParty;
  
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final FocusNode _itemFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();

  String _stockType = 'fresh'; // 'fresh' ya 'replacement'
  
  // Is party ki pichhli sales history jo item type karne par dikhegi
  List<Map<String, dynamic>> _partySalesHistory = [];

  @override
  void initState() {
    super.initState();
    _loadParties();
    _itemController.addListener(_onItemNameChanged);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    final parties = await DatabaseHelper.isar.parties.where().findAll();
    setState(() {
      _parties = parties;
      if (parties.isNotEmpty) _selectedParty = parties.first;
    });
  }

  // Jab dukaandar item name type karega, toh is selected party ki pichhli sales history aayegi
  void _onItemNameChanged() {
    final typedItem = _itemController.text.trim();
    if (typedItem.length < 2 || _selectedParty == null) {
      setState(() => _partySalesHistory = []);
      return;
    }

    // Yahan hum sample sales history dikha rahe hain jo batayegi ki is party ko yeh item kis rate mein gaya tha
    setState(() {
      _partySalesHistory = [
        {'date': '10/08/2026', 'billNo': 'INV/040', 'name': typedItem, 'rate': 250.0},
        {'date': '25/07/2026', 'billNo': 'INV/025', 'name': typedItem, 'rate': 250.0},
        {'date': '12/07/2026', 'billNo': 'INV/018', 'name': typedItem, 'rate': 240.0},
      ];
    });
  }

  void _addItemToReturn() {
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
      // Return items list mein add karna (hamari purani list ke mutabiq)
      // Yahan hum local state ya map use kar rahe hain
    });
  }

  final List<Map<String, dynamic>> _returnItems = [];

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

    FocusScope.of(context).requestFocus(_itemFocusNode);
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
          stockRecord.quantity += returnQty; // Return aane par stock mein PLUS
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
                  child: DropdownButtonFormField<Party>(
                    value: _selectedParty,
                    items: _parties.map((party) {
                      return DropdownMenuItem(
                        value: party,
                        child: Text(party.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedParty = val),
                    decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
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

            // Item Input Field
            TextField(
              controller: _itemController,
              focusNode: _itemFocusNode,
              decoration: const InputDecoration(
                labelText: 'Item Name (e.g., ORLIFE Charger)', 
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(_qtyFocusNode);
              },
            ),

            // 📜 SCROLLABLE PARTY HISTORY DROPBOX (Sirf isi party ka pichhla rate/bill dikhega)
            if (_partySalesHistory.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150), // Max 5 lines view, excess par scroll
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _partySalesHistory.length,
                    itemBuilder: (context, index) {
                      final h = _partySalesHistory[index];
                      return InkWell(
                        onTap: () {
                          // Click karte hi original rate automatic rate box mein set ho jayega
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
                      FocusScope.of(context),
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
