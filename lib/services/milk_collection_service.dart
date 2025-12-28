import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/milk_collection.dart';
import '../utils/http_retry_helper.dart';

class MilkCollectionService {
  static final MilkCollectionService _instance =
      MilkCollectionService._internal();
  factory MilkCollectionService() => _instance;
  MilkCollectionService._internal();

  final String apiBase = "${AppConfig.baseUrl}/api";

  /// --------------------------------------------------------
  /// Get saved auth token
  /// --------------------------------------------------------
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('auth_token') ??
        prefs.getString('access_token');
  }

  /// --------------------------------------------------------
  /// Get saved tenant_id (user.id OR employee.tenant_id)
  /// --------------------------------------------------------
  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id');
  }

  /// --------------------------------------------------------
  /// Download all milk collections for this tenant
  /// (Past 12 months to get complete yearly data)
  /// --------------------------------------------------------
  Future<bool> downloadMilkCollections() async {
    final token = await _getAuthToken();
    final tenantId = await _getTenantId();

    print(
      '🔄 downloadMilkCollections called - token: ${token != null ? "exists" : "null"}, tenantId: $tenantId',
    );

    if (token == null || tenantId == null) {
      Fluttertoast.showToast(
        msg: "Login required",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    }

    try {
      // Calculate date range: last 12 months
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 365));

      final url = Uri.parse(
        "$apiBase/milk-collections-sync?"
        "tenant_id=$tenantId&"
        "start_date=${DateFormat('yyyy-MM-dd').format(startDate)}&"
        "end_date=${DateFormat('yyyy-MM-dd').format(endDate)}&"
        "limit=5000",
      );

      print('🌐 Fetching milk collections from: $url');

      final response = await HttpRetryHelper.get(url: url, authToken: token);

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print(
          '❌ downloadMilkCollections FAILED - STATUS: ${response.statusCode}',
        );
        print('BODY: ${response.body}');
        Fluttertoast.showToast(
          msg: "Milk sync failed: ${response.statusCode}",
          backgroundColor: Colors.red,
        );
        return false;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        print('Expected JSON but got: $contentType');
        print('RAW BODY: ${response.body}');
        return false;
      }

      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(response.body);
      } catch (e) {
        print('JSON parse error: $e');
        print('RAW BODY: ${response.body}');
        return false;
      }

      final List<dynamic> collectionsList =
          (jsonData['data'] ?? jsonData['collections'] ?? []) as List;

      print('📦 Received ${collectionsList.length} milk collections from API');

      final box = Hive.box<MilkCollection>('milk_collections');
      final oldCount = box.length;

      // Don't clear - merge with existing unsynced records
      // Only update synced records (those with serverId)
      for (var c in collectionsList) {
        try {
          final collection = MilkCollection(
            farmerId: c['farmer_id'] ?? c['farmerID'] ?? 0,
            date: c['collection_date'] ?? c['date'] ?? '',
            morning: (c['morning'] ?? 0).toDouble(),
            evening: (c['evening'] ?? 0).toDouble(),
            rejected: (c['rejected'] ?? 0).toDouble(),
            isSynced: true, // Mark as synced from server
            center_name: c['center_name'],
            fname: c['fname'],
            lname: c['lname'],
            serverId: c['id'],
          );

          // Use serverId if available, otherwise use farmerId+date as composite key
          final key = collection.serverId ?? collection.farmerId;
          box.put(key, collection);
        } catch (e) {
          print('⚠️ Error parsing collection: $e');
        }
      }

      print('✅ Milk collections synced: had $oldCount, now have ${box.length}');
      Fluttertoast.showToast(
        msg: "Synced ${collectionsList.length} milk records",
        backgroundColor: Colors.green,
      );

      return true;
    } catch (e) {
      print('❌ downloadMilkCollections error: $e');
      Fluttertoast.showToast(
        msg: "Milk sync failed (offline mode)",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return false;
    }
  }

  /// --------------------------------------------------------
  /// Get all milk collections for a specific farmer
  /// --------------------------------------------------------
  List<MilkCollection> getMilkCollectionsForFarmer(int farmerId) {
    final box = Hive.box<MilkCollection>('milk_collections');
    return box.values.where((m) => m.farmerId == farmerId).toList();
  }

  /// --------------------------------------------------------
  /// Get yearly total for a farmer
  /// --------------------------------------------------------
  double getYearlyTotal(int farmerId) {
    final collections = getMilkCollectionsForFarmer(farmerId);
    final now = DateTime.now();

    return collections
        .where((m) {
          final date = DateTime.tryParse(m.date);
          return date != null && date.year == now.year;
        })
        .fold<double>(
          0,
          (sum, m) => sum + (m.morning + m.evening - m.rejected),
        );
  }

  /// --------------------------------------------------------
  /// Get monthly total for a farmer
  /// --------------------------------------------------------
  double getMonthlyTotal(int farmerId) {
    final collections = getMilkCollectionsForFarmer(farmerId);
    final now = DateTime.now();

    return collections
        .where((m) {
          final date = DateTime.tryParse(m.date);
          return date != null &&
              date.year == now.year &&
              date.month == now.month;
        })
        .fold<double>(
          0,
          (sum, m) => sum + (m.morning + m.evening - m.rejected),
        );
  }

  /// --------------------------------------------------------
  /// Get daily total for a farmer (today)
  /// --------------------------------------------------------
  double getDailyTotal(int farmerId) {
    final collections = getMilkCollectionsForFarmer(farmerId);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return collections
        .where((m) => m.date == todayStr)
        .fold<double>(
          0,
          (sum, m) => sum + (m.morning + m.evening - m.rejected),
        );
  }
}
