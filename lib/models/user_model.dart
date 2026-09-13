import 'package:isar/isar.dart';

part 'user_model.g.dart';

@collection
class UserAccount {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String username; // Mobile number ya unique ID

  late String name;
  late String pin;
  late String role; // 'Admin' ya 'Staff'
  late bool isApproved; // false = Pending, true = Approved
}
