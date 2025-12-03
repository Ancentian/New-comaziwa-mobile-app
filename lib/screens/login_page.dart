import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/farmer_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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
      final response = await http.post(url, body: {
        'email': email,
        'password': password,
      });

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          // Save token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user_email', email);

          Fluttertoast.showToast(msg: "Login successful");

          // -----------------------------
          // 🔥 STEP 1: SYNC FARMERS
          // -----------------------------
          Fluttertoast.showToast(msg: "Syncing farmers...");

          // await FarmerService().fetchAllFarmers();
          bool downloaded = await FarmerService().downloadFarmers();
          if (!downloaded) {
            Fluttertoast.showToast(
              msg: "Please go online to fetch farmers first",
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          }

          // -----------------------------
          // 🔥 STEP 2: GO TO DASHBOARD
          // -----------------------------
          Navigator.pushReplacementNamed(context, '/dashboard');

        } else {
          Fluttertoast.showToast(msg: data['message'] ?? "Login failed");
        }
      } else {
        Fluttertoast.showToast(
            msg: "Server Error (${response.statusCode})");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Network error: $e");
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
                      horizontal: 24, vertical: 32),
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
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline),
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
                                  backgroundColor: Colors.blue,
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
            ],
          ),
        ),
      ),
    );
  }
}
