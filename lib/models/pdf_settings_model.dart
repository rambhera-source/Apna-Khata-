import 'package:isar/isar.dart';

part 'pdf_settings_model.g.dart';

@collection
class PdfSettingsModel {
  Id id = 1; // Single instance settings ID

  // Custom Labels & Titles
  String companyCustomTitle = 'ORLIFE Mobile Accessories';
  String subHeading = 'Wholesale & Retail Mobile Parts & Accessories';
  
  // Column Visibility & Custom Names
  bool showSku = true;
  String skuColumnName = 'SKU';
  
  bool showGstin = true;
  bool showWatermark = false;
  
  // Theme Color Choice ('Teal', 'Amber', 'Blue', 'Indigo')
  String themeColorName = 'Teal';

  // Default Page Size ('A4', 'Letter', 'A5', 'Thermal 3-Inch')
  String pageSize = 'A4';
}
