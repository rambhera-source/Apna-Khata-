import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class CompanySettings {
  Id id = Isar.autoIncrement;

  late String businessName;
  String? gstin;
  
  // Yeh batayega ki GST on hai ya off
  late bool isGstEnabled;

  // Invoice Numbering ke liye fields
  String invoicePrefix = 'INV/'; // Jaise: CI/ ya ORLIFE/
  int nextInvoiceNumber = 1;     // Agla bill number jo auto-generate hoga
}
