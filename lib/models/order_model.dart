import 'package:isar/isar.dart';

part 'order_model.g.dart';

@collection
class OrderItemModel {
  Id id = Isar.autoIncrement;
  late String productName;
  late int qty;
  late double price;
  bool isDelivered = false; // Agar deliver ho gaya toh true
}

@collection
class SalesOrder {
  Id id = Isar.autoIncrement;
  late String orderNo;
  late String partyName;
  late DateTime date;
  
  final items = IsarLinks<OrderItemModel>();
  
  String status = 'Pending'; // 'Pending', 'Converted to Bill', 'Cancelled'
}
