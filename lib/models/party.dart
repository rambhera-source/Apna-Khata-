import 'isar.dart';

part 'party.g.dart';

@collection
class Party {
  Id id = Isar.autoIncrement; // Fast auto-incrementing ID

  @Index(type: IndexType.value) // Search fast karne ke liye index
  late String name;

  late String phone;
  
  late String partyType; // 'Customer' ya 'Supplier'
  
  double balance = 0.0; // Positive = Lena hai, Negative = Dena hai
}
