import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import 'searchable_field.dart';

class OrderBookingScreen extends StatefulWidget {
  const OrderBookingScreen({super.key});

  @override
  State<OrderBookingScreen> createState() => _OrderBookingScreenState();
}

class _OrderBookingScreenState extends State<OrderBookingScreen> {
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController(text: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  List<String> _allAccounts = [];
  List<Product> _allProducts = [];
  final List<Map<String, dynamic>> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final products = await DatabaseHelper.isar.products.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allProducts = products;
    });
  }

  void _addItemDialog() {
    if (_allProducts.isEmpty) return;
    Product selectedProduct = _allProducts.first;
    final TextEditingController qtyController = TextEditingController(text: '1');
    final TextEditingController priceController = TextEditingController(text: selectedProduct.sellingPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product to Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selectedProduct,
              items: _allProducts.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stock})'))).toList(),
              onChanged: (val) {
                selectedProduct = val!;
                priceController.text = selectedProduct.sellingPrice.toString();
              },
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder(), isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int q = int.tryParse(qtyController.text) ?? 1;
              double pr = double.tryParse(priceController.text) ?? selectedProduct.sellingPrice;
              setState(() {
                _orderItems.add({'name': selectedProduct.name, 'qty': q, 'price': pr});
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    if (_partyController.text.isEmpty || _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya Party aur Items bharein!'), backgroundColor: Colors.red));
      return;
    }

    final newOrder = SalesOrder()
      ..orderNo = _orderNoController.text
      ..partyName = _partyController.text.trim()
      ..date = DateTime.now()
      ..status = 'Pending';

    List<OrderItemModel> itemModels = [];
    for (var item in _orderItems) {
      final im = OrderItemModel()
        ..productName = item['name']
        ..qty = item['qty']
        ..price = item['price']
        ..isDelivered = false;
      itemModels.add(im);
    }

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.orderItemModels.putAll(itemModels);
      await DatabaseHelper.isar.salesOrders.put(newOrder);
      newOrder.items.addAll(itemModels);
      await newOrder.items.save();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Successfully Booked!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book New Customer Order'), backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: SearchableField(label: 'Party Name *', items: _allAccounts, controller: _partyController, onSelected: (v) {})),
                const SizedBox(width: 12),
                SizedBox(width: 150, child: TextField(controller: _orderNoController, decoration: const InputDecoration(labelText: 'Order No', border: OutlineInputBorder(), isDense: true))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ElevatedButton.icon(onPressed: _addItemDialog, icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _orderItems.length,
                itemBuilder: (context, index) {
                  final item = _orderItems[index];
                  return Card(
                    child: ListTile(
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Qty: ${item['qty']} | Price: ₹ ${item['price']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _orderItems.removeAt(index))),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white),
                onPressed: _saveOrder,
                child: const Text('Save Order (Pending)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
