import 'package:isar/isar.dart';

part 'party.g.dart';

@collection
class Party {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  late String phone;
  late String address;
  late String partyType; // 'Sundry Debtor' ya 'Sundry Creditor'

  String? gstin;
  
  double openingBalance = 0.0; 
  String balanceType = 'Dr'; // 'Dr' ya 'Cr'

  // 🔥 A se Z tak ki Price Category store karne ke liye
  String priceCategory = 'A'; 
}
