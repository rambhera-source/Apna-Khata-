import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class CompanySettings {
  Id id = Isar.autoIncrement;

  late String businessName;
  String? gstin;
  
  // ✅ GST On/Off ke liye (User apni marzi se set karega)
  bool isGstEnabled = false;

  // 🔥 Routes aur Salesmen ki lists jo yahan jod di gayi hain
  List<String> routes = [];    // e.g. ["Ameerpet Route", "Koti Market"]
  List<String> salesmen = [];  // e.g. ["Rahul Sharma", "Amit Kumar"]

  // 🔥 Extra Charges & Discounts Master List (Stored as JSON strings)
  List<String> extraCharges = [];
}
