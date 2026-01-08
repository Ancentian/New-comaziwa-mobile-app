import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';
import '../services/sync_service.dart';
import '../services/printer_service.dart';
import '../services/auto_print_service.dart';

class MilkCollectionPage extends StatefulWidget {
  const MilkCollectionPage({super.key});

  @override
  State<MilkCollectionPage> createState() => _MilkCollectionPageState();
}

class _MilkCollectionPageState extends State<MilkCollectionPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _memberNoController = TextEditingController();
  final TextEditingController _morningController = TextEditingController(
    text: "0",
  );
  final TextEditingController _eveningController = TextEditingController(
    text: "0",
  );
  final TextEditingController _rejectedController = TextEditingController(
    text: "0",
  );

  // error flags for validation
  bool _morningError = false;
  bool _eveningError = false;
  bool _isSubmitting = false; // Prevent double submission

  double total = 0.0;
  Map<String, dynamic>? farmer;
  double todaysTotal = 0.0;
  double monthlyTotal = 0.0;
  double yearlyTotal = 0.0; // Pre-calculated from API
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

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start automatic syncing
    SyncService().startSyncListener();

    // Note: Milk collections are already synced on dashboard load
    // No need to sync again here for better offline performance
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
    final rejected = double.tryParse(_rejectedController.text) ?? 0;
    setState(() {
      total = morning + evening - rejected;
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// --------------------------------------------------------
  /// Get saved tenant_id (user.id OR employee.tenant_id)
  /// --------------------------------------------------------
  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id'); // Must exist for multi-tenancy
  }

  /// Fetch totals from API for a specific farmer
  Future<void> _fetchTotalsForFarmer(int farmerId) async {
    try {
      final token = await _getAuthToken();
      final tenantId = await _getTenantId();

      if (token != null && tenantId != null) {
        final res = await http.get(
          Uri.parse("$apiBase/find-farmer/$farmerId?tenant_id=$tenantId"),
          headers: {"Authorization": "Bearer $token"},
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          setState(() {
            todaysTotal = (data['todays_total'] ?? 0).toDouble();
            monthlyTotal = (data['monthly_total'] ?? 0).toDouble();
            yearlyTotal = (data['yearly_total'] ?? 0).toDouble();
          });
          print(
            "✅ Totals updated: Today=$todaysTotal, Monthly=$monthlyTotal, Yearly=$yearlyTotal",
          );
        }
      }
    } catch (e) {
      print("⚠️ Could not fetch totals: $e");
    }
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

    // Clear farmer immediately when user continues typing
    if (farmer != null && memberNo != farmer!['farmerID'].toString()) {
      setState(() {
        farmer = null;
        _animationController.reverse();
      });
    }

    // Start a new debounce timer (wait for user to finish typing)
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (memberNo.isEmpty) {
        setState(() {
          farmer = null;
        });
        return;
      }

      final farmersBox = Hive.box<Farmer>('farmers');

      // 🔥 Get grader centers for filtering
      final prefs = await SharedPreferences.getInstance();
      final graderCenters = prefs.getStringList('grader_centers');

      // 1. Try offline search first
      final cached = farmersBox.values.cast<Farmer?>().firstWhere((f) {
        if (f == null || f.farmerId.toString() != memberNo) return false;

        // 🔥 Apply grader filter if user is a grader
        if (graderCenters != null && graderCenters.isNotEmpty) {
          return f.centerId != null &&
              graderCenters.contains(f.centerId.toString());
        }

        return true;
      }, orElse: () => null);

      if (cached != null) {
        setState(() {
          farmer = {
            "farmerID": cached.farmerId,
            "fname": cached.fname,
            "lname": cached.lname,
            "center_name": cached.centerName,
            "contact1": cached.contact,
          };
          // Use offline totals from synced farmer data
          todaysTotal = 0.0; // Today's total needs fresh calculation
          monthlyTotal = cached.monthlyTotal;
          yearlyTotal = cached.yearlyTotal;
        });

        print(
          "✅ Using offline totals: Monthly=$monthlyTotal, Yearly=$yearlyTotal",
        );

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

      final tenantId = await _getTenantId();

      if (token == null) {
        Fluttertoast.showToast(
          msg: "Login required",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (tenantId == null) {
        Fluttertoast.showToast(
          msg: "Missing tenant info. Please login again.",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      try {
        String baseUrl = "$apiBase/find-farmer/$memberNo";
        String url;

        if (baseUrl.contains("?")) {
          url = "$baseUrl&tenant_id=$tenantId";
        } else {
          url = "$baseUrl?tenant_id=$tenantId";
        }

        final res = await http.get(
          Uri.parse(url),
          headers: {"Authorization": "Bearer $token"},
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final f = Farmer.fromJson(data['farmer']);

          // Save offline
          farmersBox.put(f.farmerId, f);

          // Store farmer data with pre-calculated totals from API
          setState(() {
            farmer = data['farmer'];
            todaysTotal = (data['todays_total'] ?? 0).toDouble();
            monthlyTotal = (data['monthly_total'] ?? 0).toDouble();
            yearlyTotal = (data['yearly_total'] ?? 0).toDouble();
          });

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
    // Prevent double submission
    if (_isSubmitting) {
      return;
    }

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
      _isSubmitting = true; // Lock submission
    });

    try {
      // Get current user info
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('type');
      final userId = prefs.getInt('user_id');

      final collection = MilkCollection(
        farmerId: int.parse(farmer!['farmerID'].toString()),
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        morning: morning,
        evening: evening,
        rejected: double.tryParse(_rejectedController.text) ?? 0,
        isSynced: false,
        center_name: farmer!['center_name'],
        fname: farmer!['fname'],
        lname: farmer!['lname'],
        createdById: userId,
        createdByType: userType,
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

      // Auto-print receipt if enabled
      final isAutoPrintOn = AutoPrintService.isAutoPrintEnabled();
      print('🖨️ Auto-print enabled: $isAutoPrintOn');

      if (isAutoPrintOn) {
        print('🖨️ Starting auto-print for farmer ${collection.farmerId}');
        _autoPrintReceipt(collection);
      } else {
        print('⚠️ Auto-print is disabled in settings');
      }

      _resetForm();
    } finally {
      setState(() {
        _isSubmitting = false; // Unlock submission
      });
    }
  }

  /// Auto-print receipt after saving collection - OPTIMIZED for speed
  Future<void> _autoPrintReceipt(MilkCollection collection) async {
    print('🖨️ _autoPrintReceipt called');
    // Fire-and-forget approach: don't await, print in background
    _printInBackground(collection);
  }

  /// Background printing - won't block UI
  Future<void> _printInBackground(MilkCollection collection) async {
    try {
      print('🖨️ Starting background print...');

      // Use cached totals if available (from API response)
      // This is much faster than scanning all Hive records
      final currentTotal =
          collection.morning + collection.evening - collection.rejected;

      // Get company name (cached)
      final prefs = await SharedPreferences.getInstance();
      final companyName = prefs.getString('company_name');
      final servedBy = prefs.getString('name');

      print('🖨️ Building receipt data...');
      // Build receipt data using already-available data
      final receiptData = {
        'farmerID': collection.farmerId.toString(),
        'fname': collection.fname,
        'lname': collection.lname,
        'center_name': collection.center_name,
        'collection_date': collection.date,
        'morning': collection.morning.toString(),
        'evening': collection.evening.toString(),
        'rejected': collection.rejected.toString(),
        'total': currentTotal.toStringAsFixed(2),
        // Use pre-calculated totals from farmer search (much faster)
        'today_total': todaysTotal.toStringAsFixed(2),
        'monthly_total': monthlyTotal.toStringAsFixed(2),
        'yearly_total': yearlyTotal.toStringAsFixed(2),
        'company_name': companyName,
        'served_by': servedBy,
      };

      print('🖨️ Calling PrinterService.printDirectlyFast...');
      // Use direct ESC/POS printing - bypasses widget rendering delays
      final result = await PrinterService.printDirectlyFast(
        receiptData,
        context,
      );
      print('🖨️ Print result: $result');

      if (result) {
        print('✅ Auto-print initiated successfully');
      } else {
        print('⚠️ Auto-print returned false - check printer connection');
      }
    } catch (e, stackTrace) {
      // Silent fail - don't interrupt the save flow
      print('❌ Auto-print failed: $e');
      print('Stack trace: $stackTrace');
    }
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
            // Enhanced Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _memberNoController,
                onChanged: (value) => searchFarmer(value),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Search Farmer by Member Number',
                  hintText: 'e.g., 508',
                  prefixIcon: Icon(
                    Icons.person_search,
                    color: Colors.green.shade700,
                  ),
                  suffixIcon: _memberNoController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _memberNoController.clear();
                            setState(() {
                              farmer = null;
                            });
                          },
                        )
                      : Icon(Icons.search, color: Colors.green.shade300),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (farmer != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _fadeAnimation,
                  child: _buildFarmerCard(),
                ),
              ),

            if (farmer != null) ...[
              const SizedBox(height: 24),
              _buildDateField(),
              const SizedBox(height: 24),
              // Milk Input Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Enter Milk Quantity (Litres)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            _morningController,
                            'Morning',
                            icon: Icons.wb_sunny_outlined,
                            error: _morningError,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInput(
                            _eveningController,
                            'Evening',
                            icon: Icons.nightlight_outlined,
                            error: _eveningError,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInput(
                      _rejectedController,
                      'Rejected (Optional)',
                      icon: Icons.remove_circle_outline,
                    ),
                    const SizedBox(height: 16),
                    // Total Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.calculate,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Total Accepted',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                total.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'L',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Statistics Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Statistics',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Today',
                            todaysTotal,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'This Month',
                            monthlyTotal,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitCollection,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                  label: Text(
                    _isSubmitting ? 'Saving Collection...' : 'Save Collection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 4,
                    shadowColor: Colors.green.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
    // Improved center name extraction: handle both keys and empty values
    String center = '';
    if ((f['center_name'] ?? '').toString().trim().isNotEmpty) {
      center = f['center_name'].toString().trim();
    } else if ((f['centerName'] ?? '').toString().trim().isNotEmpty) {
      center = f['centerName'].toString().trim();
    } else if ((f['center'] ?? '').toString().trim().isNotEmpty) {
      center = f['center'].toString().trim();
    } else {
      center = 'N/A';
    }
    final contact = f['contact1'] ?? f['contact'] ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$fname $lname',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member #$farmerId',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildFarmerInfo(Icons.business, 'Center', center),
                  const Divider(color: Colors.white30, height: 16),
                  _buildFarmerInfo(Icons.phone, 'Contact', contact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
        ),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: 'Collection Date',
          prefixIcon: Icon(Icons.calendar_today, color: Colors.green.shade700),
          suffixIcon: IconButton(
            icon: Icon(Icons.edit_calendar, color: Colors.green.shade700),
            onPressed: _pickDate,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
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

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool error = false,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: error ? Colors.red : Colors.green.shade700,
                size: 20,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: error ? Colors.red : Colors.green.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: error ? Colors.red.shade300 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: error ? Colors.red : Colors.green.shade700,
            width: 2,
          ),
        ),
        fillColor: error ? Colors.red.shade50 : Colors.green.shade50,
        filled: true,
        errorText: error ? 'Required: Must be > 0' : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            builder: (context, val, child) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  val.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
