import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/account.dart';
import '../models/user_profile.dart';
import '../models/bom_model.dart';
import '../models/settings_model.dart';
import '../models/inventory_model.dart';
import '../models/user_model.dart'; // UserAccount model import

class DatabaseHelper {
  static late Isar isar;

  static Future<void> initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    
    // Check karein agar Isar pehle se open nahi hai toh open karein
    if (Isar.instanceNames.isEmpty) {
      isar = await Isar.open(
        [
          PartySchema, 
          UserProfileSchema, 
          BillOfMaterialsSchema, 
          CompanySettingsSchema,
          InventoryStockSchema,
          UserAccountSchema // Staff signup/login ke liye
        ],
        directory: dir.path,
      );
    } else {
      isar = Isar.getInstance()!;
    }
  }

  // --- Party Functions (Updated with new Party model fields) ---
  static Future<List<Party>> getParties() async {
    return await isar.parties.where().findAll();
  }

  static Future<void> addParty({
    required String name,
    required String groupCategory,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    String priceCategory = 'A',
    double creditLimitAmount = 0.0,
    int creditDaysLimit = 0,
    bool isCreditControlEnabled = false,
    double openingBalance = 0.0,
    String balanceType = 'Dr',
    bool isPortalAccessEnabled = false,
    String? loginUsername,
    String? loginPassword,
  }) async {
    final party = Party()
      ..name = name
      ..groupCategory = groupCategory
      ..phone = phone
      ..email = email
      ..address = address
      ..gstin = gstin
      ..priceCategory = priceCategory
      ..creditLimitAmount = creditLimitAmount
      ..creditDaysLimit = creditDaysLimit
      ..isCreditControlEnabled = isCreditControlEnabled
      ..openingBalance = openingBalance
      ..balanceType = balanceType
      ..isPortalAccessEnabled = isPortalAccessEnabled
      ..loginUsername = loginUsername
      ..loginPassword = loginPassword;

    await isar.writeTxn(() async {
      await isar.parties.put(party);
    });
  }

  // --- User Profile / Login Functions ---
  static Future<void> addUser(String username, String password, String businessType) async {
    final user = UserProfile()
      ..username = username
      ..password = password
      ..businessType = businessType
      ..subscriptionExpiry = DateTime.now().add(const Duration(days: 365)) // 1 saal ka default plan
      ..isActive = true;

    await isar.writeTxn(() async {
      await isar.userProfiles.put(user);
    });
  }

  static Future<UserProfile?> loginUser(String username, String password) async {
    return await isar.userProfiles
        .filter()
        .usernameEqualTo(username)
        .passwordEqualTo(password)
        .findFirst();
  }
}
