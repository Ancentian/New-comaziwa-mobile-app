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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/milk_collection.dart';
import '../utils/http_retry_helper.dart';
import '../utils/error_helper.dart';
import 'farmer_service.dart';

class SyncService {
  final String apiBase = "${AppConfig.baseUrl}/api";
  static bool _isSyncing = false;

  /// Start background sync listener - monitors connectivity changes
  void startSyncListener({Duration interval = const Duration(minutes: 5)}) {
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      if (result != ConnectivityResult.none && !_isSyncing) {
        print("🌐 Internet connection restored. Auto-syncing...");
        _autoSync();
      }
    });
  }

  /// Auto-sync unsynced data when internet is available
  Future<void> _autoSync() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      // Step 1: Upload unsynced collections
      final pendingCount = getPendingCollectionsCount();

      if (pendingCount > 0) {
        print("📤 Found $pendingCount unsynced collections. Uploading...");

        final uploadSuccess = await syncCollections();

        if (uploadSuccess) {
          print("✅ $pendingCount collections uploaded successfully");
        } else {
          print("⚠️ Some collections could not be uploaded");
        }
      }

      // Step 2: Download new collections from server
      print("📥 Downloading new collections from server...");
      final downloadSuccess = await downloadMilkCollections();

      if (downloadSuccess) {
        print("✅ Collections downloaded successfully");
      } else {
        print("⚠️ Could not download new collections");
      }

      // Step 3: Download updated farmer data
      print("📥 Downloading farmer data from server...");
      try {
        final farmerSuccess = await FarmerService().downloadFarmers();
        if (farmerSuccess) {
          print("✅ Farmer data downloaded successfully");
        } else {
          print("⚠️ Could not download all farmer data");
        }
      } catch (e) {
        print("⚠️ Could not download farmer data: $e");
      }

      // Show success notification if any sync succeeded
      if (pendingCount > 0 || downloadSuccess) {
        Fluttertoast.showToast(
          msg: "✅ Data synced successfully",
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      final logMessage = ErrorHelper.getLogMessage(e);
      print("❌ Auto-sync error: $logMessage");
    } finally {
      _isSyncing = false;
    }
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

    final tenantId = await _getTenantId();
    //final token = await _getAuthToken();
    print("TOKEN → $token");
    if (token == null) {
      print("TOKEN ERROR → No token found in SharedPreferences.");
      return false;
    }

    bool allSynced = true;

    // Get user type and ID for tracking who created the collection
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('type');
    final userId = prefs.getInt('user_id');

    for (var collection in unsynced) {
      try {
        final body = {
          "farmer_id": collection.farmerId,
          "collection_date": collection.date,
          "morning": collection.morning,
          "evening": collection.evening,
          "rejected": collection.rejected,
        };

        // Add creator info if available
        if (userType != null) {
          body['created_by_type'] = userType;
        }
        if (userId != null) {
          body['created_by_id'] = userId;
        }

        final res = await HttpRetryHelper.post(
          url: Uri.parse("$apiBase/store-milk-collection?tenant_id=$tenantId"),
          authToken: token,
          isJson: true,
          body: jsonEncode(body),
        );
        print("TOKEN → $token");
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

  /// Download milk collections from server and store in Hive
  /// This enables offline viewing and accurate monthly/yearly totals
  /// Downloads ALL historical data (no date restrictions) for complete yearly totals
  Future<bool> downloadMilkCollections({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _getToken();
      final tenantId = await _getTenantId();

      if (token == null || tenantId == null) {
        print("Cannot download collections: missing auth token or tenant ID");
        return false;
      }

      // Download ALL data without date restrictions for accurate yearly totals
      // Date filters can be applied in UI for display, but sync gets everything
      String url =
          "$apiBase/milk-collections-sync?tenant_id=$tenantId&limit=5000";

      print("📥 Downloading milk collections from: $url");

      final res = await HttpRetryHelper.get(
        url: Uri.parse(url),
        authToken: token,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['success'] == true) {
          final collections = data['data'] as List;
          final box = Hive.box<MilkCollection>('milk_collections');

          int imported = 0;
          int updated = 0;

          for (var item in collections) {
            final serverId = item['id'];

            // Check if this collection already exists (by server ID)
            final existing = box.values.cast<MilkCollection?>().firstWhere(
              (c) => c != null && c.serverId == serverId,
              orElse: () => null,
            );

            final collection = MilkCollection.fromJson(item);

            if (existing != null) {
              // Update existing record
              existing.morning = collection.morning;
              existing.evening = collection.evening;
              existing.rejected = collection.rejected;
              existing.isSynced = true;
              await existing.save();
              updated++;
            } else {
              // Add new record
              await box.add(collection);
              imported++;
            }
          }

          print("✅ Downloaded $imported new, updated $updated collections");
          return true;
        }
      }

      print("❌ Failed to download collections: ${res.statusCode}");
      return false;
    } catch (e) {
      print("❌ Error downloading collections: $e");
      return false;
    }
  }

  /// Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// --------------------------------------------------------
  /// Get saved tenant_id (user.id OR employee.tenant_id)
  /// --------------------------------------------------------
  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id'); // Must exist for multi-tenancy
  }
}
