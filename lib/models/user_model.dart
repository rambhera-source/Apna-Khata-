import 'package:isar/isar.dart';

part 'user_model.g.dart';

@collection
class UserAccount {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String username; // Mobile number ya unique ID

  late String name;
  late String pin;
  
  // ✅ Role & Status
  String role = 'Staff'; // 'Admin' ya 'Staff'
  bool isApproved = false; // Admin approval status

  // 🏭 Business Type (Manufacturing vs Wholesaler / Retailer)
  String businessType = 'Wholesaler / Retailer'; 

  // 📦 Subscription & Validity Details
  String subscriptionPlan = 'Demo Plan';
  String validityDate = '2027-12-31';

  // 🔒 Module-wise Feature Permissions
  bool canManageOrders = true;
  bool canManageParties = true;
  bool canManageInventory = true;
  bool canViewReports = true;
}
