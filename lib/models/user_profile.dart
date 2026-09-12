import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String username;

  late String password;
  
  // Business Type: 'retail', 'wholesale', ya 'manufacturing'
  late String businessType; 

  // Subscription expiry date
  late DateTime subscriptionExpiry;
  
  bool isActive = true;
}

