import 'package:isar/isar.dart';

part 'inventory_model.g.dart';

@collection
class InventoryStock {
  Id id = Isar.autoIncrement;

  late String itemName; // Jaise: ORLIFE 85W Charger
  
  // Stock Type: 'fresh' ya 'replacement'
  late String stockType; 

  // Quantity kitni hai
  late double quantity;

  // Warehouse ya Godown ka naam
  String locationName = 'Main Godown';
}
