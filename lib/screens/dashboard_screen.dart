import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/product.dart';
import '../models/order_model.dart';
import 'searchable_field.dart';

class OrdersManagementScreen extends StatefulWidget {
  final int initialTab; // 0 for Book New Order, 1 for Orders History
  const OrdersManagementScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers & State
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController(text: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  
  List<String> _allAccounts = [];
  List<Product> _allProducts = [];
  final List<Map<String, dynamic>> _orderItems = [];

  // Orders Management & Filter State
  List<SalesOrder> _ordersList = [];
  bool _isLoadingOrders = false;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  final Set<Id> _selectedOrderIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // 🔥 Dashboard se aaye hue initialTab ke hisab se tab open hoga
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _partyController.dispose();
    _orderNoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final accounts = await DatabaseHelper.isar.accounts.where().findAll();
    final products = await DatabaseHelper.isar.products.where().findAll();
    setState(() {
      _allAccounts = accounts.map((a) => a.name).toList();
      _allProducts = products;
    });
  }

  // 🔍 Fetch Orders Date-wise
  Future<void> _fetchOrders() async {
    setState(() => _isLoadingOrders = true);

    final startDateTime = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDateTime = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    final orders = await DatabaseHelper.isar.salesOrders
        .filter()
        .dateBetween(startDateTime, endDateTime)
        .sortByDateDesc()
        .findAll();

    setState(() {
      _ordersList = orders;
      _isLoadingOrders = false;
      _selectedOrderIds.clear();
      _isSelectionMode = false;
    });
  }

  // Add Item Dialog for Booking
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

  // 💾 Save New Order
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

    setState(() {
      _orderItems.clear();
      _orderNoController.text = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _partyController.clear();
    });

    _fetchOrders();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Successfully Booked!'), backgroundColor: Colors.green));
    
    // Switch to Orders History tab
    _tabController.animateTo(1);
  }

  // 🗑️ Delete Single Order
  Future<void> _deleteOrder(SalesOrder order) async {
    await DatabaseHelper.isar.writeTxn(() async {
      await order.items.load();
      for (var item in order.items) {
        await DatabaseHelper.isar.orderItemModels.delete(item.id);
      }
      await DatabaseHelper.isar.salesOrders.delete(order.id);
    });
    _fetchOrders();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted successfully!'), backgroundColor: Colors.red));
  }

  // 🗑️ Bulk Delete Selected Orders
  Future<void> _bulkDeleteOrders() async {
    if (_selectedOrderIds.isEmpty) return;

    await DatabaseHelper.isar.writeTxn(() async {
      for (var id in _selectedOrderIds) {
        final ord = await DatabaseHelper.isar.salesOrders.get(id);
        if (ord != null) {
          await ord.items.load();
          for (var item in ord.items) {
            await DatabaseHelper.isar.orderItemModels.delete(item.id);
          }
          await DatabaseHelper.isar.salesOrders.delete(id);
        }
      }
    });

    _fetchOrders();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedOrderIds.length} orders deleted successfully!'), backgroundColor: Colors.red),
    );
  }

  // ✏️ Modify Order Dialog
  void _editOrder(SalesOrder order) async {
    await order.items.load();
    final TextEditingController partyController = TextEditingController(text: order.partyName);
    List<Map<String, dynamic>> editableItems = order.items.map((i) => {
      'name': i.productName,
      'qty': i.qty,
      'price': i.price,
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Modify Order: ${order.orderNo}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: partyController, decoration: const InputDecoration(labelText: 'Party Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: editableItems.length,
                    itemBuilder: (context, index) {
                      final itm = editableItems[index];
                      return ListTile(
                        title: Text(itm['name']),
                        subtitle: Text('Qty: ${itm['qty']} | ₹${itm['price']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => setDialogState(() => editableItems.removeAt(index)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.isar.writeTxn(() async {
                  for (var oldItem in order.items) {
                    await DatabaseHelper.isar.orderItemModels.delete(oldItem.id);
                  }
                  List<OrderItemModel> newModels = [];
                  for (var itm in editableItems) {
                    final im = OrderItemModel()
                      ..productName = itm['name']
                      ..qty = itm['qty']
                      ..price = itm['price']
                      ..isDelivered = false;
                    newModels.add(im);
                  }
                  await DatabaseHelper.isar.orderItemModels.putAll(newModels);
                  order.partyName = partyController.text.trim();
                  order.items.clear();
                  order.items.addAll(newModels);
                  await DatabaseHelper.isar.salesOrders.put(order);
                  await order.items.save();
                });

                Navigator.pop(context);
                _fetchOrders();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order updated successfully!'), backgroundColor: Colors.green));
              },
              child: const Text('Update Order'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedOrderIds.length} Selected' : 'Orders Management'),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart), text: 'Book New Order'),
            Tab(icon: Icon(Icons.list_alt), text: 'Orders History'),
          ],
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 28),
              tooltip: 'Delete Selected Orders',
              onPressed: _bulkDeleteOrders,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ================= TAB 1: BOOK NEW ORDER =================
          Padding(
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
                  child: _orderItems.isEmpty
                      ? const Center(child: Text('Koi item add nahi kiya gaya hai.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
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

          // ================= TAB 2: ORDERS HISTORY =================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Filter Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (picked != null) { setState(() => _fromDate = picked); _fetchOrders(); }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'From Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month, size: 20)),
                          child: Text(DateFormat('dd-MM-yyyy').format(_fromDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _toDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (picked != null) { setState(() => _toDate = picked); _fetchOrders(); }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'To Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month, size: 20)),
                          child: Text(DateFormat('dd-MM-yyyy').format(_toDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _fetchOrders,
                      child: const Text('Filter'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Orders List
                Expanded(
                  child: _isLoadingOrders
                      ? const Center(child: CircularProgressIndicator())
                      : _ordersList.isEmpty
                          ? const Center(child: Text('Is date range mein koi order nahi mila.', style: TextStyle(color: Colors.grey, fontSize: 15)))
                          : ListView.builder(
                              itemCount: _ordersList.length,
                              itemBuilder: (context, index) {
                                final order = _ordersList[index];
                                final isSelected = _selectedOrderIds.contains(order.id);
                                bool isPending = order.status == 'Pending' || order.status.contains('Pending');

                                return Card(
                                  elevation: 2,
                                  color: isSelected ? Colors.amber.shade100 : Colors.white,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedOrderIds.add(order.id);
                                          } else {
                                            _selectedOrderIds.remove(order.id);
                                          }
                                          _isSelectionMode = _selectedOrderIds.isNotEmpty;
                                        });
                                      },
                                    ),
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Order No: ${order.orderNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Chip(
                                          label: Text(order.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                          backgroundColor: isPending ? Colors.amber.shade800 : Colors.green,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    subtitle: Text('Party: ${order.partyName}\nDate: ${DateFormat('dd-MM-yyyy').format(order.date)}'),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          tooltip: 'Modify Order',
                                          onPressed: () => _editOrder(order),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Delete Order',
                                          onPressed: () => _deleteOrder(order),
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
          ),
        ],
      ),
    );
  }
}
