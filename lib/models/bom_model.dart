import 'package:isar/isar.dart';

part 'bom_model.g.dart';

@collection
class BillOfMaterials {
  Id id = Isar.autoIncrement;

  // Finished Product
  late String productName;

  // Raw Material / Component
  late String materialName;

  // Quantity required for 1 unit of finished product
  double quantity = 0.0;

  // Unit: Pcs, Meter, Kg, Box, etc.
  late String unit = 'Pcs';
}