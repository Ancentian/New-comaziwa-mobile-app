import 'dart:convert';
import 'package:flutter/material.dart'; // Needed for Color
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/farmer.dart';

class FarmerService {
  static final FarmerService _instance = FarmerService._internal();
  factory FarmerService() => _instance;
  FarmerService._internal();

  final String apiBase = "${AppConfig.baseUrl}/api";

  /// Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Download all farmers from server and save to Hive
  Future<bool> downloadFarmers() async {
    final token = await _getAuthToken();
    if (token == null) {
      Fluttertoast.showToast(
        msg: "Login required",
        backgroundColor: Colors.red, // corrected
        textColor: Colors.white,
      );
      return false;
    }

    try {
      final res = await http.get(
        Uri.parse("$apiBase/farmers-sync-data"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode != 200) return false;

      final jsonData = json.decode(res.body);
      final List<dynamic> farmersList =
          (jsonData['farmers'] ?? jsonData['data'] ?? jsonData) as List<dynamic>;
      final box = Hive.box<Farmer>('farmers');

      await box.clear();
      for (var f in farmersList) {
        final farmer = Farmer.fromJson(Map<String, dynamic>.from(f));
        box.put(farmer.farmerId, farmer);
      }

      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Download failed (offline)",
        backgroundColor: Colors.orange, // corrected
        textColor: Colors.white,
      );
      return false;
    }
  }

  /// Search online for a member number (returns Farmer or null)
  Future<Farmer?> searchOnline(String memberNo) async {
    final token = await _getAuthToken();
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse("$apiBase/find-farmer/$memberNo"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      final f = Farmer.fromJson(Map<String, dynamic>.from(data['farmer']));

      // save locally
      final box = Hive.box<Farmer>('farmers');
      box.put(f.farmerId, f);

      return f;
    } catch (_) {
      return null;
    }
  }

  /// Search from local Hive storage
  Farmer? searchLocal(String memberNo) {
    final box = Hive.box<Farmer>('farmers');
    for (var f in box.values) {
      if (f.farmerId.toString() == memberNo) return f;
    }
    return null;
  }

  /// Start auto-sync when device regains connectivity
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        downloadFarmers();
      }
    });
  }
}
