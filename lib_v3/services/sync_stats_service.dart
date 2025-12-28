import 'package:hive/hive.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';

class SyncStatsService {
  static int getSyncedFarmersCount() {
    final box = Hive.box<Farmer>('farmers');
    // if you have an `isSynced` flag in Farmer, filter it
    return box.values.where((f) => true).length; // all local farmers
  }

  static int getUnsyncedMilkCollectionsCount() {
    final box = Hive.box<MilkCollection>('milk_collections');
    return box.values.where((mc) => mc.isSynced == false).length;
  }
}
