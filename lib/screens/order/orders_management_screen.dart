import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/order_model.dart';
import 'book_order_screen.dart';
import '../sales/sales_screen.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> {
  List<SalesOrder> _ordersList = [];
  bool _isLoadingOrders = false;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  final Set<Id> _selectedOrderIds = {};
  bool _isSelectionMode = false;
  final TextEditingController _searchFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchFilterController.dispose();
    super.dispose();
  }

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

  void _generateBillForOrder(SalesOrder order) async {
    await order.items.load();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesScreen(initialOrder: order),
      ),
    );
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchFilterController.text.trim().toLowerCase();
    final filteredOrders = _ordersList.where((order) {
      if (query.isEmpty) return true;
      return order.orderNo.toLowerCase().contains(query) || order.partyName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedOrderIds.length} Selected' : 'Orders Management'),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 28),
              tooltip: 'Delete Selected Orders',
              onPressed: _bulkDeleteOrders,
            ),
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, size: 22),
            tooltip: 'Book New Order',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookOrderScreen()),
              );
              _fetchOrders();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) { setState(() => _fromDate = picked); _fetchOrders(); }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'From Date', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.calendar_month, size: 18)),
                      child: Text(DateFormat('dd-MM-yyyy').format(_fromDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _toDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) { setState(() => _toDate = picked); _fetchOrders(); }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'To Date', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.calendar_month, size: 18)),
                      child: Text(DateFormat('dd-MM-yyyy').format(_toDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white),
                    onPressed: _fetchOrders,
                    child: const Text('Filter', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _searchFilterController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Search by Order No or Party Name...',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchFilterController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() => _searchFilterController.clear());
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: filteredOrders.isNotEmpty && _selectedOrderIds.length == filteredOrders.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedOrderIds.addAll(filteredOrders.map((o) => o.id));
                            _isSelectionMode = true;
                          } else {
                            _selectedOrderIds.clear();
                            _isSelectionMode = false;
                          }
                        });
                      },
                    ),
                    const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_selectedOrderIds.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete, size: 16),
                    label: Text('Delete Selected (${_selectedOrderIds.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _bulkDeleteOrders,
                  ),
              ],
            ),
            const SizedBox(4),

            Expanded(
              child: _isLoadingOrders
                  ? const Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                      ? const Center(child: Text('No orders found in this date range.', style: TextStyle(color: Colors.grey, fontSize: 13)))
                      : ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final isSelected = _selectedOrderIds.contains(order.id);
                            bool isPending = order.status == 'Pending' || order.status.contains('Pending');

                            return Card(
                              elevation: 2,
                              color: isSelected ? Colors.amber.shade100 : Colors.white,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedOrderIds.add(order.id);
                                        _isSelectionMode = true;
                                      } else {
                                        _selectedOrderIds.remove(order.id);
                                        if (_selectedOrderIds.isEmpty) _isSelectionMode = false;
                                      }
                                    });
                                  },
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Order No: ${order.orderNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Chip(
                                      label: Text(order.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: isPending ? Colors.amber.shade800 : Colors.green,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                subtitle: Text('Party: ${order.partyName}\nDate: ${DateFormat('dd-MM-yyyy').format(order.date)}', style: const TextStyle(fontSize: 11)),
                                isThreeLine: true,
                                onTap: () => _editOrder(order),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPending)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          minimumSize: const Size(70, 30),
                                        ),
                                        onPressed: () => _generateBillForOrder(order),
                                        child: const Text('Gen Bill', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book Order'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookOrderScreen()),
          );
          _fetchOrders();
        },
      ),
    );
  }
}
