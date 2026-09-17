import 'package:isar/isar.dart';

part 'account_category_model.g.dart';

@collection
class AccountCategoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String categoryName; // e.g. Sundry Debtor, Sundry Creditor, etc.

  // List of usernames or salesman IDs who have permission to access/view this category
  List<String> allowedUsers = []; 
}
