import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class CompanySettings {
  Id id = Isar.autoIncrement;

  late String businessName;
  String? gstin;
  
  // ✅ GST On/Off ke liye (User apni marzi se set karega)
  bool isGstEnabled = false;
}
