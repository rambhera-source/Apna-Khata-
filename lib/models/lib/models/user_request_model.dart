import 'package:isar/isar.dart';

part 'user_request_model.g.dart';

@collection
class UserRequest {
  Id id = Isar.autoIncrement;

  late String firmName;
  late String ownerName;
  late String phone;
  late String email;
  late String password;
  late String businessMode; // 'Wholesale' ya 'Manufacturing'
  late String pincode;
  late String city;
  late String state;
  late String address;
  
  // Status: 'Pending', 'Approved', 'Rejected'
  String status = 'Pending'; 
  
  // Subscription Plan assigned by Admin
  String assignedPlan = 'Monthly Standard';
}
