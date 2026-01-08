import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/http_retry_helper.dart';

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
    
    final response = await HttpRetryHelper.get(
      url: url,
      authToken: token,
    );
    
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        print('API getStaffProfile expected JSON but got: $contentType');
        print('RAW BODY: ${response.body}');
        return {'success': false, 'message': 'Invalid server response (not JSON)'};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print('JSON parse error in getStaffProfile: $e');
        print('RAW BODY: ${response.body}');
        return {'success': false, 'message': 'Invalid JSON from server'};
      }
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

    final response = await HttpRetryHelper.post(
      url: url,
      authToken: token,
      isJson: true,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        print('API updateProfile expected JSON but got: $contentType');
        print('RAW BODY: ${response.body}');
        return {'success': false, 'message': 'Invalid server response (not JSON)'};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print('JSON parse error in updateProfile: $e');
        print('RAW BODY: ${response.body}');
        return {'success': false, 'message': 'Invalid JSON from server'};
      }
    } else if (response.statusCode == 422) {
      try {
        final decoded = jsonDecode(response.body);
        return {
          'success': false,
          'errors': decoded['errors'],
        };
      } catch (e) {
        print('JSON parse error parsing 422 body: $e');
        print('RAW BODY: ${response.body}');
        return {'success': false, 'message': 'Validation error (malformed response)'};
      }
    } else {
      return {'success': false, 'message': 'Something went wrong'};
    }
  }
}
  // ---------------------------------------------------