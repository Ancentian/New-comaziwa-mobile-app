import 'package:hive/hive.dart';
import '../models/milk_collection.dart';
import '../models/farmer.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<Box<Farmer>> farmersBox() async => Hive.box<Farmer>('farmers');
  Future<Box<MilkCollection>> milkBox() async => Hive.box<MilkCollection>('milk_collections');

  // helper save
  Future<void> saveFarmer(Farmer f) async {
    final box = await farmersBox();
    await box.put(f.farmerId, f);
  }

  Future<Farmer?> getFarmer(int id) async {
    final box = await farmersBox();
    return box.get(id);
  }

  Future<List<Farmer>> getAllFarmers() async {
    final box = await farmersBox();
    return box.values.toList();
  }

  Future<void> saveCollection(MilkCollection c) async {
    final box = await milkBox();
    await box.add(c);
  }

  Future<List<MilkCollection>> getAllCollections() async {
    final box = await milkBox();
    return box.values.toList();
  }
}
