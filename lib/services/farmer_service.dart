import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/farmer.dart';

class FarmerService {
  static final FarmerService _instance = FarmerService._internal();
  factory FarmerService() => _instance;
  FarmerService._internal();

  final String apiBase = "https://your-api.com/api"; // replace with your API

  /// Get token from SharedPreferences
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Fetch all farmers from API and save to Hive
  Future<void> fetchAllFarmers() async {
    final token = await _getAuthToken();
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse("$apiBase/farmers"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final List data = json.decode(res.body)['farmers'];
        final box = Hive.box<Farmer>('farmers');

        for (var f in data) {
          final farmer = Farmer.fromJson(f);
          box.put(farmer.farmerId, farmer);
        }

        Fluttertoast.showToast(
          msg: "Farmers synced successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Failed to fetch farmers",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "No internet — offline data only",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  /// Start listening to connectivity changes and auto-sync farmers
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        fetchAllFarmers();
      }
    });
  }

  /// Search farmer in Hive locally
Farmer? searchLocal(String memberNo) {
  final box = Hive.box<Farmer>('farmers');
  return box.values.cast<Farmer?>().firstWhere(
    (f) => f != null && f.farmerId.toString() == memberNo,
    orElse: () => null,
  );
}

}
