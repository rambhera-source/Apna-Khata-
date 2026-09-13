import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class ProductHistoryScreen extends StatefulWidget {
  final InventoryItem product;
  const ProductHistoryScreen({super.key, required.product});

  @override
  State<ProductHistoryScreen> createState() => _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends State<ProductHistoryScreen> {
  // 📅 Date Range Filter State Variables
  DateTime? _startDate;
  DateTime? _endDate;

  // Date Range Picker Dialog
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.teal,
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Purchases, Sales, Manufacturing
      child: Scaffold(
        appBar: AppBar(
          title: Text('History & Stock: ${widget.product.itemName}'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: 'Purchases'),
              Tab(icon: Icon(Icons.sell), text: 'Sales'),
              Tab(icon: Icon(Icons.factory), text: 'Manufacturing'),
            ],
          ),
        ),
        body: Column(
          children: [
            // 📊 Live Stock & Closing Stock Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.teal.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStockBadge('Live Current Stock', '${widget.product.stockQuantity} ${widget.product.unit}', Colors.teal),
                  const VerticalDivider(color: Colors.grey),
                  _buildStockBadge('Closing Stock (Filtered)', '${widget.product.stockQuantity} ${widget.product.unit}', Colors.indigo),
                ],
              ),
            ),

            // 📅 Date Range Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.teal.shade100.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _startDate == null || _endDate == null
                          ? 'Date Filter: All Time (Tap to filter)'
                          : 'From: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}  To: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (_startDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                          tooltip: 'Clear Date Filter',
                          onPressed: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.date_range, size: 14),
                        label: const Text('Select Dates', style: TextStyle(fontSize: 11)),
                        onPressed: () => _selectDateRange(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views for Purchases, Sales & Manufacturing
            Expanded(
              child: TabBarView(
                children: [
                  _buildPurchaseHistoryList(context, widget.product),
                  _buildSalesHistoryList(context, widget.product),
                  _buildManufacturingHistoryList(context, widget.product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stock Badge UI Helper
  Widget _buildStockBadge(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 🛒 Purchase History List
  Widget _buildPurchaseHistoryList(BuildContext context, InventoryItem product) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Purchase Transactions (Tap to open bill)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.arrow_downward, color: Colors.indigo),
            title: const Text('Vendor: Sharma Electronics'),
            subtitle: const Text('Date: 12 Aug 2026 | Bill No: PUR-1092'),
            trailing: const Text('+500 Pcs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
            onTap: () => _openVoucherScreen(context, 'Purchase Bill', 'PUR-1092'),
          ),
        ),
      ],
    );
  }

  // 🏷️ Sales History List
  Widget _buildSalesHistoryList(BuildContext context, InventoryItem product) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Sales Transactions (Tap to open invoice)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.orange),
            title: const Text('Customer: Chamunda Mobile (Jalore)'),
            subtitle: const Text('Date: 14 Aug 2026 | Invoice No: INV-2026-88'),
            trailing: const Text('-50 Pcs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
            onTap: () => _openVoucherScreen(context, 'Sales Invoice', 'INV-2026-88'),
          ),
        ),
      ],
    );
  }

  // 🏭 Manufacturing History List
  Widget _buildManufacturingHistoryList(BuildContext context, InventoryItem product) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Production Batches (Tap to open production slip)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.precision_manufacturing, color: Colors.purple),
            title: const Text('Batch Production #PRD-2026-08'),
            subtitle: const Text('Date: 10 Aug 2026 | Status: Completed'),
            trailing: const Text('+1000 Pcs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
            onTap: () => _openVoucherScreen(context, 'Production Voucher', 'PRD-2026-08'),
          ),
        ),
      ],
    );
  }

  // Voucher / Bill open karne ka helper function
  void _openVoucherScreen(BuildContext context, String voucherType, String voucherNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open $voucherType'),
        content: Text('Aap "$voucherNumber" ko modify karne ke liye open karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Open for Edit'),
          ),
        ],
      ),
    );
  }
}
