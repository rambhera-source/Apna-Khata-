import 'package:isar/isar.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name; // Party or Account Name

  late String groupCategory; 
  // e.g., 'Sundry Debtor', 'Sundry Creditor', 'Bank Account', 'Cash-in-Hand'

  // 📞 Contact & Address Details
  String? phone;
  String? email;
  String? address;
  String? gstin;

  // 🚚 🔥 New: Route aur Salesman fields
  String? route;
  String? salesman;

  // 🏷️ Pricing & Credit Control
  String priceCategory = 'A'; // A to Z Price Tier
  double creditLimitAmount = 0.0;
  int creditDaysLimit = 0;
  bool isCreditControlEnabled = false;

  // 💰 Opening Balance
  double openingBalance = 0.0; 
  String balanceType = 'Dr'; // 'Dr' ya 'Cr'

  // 🔐 Client Portal Login Credentials
  bool isPortalAccessEnabled = false; 
  String? loginUsername; 
  String? loginPassword; 
}
