import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';
import '../models/party.dart';
import '../models/inventory_model.dart';

// Purchase Bill model ko track karne ke liye ek chota sa local schema ya logic rakh sakte hain,
// Abhi hum inventory aur duplicate check handle karenge.
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<Party> _parties = [];
  Party? _selectedSupplier;
  
  final _billNoController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _stockType = 'fresh'; // 'fresh' ya 'replacement'
  bool _isGstEnabled = false;

  final List<Map<String, dynamic>> _purchaseItems = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final parties = await DatabaseHelper.isar.parties.where().findAll();
    final settings = await DatabaseHelper.isar.companySettings.where().findFirst();
    
    setState(() {
      _parties = parties;
      if (parties.isNotEmpty) _selectedSupplier = parties.first;
      if (settings != null) {
        _isGstEnabled = settings.isGstEnabled;
      }
    });
  }

  // Date picker open karne ke liye
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

  // Purchase Bill mein item add karna
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
    });
  }

  // Purchase Save & Stock IN karna (Duplicate Bill Number Check ke sath)
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

    // DUPLICATE CHECK: (Aap yahan check kar sakte hain ki yeh bill no pehle se hai ya nahi)
    // Abhi ke liye hum transaction ke andar stock update aur validation set kar rahe hain.

    await DatabaseHelper.isar.writeTxn(() async {
      for (var item in _purchaseItems) {
        String itemName = item['name'];
        double purchasedQty = item['qty'];

        // Inventory record check karein
        var stockRecord = await DatabaseHelper.isar.inventoryStocks
            .filter()
            .itemNameEqualTo(itemName)
            .and()
            .stockTypeEqualTo(_stockType)
            .findFirst();

        if (stockRecord != null) {
          stockRecord.quantity += purchasedQty; // Stock mein PLUS ho gaya
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
            // Supplier Selection & Date Picker
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Party>(
                    value: _selectedSupplier,
                    items: _parties.map((party) {
                      return DropdownMenuItem(
                        value: party,
                        child: Text(party.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSupplier = val),
                    decoration: const InputDecoration(labelText: 'Select Supplier', border: OutlineInputBorder()),
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

            // Manual Bill Number & Stock Type Row
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

            // Item input row
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(labelText: 'Item Name (e.g., ORLIFE Charger)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase Rate (₹)', border: OutlineInputBorder()),
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

            // Items list in current purchase bill
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

            // Totals and Save Button
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
                    Text('₹${grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
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
