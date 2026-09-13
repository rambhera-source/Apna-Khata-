import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class CompanySettings {
  Id id = Isar.autoIncrement;

  late String businessName;
  String? gstin;
  
  // ✅ GST On/Off ke liye (User apni marzi se set karega)
  bool isGstEnabled = false; 

  // ✅ Neutral default prefix (User baad mein apni company ke hisaab se badal lega)
  String invoicePrefix = 'INV/'; 
  int nextInvoiceNumber = 1;     
}
