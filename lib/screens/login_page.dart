import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
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
  bool _rememberMe = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Failed to load saved credentials: $e');
    }
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
    final uri = Uri.parse('https://www.cowango.org/privacy-policy.html');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Fluttertoast.showToast(
          msg: 'Could not open Privacy Policy',
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

    // Check internet connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      Fluttertoast.showToast(
        msg:
            "No internet connection.\nPlease check your network and try again.",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
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
        // 🔥 SAVE CREDENTIALS IF REMEMBER ME IS CHECKED
        // -----------------------------
        if (_rememberMe) {
          await prefs.setString('saved_email', email);
          await prefs.setString('saved_password', password);
          await prefs.setBool('remember_me', true);
        } else {
          // Clear saved credentials if remember me is unchecked
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
          await prefs.setBool('remember_me', false);
        }

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
        // 🔥 SAVE GRADER COLLECTION CENTERS
        // -----------------------------
        if (data['user'] != null &&
            data['user']['collection_centers'] != null) {
          final centers = (data['user']['collection_centers'] as List)
              .map((e) => e.toString())
              .toList();
          await prefs.setStringList('grader_centers', centers);
          print('💾 Saved grader centers: $centers');
          print('📊 User type: ${data['user']['type']}');
          print('📊 Full user data: ${data['user']}');
        } else {
          // Clear any previously saved centers if user is not a grader
          await prefs.remove('grader_centers');
          print('⚠️ No collection centers found - clearing grader_centers');
          print('📊 User type: ${data['user']?['type']}');
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
        // 🔥 COMMIT AUTOFILL FOR PASSWORD MANAGER
        // -----------------------------
        // This tells the system to save the credentials to Google Password Manager
        TextInput.finishAutofillContext(shouldSave: true);

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

      // Better error messages for users
      String userMessage = "Network error. Please try again.";

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        userMessage =
            "Cannot connect to server.\nPlease check your internet connection and try again.";
      } else if (e.toString().contains('TimeoutException')) {
        userMessage =
            "Connection timeout.\nServer is taking too long to respond.";
      } else if (e.toString().contains('HandshakeException')) {
        userMessage =
            "Secure connection failed.\nPlease check your network settings.";
      }

      Fluttertoast.showToast(
        msg: userMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  /// ------------------------------------
  /// UI
  /// ------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.shade50,
                const Color(0xFFF7F9FB),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Logo with enhanced styling
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade300.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/logo.png', height: 90),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Welcome text
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade900],
                    ).createShader(bounds),
                    child: const Text(
                      "Welcome to Comaziwa",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Dairy Management Made Simple",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    elevation: 8,
                    shadowColor: Colors.green.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _emailController,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: "Email Address",
                                    hintText: "your@email.com",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    // Focus on password field when email is submitted
                                    FocusScope.of(context).nextFocus();
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    hintText: "Enter your password",
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
                                  onSubmitted: (_) {
                                    // Trigger login when password is submitted
                                    if (!_isLoading) {
                                      login();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Remember Me Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: Colors.green.shade700,
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rememberMe = !_rememberMe;
                                  });
                                },
                                child: const Text(
                                  "Remember my credentials",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _isLoading
                              ? Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Signing you in...",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Login",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Terms, Version and View Logs Links
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        // Privacy Policy Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _openTerms,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.privacy_tip_outlined,
                                      color: Colors.green.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.open_in_new,
                                      color: Colors.green.shade700,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Version
                        if (_appVersion.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Version ${_appVersion.split('.').take(2).join('.')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Hidden Error Logs
                        Opacity(
                          opacity: 0.0,
                          child: GestureDetector(
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
