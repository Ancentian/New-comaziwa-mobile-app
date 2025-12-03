// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:hive/hive.dart';
// import '../config/app_config.dart';
// import '../models/milk_collection.dart';

// class SyncService {
//   final String apiBase = "${AppConfig.baseUrl}/api";

//   /// Start background sync listener (optional)
//   void startSyncListener({Duration interval = const Duration(minutes: 5)}) {
//     // Example: Timer.periodic(interval, (_) => syncAll());
//   }

//   /// Sync all unsynced data
//   Future<bool> syncAll() async {
//     return await syncCollections();
//   }

//   /// Sync all unsynced milk collections
//   Future<bool> syncCollections() async {
//     final box = Hive.box<MilkCollection>('milk_collections');
//     final unsynced = box.values.where((c) => !c.isSynced).toList();

//     if (unsynced.isEmpty) return true;

//     final token = await _getToken();
//     if (token == null) return false;

//     bool allSynced = true;

//     for (var collection in unsynced) {
//       try {
//         final res = await http.post(
//           Uri.parse("$apiBase/store-milk-collection"),
//           headers: {
//             'Authorization': 'Bearer $token',
//             'Content-Type': 'application/json',
//           },
//           body: jsonEncode({
//             "farmer_id": collection.farmerId,
//             "date": collection.date,
//             "morning": collection.morning,
//             "evening": collection.evening,
//             "rejected": collection.rejected,
//           }),
//         );

//         if (res.statusCode == 200) {
//           collection.isSynced = true;
//           await collection.save();
//         } else {
//           allSynced = false;
//         }
//       } catch (e) {
//         allSynced = false;
//         print("Error syncing collection ${collection.key}: $e");
//       }
//     }

//     return allSynced;
//   }

//   /// Count of unsynced milk collections
//   int getPendingCollectionsCount() {
//     final box = Hive.box<MilkCollection>('milk_collections');
//     return box.values.where((c) => !c.isSynced).length;
//   }

//   /// Get auth token from shared preferences
//   Future<String?> _getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('token');
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import '../models/milk_collection.dart';

class SyncService {
  final String apiBase = "${AppConfig.baseUrl}/api";

  /// Start background sync listener (optional)
  void startSyncListener({Duration interval = const Duration(minutes: 5)}) {
    // Example: Timer.periodic(interval, (_) => syncAll());
  }

  /// Sync all unsynced data
  Future<bool> syncAll() async {
    return await syncCollections();
  }

  /// Sync all unsynced milk collections
  Future<bool> syncCollections() async {
    final box = Hive.box<MilkCollection>('milk_collections');
    final unsynced = box.values.where((c) => !c.isSynced).toList();

    if (unsynced.isEmpty) {
      print("No unsynced collections found.");
      return true;
    }

    final token = await _getToken();
    //final token = await _getAuthToken();
    print("TOKEN → ${token}");
    if (token == null) {
      print("TOKEN ERROR → No token found in SharedPreferences.");
      return false;
    }

    bool allSynced = true;

    for (var collection in unsynced) {
      try {
        final res = await http.post(
          Uri.parse("$apiBase/store-milk-collection"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            "farmer_id": collection.farmerId,
            "collection_date": collection.date,
            "morning": collection.morning,
            "evening": collection.evening,
            "rejected": collection.rejected,
          }),
        );
        print("TOKEN → ${token}");
        print("SERVER STATUS → ${res.statusCode}");
        print("SERVER RESPONSE → ${res.body}");

        /// Handle Laravel validation error (422)
        if (res.statusCode == 422) {
          final errorData = jsonDecode(res.body);
          print("VALIDATION ERROR: ${errorData['message']}");
          print("DETAILS: ${errorData['errors']}");
          allSynced = false;
          continue; 
        }

        /// Handle Laravel success
        if (res.statusCode == 200 || res.statusCode == 201) {
          collection.isSynced = true;
          await collection.save();

          print("Collection ${collection.key} synced successfully.");
        } else {
          allSynced = false;
          print("FAILED SYNC FOR KEY ${collection.key}");
          print("Status: ${res.statusCode}");
          print("Body: ${res.body}");
        }
      } catch (e) {
        allSynced = false;
        print("EXCEPTION → Could not sync collection ${collection.key}: $e");
      }
    }

    return allSynced;
  }

  /// Count of unsynced milk collections
  int getPendingCollectionsCount() {
    final box = Hive.box<MilkCollection>('milk_collections');
    return box.values.where((c) => !c.isSynced).length;
  }

  /// Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}

