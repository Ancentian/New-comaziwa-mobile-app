import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/milk_collection.dart';
import '../config/app_config.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final String apiBase = "${AppConfig.baseUrl}/api";

  Future<void> syncCollections() async {
    final box = Hive.box<MilkCollection>('milk_collections');
    final unsynced = box.values.where((c) => c.isSynced == false).toList();

    for (var collection in unsynced) {
      try {
        final token = await _getAuthToken();
        if (token == null) continue;

        final response = await http.post(
          Uri.parse("$apiBase/store-milk-collection"),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: {
            "farmer_id": collection.farmerId.toString(),
            "collection_date": collection.date,
            "morning": collection.morning.toString(),
            "evening": collection.evening.toString(),
            "rejected": collection.rejected.toString(),
          },
        );

        if (response.statusCode == 200) {
          collection.isSynced = true;
          await collection.save();
        }
      } catch (e) {
        // ignore if offline
      }
    }
  }

  void startSyncListener() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        syncCollections();
      }
    });
  }

  Future<String?> _getAuthToken() async {
    // Implement how you retrieve token (e.g., SharedPreferences)
    return null;
  }
}
