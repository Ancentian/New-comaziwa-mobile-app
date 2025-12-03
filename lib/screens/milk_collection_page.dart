import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';
import '../services/sync_service.dart';

class MilkCollectionPage extends StatefulWidget {
  const MilkCollectionPage({super.key});

  @override
  State<MilkCollectionPage> createState() => _MilkCollectionPageState();
}

class _MilkCollectionPageState extends State<MilkCollectionPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController _memberNoController = TextEditingController();
  final TextEditingController _morningController = TextEditingController(text: "0");
  final TextEditingController _eveningController = TextEditingController(text: "0");
  final TextEditingController _rejectedController = TextEditingController(text: "0");

  // error flags for validation
  bool _morningError = false;
  bool _eveningError = false;

  double total = 0.0;
  Map<String, dynamic>? farmer;
  double todaysTotal = 0.0;
  double monthlyTotal = 0.0;
  DateTime selectedDate = DateTime.now();

  late final String apiBase;
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";

    _morningController.addListener(_calculateTotal);
    _eveningController.addListener(_calculateTotal);
    _rejectedController.addListener(_calculateTotal);

    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start automatic syncing
    SyncService().startSyncListener();
  }

  @override
  void dispose() {
    _memberNoController.dispose();
    _morningController.dispose();
    _eveningController.dispose();
    _rejectedController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final morning = double.tryParse(_morningController.text) ?? 0;
    final evening = double.tryParse(_eveningController.text) ?? 0;
    setState(() {
      total = morning + evening;
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // /// Offline-first farmer search
  // Future<void> searchFarmer(String memberNo) async {
  //   if (memberNo.isEmpty) return;

  //   final farmersBox = Hive.box<Farmer>('farmers');

  //   // 1. Try offline search
  //   final cached = farmersBox.values.cast<Farmer?>().firstWhere(
  //         (f) => f != null && f.farmerId.toString() == memberNo,
  //         orElse: () => null,
  //       );

  //   if (cached != null) {
  //     setState(() {
  //       farmer = {
  //         "farmerID": cached.farmerId,
  //         "fname": cached.fname,
  //         "lname": cached.lname,
  //         "center_name": cached.centerName,
  //         "contact1": cached.contact,
  //       };
  //     });
  //     Fluttertoast.showToast(
  //       msg: "Farmer loaded offline",
  //       backgroundColor: Colors.green,
  //       textColor: Colors.white,
  //     );
  //     _animationController.forward(from: 0);
  //     return;
  //   }

  //   // 2. Online search
  //   _debounce?.cancel();
  //   _debounce = Timer(const Duration(milliseconds: 500), () async {
  //     final token = await _getAuthToken();
  //     if (token == null) {
  //       Fluttertoast.showToast(
  //         msg: "Login required",
  //         backgroundColor: Colors.red,
  //         textColor: Colors.white,
  //       );
  //       return;
  //     }

  //     try {
  //       final res = await http.get(
  //         Uri.parse("$apiBase/find-farmer/$memberNo"),
  //         headers: {"Authorization": "Bearer $token"},
  //       );

  //       if (res.statusCode == 200) {
  //         final data = json.decode(res.body);
  //         final f = Farmer.fromJson(data['farmer']);

  //         // Save offline
  //         farmersBox.put(f.farmerId, f);

  //         setState(() => farmer = data['farmer']);
  //         Fluttertoast.showToast(
  //           msg: "Farmer loaded online",
  //           backgroundColor: Colors.green,
  //           textColor: Colors.white,
  //         );
  //         _animationController.forward(from: 0);
  //       } else {
  //         Fluttertoast.showToast(
  //           msg: "Farmer not found",
  //           backgroundColor: Colors.red,
  //           textColor: Colors.white,
  //         );
  //       }
  //     } catch (_) {
  //       Fluttertoast.showToast(
  //         msg: "No internet — offline search only",
  //         backgroundColor: Colors.orange,
  //         textColor: Colors.white,
  //       );
  //     }
  //   });
  // }
  /// Offline-first farmer search with debounce
Future<void> searchFarmer(String memberNo) async {
  // Cancel any previous debounce
  _debounce?.cancel();

  // Start a new debounce timer
  _debounce = Timer(const Duration(milliseconds: 400), () async {
    if (memberNo.isEmpty) return;

    final farmersBox = Hive.box<Farmer>('farmers');

    // 1. Try offline search first
    final cached = farmersBox.values.cast<Farmer?>().firstWhere(
      (f) => f != null && f.farmerId.toString() == memberNo,
      orElse: () => null,
    );

    if (cached != null) {
      setState(() {
        farmer = {
          "farmerID": cached.farmerId,
          "fname": cached.fname,
          "lname": cached.lname,
          "center_name": cached.centerName,
          "contact1": cached.contact,
        };
      });
      Fluttertoast.showToast(
        msg: "Farmer loaded offline",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      _animationController.forward(from: 0);
      return; // Stop here if found offline
    }

    // 2. Online search if not found offline
    final token = await _getAuthToken();
    if (token == null) {
      Fluttertoast.showToast(
        msg: "Login required",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final res = await http.get(
        Uri.parse("$apiBase/find-farmer/$memberNo"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final f = Farmer.fromJson(data['farmer']);

        // Save offline
        farmersBox.put(f.farmerId, f);

        setState(() => farmer = data['farmer']);
        Fluttertoast.showToast(
          msg: "Farmer loaded online",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        _animationController.forward(from: 0);
      } else {
        Fluttertoast.showToast(
          msg: "Farmer not found",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (_) {
      Fluttertoast.showToast(
        msg: "No internet — offline search only",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  });
}


  /// Submit milk collection (offline-first, sync later)
  Future<void> _submitCollection() async {
  if (farmer == null) {
    Fluttertoast.showToast(msg: "Please select farmer");
    return;
  }

  double morning = double.tryParse(_morningController.text) ?? 0;
  double evening = double.tryParse(_eveningController.text) ?? 0;

  // ============================
  //  VALIDATION RULE
  // ============================
  if (morning <= 0 && evening <= 0) {
    setState(() {
      _morningError = true;
      _eveningError = true;
    });

    Fluttertoast.showToast(
      msg: "Morning or Evening must be greater than 0",
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
    return; // STOP submission
  }

  setState(() {
    _morningError = false;
    _eveningError = false;
  });

  final collection = MilkCollection(
    farmerId: int.parse(farmer!['farmerID'].toString()),
    date: DateFormat('yyyy-MM-dd').format(selectedDate),
    morning: morning,
    evening: evening,
    rejected: double.tryParse(_rejectedController.text) ?? 0,
    isSynced: false,
  );

  // Save offline
  final box = Hive.box<MilkCollection>('milk_collections');
  await box.add(collection);

  bool success = await SyncService().syncCollections();
  Fluttertoast.showToast(
    msg: success ? "Collection synced!" : "Saved offline",
    backgroundColor: success ? Colors.green : Colors.orange,
    textColor: Colors.white,
  );

  _resetForm();
}


  void _resetForm() {
    _morningController.text = '0';
    _eveningController.text = '0';
    _rejectedController.text = '0';
    setState(() {
      total = 0;
      farmer = null;
      _memberNoController.clear();
      todaysTotal = 0;
      monthlyTotal = 0;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  /// ----------------------------
  /// UI BUILD
  /// ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Collection Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              bool success = await SyncService().syncCollections();
              Fluttertoast.showToast(
                msg: success ? "Collections synced!" : "No collections to sync",
                backgroundColor: success ? Colors.green : Colors.orange,
                textColor: Colors.white,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Member input
            TextField(
              controller: _memberNoController,
              onChanged: (value) => searchFarmer(value),
              decoration: InputDecoration(
                labelText: 'Enter Member Number',
                suffixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            if (farmer != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _fadeAnimation,
                  child: _buildFarmerCard(),
                ),
              ),

            if (farmer != null) ...[
              const SizedBox(height: 20),
              _buildDateField(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildInput(_morningController, 'Morning (L)')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput(_eveningController, 'Evening (L)')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput(_rejectedController, 'Rejected (L)')),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildStatCard('Today', todaysTotal, Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('Month', monthlyTotal, Colors.blue)),
                ],
              ),
              const SizedBox(height: 20),

              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: total),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return _buildTotalField(value);
                },
              ),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _submitCollection,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Save Collection',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerCard() {
    final f = farmer ?? {};
    final fname = f['fname'] ?? '';
    final lname = f['lname'] ?? '';
    final farmerId = f['farmerID'] ?? f['farmer_id'] ?? 'N/A';
    final center = f['center_name'] ?? 'N/A';
    final contact = f['contact1'] ?? 'N/A';

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.green.shade200,
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fname $lname',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text("Member No.: $farmerId"),
                Text("Center: $center"),
                Text("Phone: $contact"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextField(
      readOnly: true,
      controller: TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(selectedDate)),
      decoration: InputDecoration(
        labelText: 'Collection Date',
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: _pickDate,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Widget _buildInput(TextEditingController controller, String label) {
  //   return TextField(
  //     controller: controller,
  //     decoration: InputDecoration(
  //       labelText: label,
  //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  //       fillColor: Colors.green.shade50,
  //       filled: true,
  //     ),
  //     keyboardType: TextInputType.number,
  //   );
  // }

  Widget _buildInput(TextEditingController controller, String label, {bool error = false}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      fillColor: Colors.green.shade50,
      filled: true,
      errorText: error ? 'Value must be > 0' : null,
    ),
    keyboardType: TextInputType.number,
  );
}


  Widget _buildTotalField(double value) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Total (L)',
        filled: true,
        fillColor: Colors.green.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      controller: TextEditingController(text: value.toStringAsFixed(2)),
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            builder: (context, val, child) => Text(val.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
