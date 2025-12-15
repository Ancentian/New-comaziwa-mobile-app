import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String role;

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _passwordController = TextEditingController();
    _passwordConfirmController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final response = await ApiService.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
      passwordConfirmation: _passwordConfirmController.text.trim(),
    );

    setState(() => isLoading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
      _passwordController.clear();
      _passwordConfirmController.clear();
    } else if (response['errors'] != null) {
      final errors = response['errors'] as Map<String, dynamic>;
      final errorMsg = errors.values.map((e) => e[0]).join('\n');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMsg)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Error updating profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.green.shade200,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.role,
                      style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Phone",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Phone required' : null,
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Change Password",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordConfirmController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (_passwordController.text.isNotEmpty &&
                          value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Update Profile"),
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
