import 'package:isar/isar.dart';

part 'user_model.g.dart';

@collection
class UserAccount {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String username; // Mobile number ya unique ID

  late String name;
  late String pin;
  
  // ✅ Default values set kar di gayi hain taaki uninitialized error na aaye
  String role = 'Staff'; // 'Admin' ya 'Staff'
  bool isApproved = false; // false = Pending, true = Approved
}
