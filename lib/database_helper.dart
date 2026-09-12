import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/party.dart';

class DatabaseHelper {
  static late Isar isar;

  static Future<void> initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [PartySchema],
      directory: dir.path,
    );
  }

  static Future<List<Party>> getParties() async {
    return await isar.parties.where().findAll();
  }

  static Future<void> addParty(String name, String phone, String type, double openingBalance) async {
    final party = Party()
      ..name = name
      ..phone = phone
      ..partyType = type
      ..balance = openingBalance;

    await isar.writeTxn(() async {
      await isar.parties.put(party);
    });
  }
}
