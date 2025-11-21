import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  // Existing Milk Record API
  static Future<bool> sendMilkRecord(Map<String, dynamic> record, {bool online = true}) async {
    final url = Uri.parse('${AppConfig.getBaseUrl(online)}/api/milk/store');
    final response = await http.post(url, body: record);
    return response.statusCode == 200;
  }

  //Get Staff Profile API
  static Future<Map<String, dynamic>> getStaffProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      return {'success': false, 'message': 'Unauthorized'};
    }
    final url = Uri.parse('${AppConfig.getBaseUrl(true)}/api/staff-profile');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'success': false, 'message': 'Something went wrong'};
    }
  }

  // ---------- New: Update Staff Profile API ----------
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? password,
    String? passwordConfirmation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      return {'success': false, 'message': 'Unauthorized'};
    }

    final url = Uri.parse('${AppConfig.getBaseUrl(true)}/api/update-staff-profile');

    final body = {
      'name': name,
      'email': email,
      'phone_no': phone,
    };

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['password_confirmation'] = passwordConfirmation ?? '';
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 422) {
      return {
        'success': false,
        'errors': jsonDecode(response.body)['errors'],
      };
    } else {
      return {'success': false, 'message': 'Something went wrong'};
    }
  }
}
  // ---------------------------------------------------