import 'package:isar/isar.dart';

part 'party.g.dart';

@collection
class Party {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  late String phone;
  String? email; // 🔥 Nayi field: Email ID
  late String address;
  late String partyType; // 'Sundry Debtor' ya 'Sundry Creditor'

  String? gstin;
  
  double openingBalance = 0.0; 
  String balanceType = 'Dr'; // 'Dr' ya 'Cr'

  String priceCategory = 'A'; // A to Z Price Tier

  // 🔥 Credit Control & Limit Fields
  double creditLimitAmount = 0.0; // Max credit amount allowed
  int creditDaysLimit = 0;        // Max days allowed (e.g. 45 or 60 days)
  bool isCreditControlEnabled = false; // On/Off Switch for restriction
}
