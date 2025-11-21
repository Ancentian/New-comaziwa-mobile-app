import '../db/database_helper.dart';
import 'api_service.dart';

class SyncService {
  static Future<void> syncData() async {
    final db = await DatabaseHelper.instance.database;
    final unsynced = await db.query('milk_collections', where: 'synced = 0');

    for (final record in unsynced) {
      bool success = await ApiService.sendMilkRecord(record);
      if (success) {
        await db.update(
          'milk_collections',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      }
    }
  }
}
