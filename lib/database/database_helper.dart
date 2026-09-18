import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../models/bom_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/inventory_model.dart';

class DatabaseHelper {
  static late Isar isar;

  static Future<void> initDB() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open(
      [
        AccountSchema,
        ProductSchema,
        UserProfileSchema,
        BillOfMaterialsSchema,
        CompanySettingsSchema,
        UserAccountSchema,
        SalesOrderSchema,
        OrderItemModelSchema,
        AccountingTransactionSchema,
        InventoryItemSchema,
      ],
      directory: dir.path,
      inspector: true,
    );
  }

  // ----------------------------------------------------------
  // Account / Party Functions
  // ----------------------------------------------------------

  static Future<List<Account>> getParties() async {
    return await isar.accounts.where().findAll();
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
    final account = Account()
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
      await isar.accounts.put(account);
    });
  }

  // ----------------------------------------------------------
  // User Profile / Login Functions
  // ----------------------------------------------------------

  static Future<void> addUser(
    String username,
    String password,
    String businessType,
  ) async {
    final user = UserProfile()
      ..username = username
      ..password = password
      ..businessType = businessType
      ..subscriptionExpiry =
          DateTime.now().add(const Duration(days: 365))
      ..isActive = true;

    await isar.writeTxn(() async {
      await isar.userProfiles.put(user);
    });
  }

  static Future<UserProfile?> loginUser(
    String username,
    String password,
  ) async {
    return await isar.userProfiles
        .filter()
        .usernameEqualTo(username)
        .passwordEqualTo(password)
        .findFirst();
  }
}