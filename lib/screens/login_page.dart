import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/farmer_service.dart';
import '../utils/http_retry_helper.dart';
import '../utils/error_logger.dart';
import 'error_logs_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _appVersion = info.version);
    } catch (e) {
      print('Failed to load package info: $e');
    }
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/terms');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Fluttertoast.showToast(
          msg: 'Could not open Terms & Conditions',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error opening link: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  /// ------------------------------------
  /// LOGIN FUNCTION
  /// ------------------------------------
  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: "Email and password required");
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse("${AppConfig.baseUrl}/api/auth/login");

    try {
      final response = await HttpRetryHelper.post(
        url: url,
        isJson: true,
        body: jsonEncode({'email': email, 'password': password}),
      );

      setState(() => _isLoading = false);

      // If the server returns non-200, show server error with status
      if (response.statusCode != 200) {
        // Log to file for support
        await ErrorLogger.logNetworkError(
          endpoint: url.toString(),
          statusCode: response.statusCode,
          contentType: response.headers['content-type'],
          rawBody: response.body,
          errorMessage: 'Login failed with status ${response.statusCode}',
          headers: response.headers,
        );

        Fluttertoast.showToast(
          msg: "Server Error (${response.statusCode})",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // At this point statusCode == 200. Ensure the response is JSON.
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        // Server returned HTML or plain text (often an error page). Log and show message.
        print('EXPECTED JSON BUT GOT: $contentType');
        print('RAW BODY: ${response.body}');

        // Log to file for support
        await ErrorLogger.logNetworkError(
          endpoint: url.toString(),
          statusCode: response.statusCode,
          contentType: contentType,
          rawBody: response.body,
          errorMessage:
              'Received non-JSON response (expected application/json)',
          headers: response.headers,
        );

        Fluttertoast.showToast(
          msg: "Unexpected response from server (not JSON). Check server logs.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } on FormatException catch (fe) {
        // This happens when response starts with '<' (HTML) or otherwise invalid JSON
        print('JSON PARSE ERROR: $fe');
        print('RAW BODY: ${response.body}');

        // Log to file for support
        await ErrorLogger.logNetworkError(
          endpoint: url.toString(),
          statusCode: response.statusCode,
          contentType: contentType,
          rawBody: response.body,
          errorMessage: 'JSON parse error: $fe',
          headers: response.headers,
        );

        Fluttertoast.showToast(
          msg: "Received invalid JSON from server.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();

        // -----------------------------
        // 🔥 SAVE TOKEN
        // -----------------------------
        await prefs.setString('token', data['token']);
        await prefs.setString('user_email', email);

        // -----------------------------
        // 🔥 SAVE USER TYPE (user / employee) & ID
        // -----------------------------
        if (data['user'] != null) {
          final type = data['user']['role'] ?? data['user']['type'] ?? 'user';
          await prefs.setString('type', type);

          // Save user/employee ID
          if (data['user']['id'] != null) {
            await prefs.setInt('user_id', data['user']['id']);
          }

          // Save user name
          if (data['user']['name'] != null) {
            await prefs.setString('name', data['user']['name']);
          }
        }

        // -----------------------------
        // 🔥 SAVE TENANT ID
        // -----------------------------
        if (data['user'] != null && data['user']['tenant_id'] != null) {
          await prefs.setInt('tenant_id', data['user']['tenant_id']);
        }

        // -----------------------------
        // 🔥 SAVE COMPANY INFO
        // -----------------------------
        if (data['company'] != null) {
          if (data['company']['name'] != null) {
            await prefs.setString('company_name', data['company']['name']);
          }
          if (data['company']['email'] != null) {
            await prefs.setString('company_email', data['company']['email']);
          }
        }

        Fluttertoast.showToast(
          msg: "Login successful",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // -----------------------------
        // 🔥 GO TO DASHBOARD
        // -----------------------------
        // Sync happens in dashboard initState
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        Fluttertoast.showToast(
          msg: data['message'] ?? "Login failed",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('LOGIN EXCEPTION: $e');

      // Log exception to file
      await ErrorLogger.logError(
        message: 'Login exception: $e',
        stackTrace: StackTrace.current.toString(),
      );

      Fluttertoast.showToast(
        msg: "Network error: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// ------------------------------------
  /// UI
  /// ------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('assets/logo.png', height: 90),
              const SizedBox(height: 10),
              const Text(
                "People for development",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Access to our dashboard",
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 32),

                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              // Terms, Version and View Logs Links
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _openTerms,
                      child: Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_appVersion.isNotEmpty)
                      Text(
                        'v${_appVersion.split('.').take(2).join('.')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ErrorLogsPage(),
                          ),
                        );
                      },
                      child: Text(
                        'View Error Logs',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
