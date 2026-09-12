import 'package:isar/isar.dart';

part 'settings_model.g.dart';

@collection
class CompanySettings {
  Id id = Isar.autoIncrement;

  late String businessName;
  String? gstin;
  
  // Yeh batayega ki GST on hai ya off
  late bool isGstEnabled;
}
