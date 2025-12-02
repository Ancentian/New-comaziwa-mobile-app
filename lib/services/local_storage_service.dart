import 'package:hive/hive.dart';
import '../models/milk_collection.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  final String boxName = 'milk_collections';

  Future<void> saveCollection(MilkCollection collection) async {
    final box = await Hive.openBox<MilkCollection>(boxName);
    await box.add(collection);
  }

  Future<List<MilkCollection>> getAllCollections() async {
    final box = await Hive.openBox<MilkCollection>(boxName);
    return box.values.toList();
  }

  Future<void> clearAll() async {
    final box = await Hive.openBox<MilkCollection>(boxName);
    await box.clear();
  }
}
