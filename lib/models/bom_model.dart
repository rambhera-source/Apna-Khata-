import 'package:isar/isar.dart';

part 'bom_model.g.dart';

@collection
class BillOfMaterials {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String productName;

  late String materialName;
  double quantity = 0.0;
  late String unit = 'Pcs';
}
