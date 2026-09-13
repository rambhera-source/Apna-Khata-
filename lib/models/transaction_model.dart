import 'package:isar/isar.dart';

part 'transaction_model.g.dart';

@collection
class AccountingTransaction {
  Id id = Isar.autoIncrement;

  late String voucherType;      // 'Payment', 'Receipt', 'Journal'
  late String voucherNumber;    // Jaise PMT-9041, RCP-3312, GEN-1022
  late DateTime date;           // Voucher Date

  late String partyName;        // Party ka naam ya Debit/Credit accounts ki details
  late String cashOrBank;       // Cash-in-Hand, Specific Bank, UPI, ya Third Party source
  
  late double amount;           // Transaction Amount
  String? notes;                // Narration / Remarks (Optional)
}
