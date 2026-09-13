import 'package:isar/isar.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name; // e.g. "Ramesh Mobile Shop", "HDFC Bank", "Salary Account"

  late String groupCategory; 
  // 'Sundry Debtor', 'Sundry Creditor', 'Bank Account', 'Cash-in-Hand', 'Direct Expense', 'Indirect Expense', etc.

  // 📞 Contact & Address
  String? phone;
  String? email;
  String? address;
  String? gstin;

  // 🏷️ Pricing & Credit Control (Sirf Customers ke liye)
  String priceCategory = 'A'; // A to Z Price Tier
  double creditLimitAmount = 0.0;
  int creditDaysLimit = 0;
  bool isCreditControlEnabled = false;

  // 💰 Opening Balance & Ledger Type
  double openingBalance = 0.0; 
  String balanceType = 'Dr'; // 'Dr' ya 'Cr'

  // 🔐 🔥 Naye Fields: Party Portal Login Credentials
  bool isPortalAccessEnabled = false; // Toggle to allow/block app login for this party
  String? loginUsername; // e.g. Mobile number or unique ID
  String? loginPassword; // Password for client login
}
