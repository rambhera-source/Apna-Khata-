import 'package:isar/isar.dart';

part 'inventory_model.g.dart';

@collection
class InventoryItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String itemName; // e.g. "ORLIFE 85W Fast Charger"

  // 🆔 Added SKU and Stock Type for inventory tracking & filtering
  String? sku; 
  String? stockType = 'Fresh'; // 'Fresh' ya 'Replacement'

  late String category = 'Mobile Accessories'; // e.g. "Mobile Accessories", "Cables", "Power Banks"
  
  double stockQuantity = 0.0; // Current Stock
  late String unit = 'Pcs'; // e.g. "Pcs", "Box", "Set"

  // 🖼️ 4 Product Images ke local file paths
  String? imagePath1;
  String? imagePath2;
  String? imagePath3;
  String? imagePath4;

  // 🏷️ A to Z Price Tiers (Category A se Z tak ke rates)
  double priceA = 0.0;
  double priceB = 0.0;
  double priceC = 0.0;
  double priceD = 0.0;
  double priceE = 0.0;
  double priceF = 0.0;
  double priceG = 0.0;
  double priceH = 0.0;
  double priceI = 0.0;
  double priceJ = 0.0;
  double priceK = 0.0;
  double priceL = 0.0;
  double priceM = 0.0;
  double priceN = 0.0;
  double priceO = 0.0;
  double priceP = 0.0;
  double priceQ = 0.0;
  double priceR = 0.0;
  double priceS = 0.0;
  double priceT = 0.0;
  double priceU = 0.0;
  double priceV = 0.0;
  double priceW = 0.0;
  double priceX = 0.0;
  double priceY = 0.0;
  double priceZ = 0.0;
}
