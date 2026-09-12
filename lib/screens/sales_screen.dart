import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';
import '../models/party.dart';
import '../models/inventory_model.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Party> _parties = [];
  Party? _selectedParty;
  
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final FocusNode _itemFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();

  String _stockType = 'fresh';
  bool _isGstEnabled = false;
  String _generatedInvoiceNo = 'INV/001';
  int _currentInvoiceSeq = 1;

  DateTime _billDate = DateTime.now();
  final List<Map<String, dynamic>> _billItems = [];

  // Mock / Dynamic History List jo item type karne par dikhegi
  // (Format: Date | Bill No | Item Name | Rate)
  List<Map<String, dynamic>> _itemHistoryList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    final parties = await DatabaseHelper.isar.parties.where().findAll();
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    
    setState(() {
      _parties = parties;
      if (parties.isNotEmpty) _selectedParty = parties.first;

      if (settings != null) {
        _isGstEnabled = settings.isGstEnabled;
        _currentInvoiceSeq = settings.nextInvoiceNumber;
        _generatedInvoiceNo = '${settings.invoicePrefix}$_currentInvoiceSeq';
      }
    });
  }

  // Jab dukaandar item name type karega, toh uski pichli history fetch hogi
  void _onItemNameChanged() {
    final typedItem = _itemController.text.trim();
    if (typedItem.length < 2 || _selectedParty == null) {
      setState(() => _itemHistoryList = []);
      return;
    }

    // Yahan hum sample history generate kar rahe hain (Aap isko database se connect kar sakte hain)
    // Dhyan dein: Yeh scrollable list mein 5 se zyada hone par scroll support karegi
    setState(() {
      _itemHistoryList = [
        {'date': '12/08/2026', 'billNo': 'INV/045', 'name': typedItem, 'rate': 250.0},
        {'date': '05/08/2026', 'billNo': 'INV/038', 'name': typedItem, 'rate': 245.0},
        {'date': '28/07/2026', 'billNo': 'INV/022', 'name': typedItem, 'rate': 240.0},
        {'date': '15/07/2026', 'billNo': 'INV/015', 'name': typedItem, 'rate': 250.0},
        {'date': '01/07/2026', 'billNo': 'INV/009', 'name': typedItem, 'rate': 235.0},
        {'date': '20/06/2026', 'billNo': 'INV/004', 'name': typedItem, 'rate': 230.0}, // 6th item (Scrollable test)
      ];
    });
  }

  Future<void> _selectBillDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _billDate) {
      setState(() {
        _billDate = picked;
      });
    }
  }

  void _addItemToBill() {
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
      _billItems.add({
        'name': itemName,
        'qty': qty,
        'rate': rate,
        'total': qty * rate,
      });
      _itemController.clear();
      _qtyController.clear();
      _rateController.clear();
      _itemHistoryList = [];
    });

    FocusScope.of(context).requestFocus(_itemFocusNode);
  }

  Future<void> _saveBill() async {
    if (_billItems.isEmpty || _selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party select karein aur kam se kam ek item add karein!')),
      );
      return;
    }

    await DatabaseHelper.isar.writeTxn(() async {
      for (var item in _billItems) {
        String itemName = item['name'];
        double soldQty = item['qty'];

        var stockRecord = await DatabaseHelper.isar.inventoryStocks
            .filter()
            .itemNameEqualTo(itemName)
            .and()
            .stockTypeEqualTo(_stockType)
            .findFirst();

        if (stockRecord != null) {
          stockRecord.quantity -= soldQty;
          await DatabaseHelper.isar.inventoryStocks.put(stockRecord);
        } else {
          var newStock = InventoryStock()
            ..itemName = itemName
            ..stockType = _stockType
            ..quantity = -soldQty;
          await DatabaseHelper.isar.inventoryStocks.put(newStock);
        }
      }

      final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
      if (settings != null) {
        settings.nextInvoiceNumber = _currentInvoiceSeq + 1;
        await DatabaseHelper.isar.companySettings.put(settings);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bill No: $_generatedInvoiceNo Safaltapurvak Ban Gaya aur Stock Update Ho Gaya!')),
    );

    setState(() {
      _billItems.clear();
      _currentInvoiceSeq++;
    });
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    double subTotal = _billItems.fold(0, (sum, item) => sum + item['total']);
    double taxAmount = _isGstEnabled ? subTotal * 0.18 : 0.0;
    double grandTotal = subTotal + taxAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Invoice: $_generatedInvoiceNo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _selectBillDate(context),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Date: ${_billDate.day}/${_billDate.month}/${_billDate.year}'),
                ),
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

            // Party Dropdown
            DropdownButtonFormField<Party>(
              value: _selectedParty,
              items: _parties.map((party) {
                return DropdownMenuItem(
                  value: party,
                  child: Text(party.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedParty = val);
              },
              decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            // Item Input
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

            // 📜 SCROLLABLE HISTORY BOX (Max 5 items visible, extra par scroll aayega)
            if (_itemHistoryList.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 160), // Lagbhag 5 lines ki height
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _itemHistoryList.length,
                    itemBuilder: (context, index) {
                      final h = _itemHistoryList[index];
                      return InkWell(
                        onTap: () {
                          // Us row par click karte hi rate automatic rate box mein set ho jayega
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

            const SizedBox(height: 4),
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
                    decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()),
                    onSubmitted: (_) {
                      _addItemToBill();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: _addItemToBill,
                  child: const Text('Add'),
                ),
              ],
            ),
            const Divider(height: 24),

            const Text('Items Added in Bill:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _billItems.isEmpty
                  ? const Center(child: Text('Abhi koi item add nahi kiya gaya hai.'))
                  : ListView.builder(
                      itemCount: _billItems.length,
                      itemBuilder: (context, index) {
                        final item = _billItems[index];
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
                choice: null,
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
                      onPressed: _saveBill,
                      child: const Text('Save & Finalize Bill', style: TextStyle(fontSize: 16)),
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
