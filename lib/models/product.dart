import 'package:isar/isar.dart';

part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;
  double stock = 0.0;
  double sellingPrice = 0.0;
  double purchasePrice = 0.0; // 🔥 Purchase Price successfully added here
}
