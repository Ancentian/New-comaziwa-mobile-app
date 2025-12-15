import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/farmer.dart';
import '../utils/http_retry_helper.dart';

class FarmerService {
  static final FarmerService _instance = FarmerService._internal();
  factory FarmerService() => _instance;
  FarmerService._internal();

  final String apiBase = "${AppConfig.baseUrl}/api";

  /// --------------------------------------------------------
  /// Get saved auth token
  /// --------------------------------------------------------
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Try multiple possible keys for backward compatibility
    return prefs.getString('token') ??
        prefs.getString('auth_token') ??
        prefs.getString('access_token');
  }

  /// --------------------------------------------------------
  /// Get saved tenant_id (user.id OR employee.tenant_id)
  /// --------------------------------------------------------
  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id'); // Must exist for multi-tenancy
  }

  /// --------------------------------------------------------
  /// Download all farmers for this tenant
  /// --------------------------------------------------------
  Future<bool> downloadFarmers() async {
    final token = await _getAuthToken();
    final tenantId = await _getTenantId();

    print(
      '🔄 downloadFarmers called - token: ${token != null ? "exists" : "null"}, tenantId: $tenantId',
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
      final url = Uri.parse("$apiBase/farmers-sync-data?tenant_id=$tenantId");

      final response = await HttpRetryHelper.get(url: url, authToken: token);

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ downloadFarmers FAILED - STATUS: ${response.statusCode}');
        print('BODY: ${response.body}');
        Fluttertoast.showToast(
          msg: "Sync failed: ${response.statusCode}",
          backgroundColor: Colors.red,
        );
        return false;
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        print('downloadFarmers expected JSON but got: $contentType');
        print('RAW BODY: ${response.body}');
        return false;
      }

      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(response.body);
      } catch (e) {
        print('JSON parse error in downloadFarmers: $e');
        print('RAW BODY: ${response.body}');
        return false;
      }
      final List<dynamic> farmersList =
          (jsonData['farmers'] ?? jsonData['data'] ?? []) as List;

      print('📦 Received ${farmersList.length} farmers from API');

      final box = Hive.box<Farmer>('farmers');
      final oldCount = box.length;

      await box.clear();
      print('🗑️ Cleared $oldCount old farmers from Hive');

      for (var f in farmersList) {
        final farmer = Farmer.fromJson(Map<String, dynamic>.from(f));
        
        box.put(farmer.farmerId, farmer);
      }

      print('✅ Saved ${box.length} farmers to Hive');
      Fluttertoast.showToast(
        msg: "Synced ${box.length} farmers",
        backgroundColor: Colors.green,
      );

      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Download failed (offline mode)",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return false;
    }
  }

  /// --------------------------------------------------------
  /// Online search for one farmer by memberNo
  /// --------------------------------------------------------
  Future<Farmer?> searchOnline(String memberNo) async {
    final token = await _getAuthToken();
    final tenantId = await _getTenantId();

    if (token == null || tenantId == null) {
      return null;
    }

    try {
      final url = Uri.parse(
        "$apiBase/find-farmer/$memberNo?tenant_id=$tenantId",
      );

      final response = await HttpRetryHelper.get(url: url, authToken: token);

      if (response.statusCode != 200) {
        print('searchOnline failed - status: ${response.statusCode}');
        print('body: ${response.body}');
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        print('searchOnline expected JSON but got: $contentType');
        print('RAW BODY: ${response.body}');
        return null;
      }

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('JSON parse error in searchOnline: $e');
        print('RAW BODY: ${response.body}');
        return null;
      }
      final farmerData = Map<String, dynamic>.from(data['farmer']);

      final farmer = Farmer.fromJson(farmerData);

      Hive.box<Farmer>('farmers').put(farmer.farmerId, farmer);

      return farmer;
    } catch (e) {
      return null;
    }
  }

  /// --------------------------------------------------------
  /// Local search (offline)
  /// --------------------------------------------------------
  Farmer? searchLocal(String memberNo) {
    final box = Hive.box<Farmer>('farmers');

    for (var f in box.values) {
      if (f.farmerId.toString() == memberNo) {
        return f;
      }
    }

    return null;
  }

  /// --------------------------------------------------------
  /// Auto-sync whenever internet comes back online
  /// --------------------------------------------------------
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        downloadFarmers();
      }
    });
  }
}
