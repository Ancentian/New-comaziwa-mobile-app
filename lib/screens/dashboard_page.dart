import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';
import '../services/sync_service.dart';
import '../services/farmer_service.dart';
import '../utils/theme_provider.dart';
import '../widgets/shimmer_loading.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'printer_settings_page.dart';

class DashboardPage extends StatefulWidget {
  final String name;
  const DashboardPage({super.key, required this.name});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late String apiBase;
  String? savedName;

  List<dynamic> dailyData = [];
  List<dynamic> monthlyData = [];

  DateTimeRange? selectedRange;
  bool isLoading = true;
  bool isFetchingData = false;

  int totalFarmers = 0;
  int unsyncedCollections = 0;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";

    _loadSavedName();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    final now = DateTime.now();
    // For monthly data: Start from first day of the month 5 months ago (current + 5 past = 6 months)
    final start = DateTime(now.year, now.month - 5, 1);
    selectedRange = DateTimeRange(start: start, end: now);

    fetchDashboardData(range: selectedRange);
    _loadSyncStats();

    // Listen to milk collection changes for real-time sync count updates
    final milkBox = Hive.box<MilkCollection>('milk_collections');
    milkBox.listenable().addListener(() {
      if (mounted) {
        _loadSyncStats();
      }
    });

    // Single periodic timer
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        fetchDashboardData(range: selectedRange);
        _loadSyncStats();
      }
    });

    // Central sync point: Download all data when user connects online
    // This enables offline work for milk graders who sync once, then work without connectivity
    Future.delayed(Duration.zero, () async {
      Fluttertoast.showToast(msg: "Syncing data...");

      // Sync farmers - Required for offline milk collection
      final farmersDownloaded = await FarmerService().downloadFarmers();

      // Sync milk collections - Required for accurate historical totals on receipts
      final collectionsDownloaded = await SyncService()
          .downloadMilkCollections();

      if (!mounted) return;

      if (farmersDownloaded && collectionsDownloaded) {
        Fluttertoast.showToast(
          msg: "All data synced successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else if (farmersDownloaded || collectionsDownloaded) {
        Fluttertoast.showToast(
          msg: "Some data synced",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Sync incomplete",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSyncStats() async {
    final farmersBox = Hive.box<Farmer>('farmers');
    final milkBox = Hive.box<MilkCollection>('milk_collections');

    final newTotalFarmers = farmersBox.length;
    final newUnsynced = milkBox.values.where((c) => !c.isSynced).length;

    if (newTotalFarmers != totalFarmers || newUnsynced != unsyncedCollections) {
      setState(() {
        totalFarmers = newTotalFarmers;
        unsyncedCollections = newUnsynced;
      });
    }
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedName =
          prefs.getString('name') ??
          prefs.getString('full_name') ??
          prefs.getString('user_name') ??
          widget.name;
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ??
        prefs.getString('token') ??
        prefs.getString('access_token');
  }

  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id');
  }

  /// Debug function: Check Hive data and API status
  /// Call this to verify milk collections were downloaded successfully
  Future<void> _debugCheckData() async {
    try {
      print('\n🔍 ═══════════════════════════════════════════════════════');
      print('📊 HIVE & API DEBUG CHECK');
      print('═══════════════════════════════════════════════════════');

      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final tenantId = prefs.getInt('tenant_id');
      print('\n✅ SharedPreferences Status:');
      print(
        '   Token: ${token != null ? '✓ Exists (${token.length} chars)' : '✗ Missing'}',
      );
      print('   Tenant ID: ${tenantId ?? '✗ Missing'}');

      // Check Hive farmers
      final farmerBox = Hive.box<Farmer>('farmers');
      print('\n✅ Farmers Hive:');
      print('   Total records: ${farmerBox.length}');
      if (farmerBox.isNotEmpty) {
        final f = farmerBox.values.first;
        print('   Sample: ${f.fname} ${f.lname} (ID: ${f.farmerId})');
      }

      // Check Hive milk collections
      final milkBox = Hive.box<MilkCollection>('milk_collections');
      print('\n✅ Milk Collections Hive:');
      print('   Total records: ${milkBox.length}');
      if (milkBox.isEmpty) {
        print('   ⚠️  WARNING: Hive is EMPTY!');
        print('   → This is why totals show 0');
        print('   → Check: 1) API endpoint 2) Database records 3) Tenant ID');
      } else {
        final synced = milkBox.values.where((m) => m.isSynced).length;
        final unsynced = milkBox.values.where((m) => !m.isSynced).length;
        print('   Synced: $synced, Unsynced: $unsynced');

        // Show sample records
        print('   📋 Latest 3 records:');
        final sorted = milkBox.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        for (var i = 0; i < sorted.length.clamp(0, 3); i++) {
          final m = sorted[i];
          print(
            '     [$i] ${m.date}: Farmer ${m.farmerId}, '
            '${m.morning}L + ${m.evening}L - ${m.rejected}L = ${m.morning + m.evening - m.rejected}L',
          );
        }
      }

      // Test API endpoint (if token exists)
      if (token != null && tenantId != null) {
        print('\n✅ Testing API Endpoint:');
        try {
          final apiBase = "${AppConfig.baseUrl}/api";
          final url = Uri.parse(
            "$apiBase/milk-collections-sync?tenant_id=$tenantId&limit=5",
          );
          print('   URL: $url');

          final response = await http
              .get(url, headers: {'Authorization': 'Bearer $token'})
              .timeout(const Duration(seconds: 5));

          print('   Status: ${response.statusCode}');
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final count = (data['data'] as List?)?.length ?? 0;
            print('   ✅ API Response: $count records returned');
            if (count == 0) {
              print('   ⚠️  API returned empty data - check database records');
            }
          } else {
            print('   ❌ API Error: ${response.statusCode}');
            print('   Response: ${response.body.substring(0, 200)}...');
          }
        } catch (e) {
          print('   ❌ API Test Failed: $e');
        }
      }

      print('═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Debug check error: $e');
    }
  }

  DateTime _parseMonth(dynamic monthValue) {
    if (monthValue == null) return DateTime.now();
    final str = monthValue.toString().trim();

    if (str.contains("-")) {
      final parts = str.split("-");
      final year = int.tryParse(parts[0]) ?? DateTime.now().year;
      final month = int.tryParse(parts[1]) ?? 1;
      return DateTime(year, month, 1);
    }

    final m = int.tryParse(str);
    if (m != null && m >= 1 && m <= 12) {
      return DateTime(DateTime.now().year, m, 1);
    }

    try {
      return DateTime.parse(str);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> fetchDashboardData({DateTimeRange? range}) async {
    if (isFetchingData) return;
    isFetchingData = true;
    setState(() => isLoading = true);

    try {
      final token = await _getAuthToken();
      final tenantId = await _getTenantId();
      if (tenantId == null) {
        Fluttertoast.showToast(
          msg: "Missing tenant info. Please login again.",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      String query = '';
      if (range != null) {
        final start = DateFormat('yyyy-MM-dd').format(range.start);
        final end = DateFormat('yyyy-MM-dd').format(range.end);
        query =
            '?start_date=$start&end_date=$end&monthly_limit=6&daily_limit=7';
      }

      String url = "$apiBase/dashboard_milk_data$query";
      url += query.contains("?")
          ? "&tenant_id=$tenantId"
          : "?tenant_id=$tenantId";

      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = await compute(jsonDecode, res.body);
        if (!mounted) return;
        setState(() {
          dailyData = List<dynamic>.from(data['daily'] ?? []);
          monthlyData = List<dynamic>.from(data['monthly'] ?? []);
        });
      } else {
        Fluttertoast.showToast(
          msg: "Failed to fetch data from server.",
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
      isFetchingData = false;
    }
  }

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedRange,
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
      fetchDashboardData(range: picked);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserProfile() async {
    final token = await _getAuthToken();
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse("$apiBase/employee/profile"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['employee'];
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
    return null;
  }

  Future<void> _syncNow() async {
    Fluttertoast.showToast(msg: "Syncing...", backgroundColor: Colors.green);
    final success = await SyncService().syncAll();
    if (success) {
      Fluttertoast.showToast(
        msg: "All data synced successfully",
        backgroundColor: Colors.green,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Some data could not be synced",
        backgroundColor: Colors.red,
      );
    }
    _loadSyncStats();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const ShimmerCardGrid()
          : RefreshIndicator(
              onRefresh: () async {
                await fetchDashboardData(range: selectedRange);
                await _loadSyncStats();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreetingRow(screenWidth),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatCard(
                            'Total Milk',
                            '${dailyData.fold<double>(0, (p, c) => p + ((c['total_milk'] ?? c['total'] ?? 0) * 1.0)).toStringAsFixed(0)} L',
                            Icons.local_drink,
                            Colors.green,
                            width: (screenWidth - 48) / 2,
                          ),
                          _buildStatCard(
                            'Collections',
                            '${dailyData.length}',
                            Icons.add,
                            Colors.orange,
                            width: (screenWidth - 48) / 2,
                          ),
                          _buildStatCard(
                            'Direct',
                            '${(dailyData.length / 2).ceil()}',
                            Icons.send,
                            Colors.blue,
                            width: (screenWidth - 48) / 2,
                          ),
                          _buildStatCard(
                            'Farmers',
                            '$totalFarmers',
                            Icons.people,
                            Colors.purple,
                            width: (screenWidth - 48) / 2,
                          ),
                          _buildStatCard(
                            'Unsynced',
                            '$unsyncedCollections',
                            Icons.sync,
                            Colors.red,
                            width: (screenWidth - 48) / 2,
                          ),
                          GestureDetector(
                            onTap: _syncNow,
                            child: _buildStatCard(
                              'Sync Now',
                              'Tap to sync',
                              Icons.cloud_upload,
                              Colors.teal,
                              width: (screenWidth - 48) / 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildMonthlyLineChart(),
                          const SizedBox(height: 20),
                          _buildDailyBarChart(),
                          const SizedBox(height: 20),
                          _buildMilkPieChart(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGreetingRow(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hello, ${savedName ?? "User"}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.filter_alt_rounded,
              color: Colors.green,
              size: 28,
            ),
            tooltip: 'Filter by Date',
            onPressed: pickDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF2E7D32), // Dark green background
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 30,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    savedName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(top: 20),
                  children: [
                    _drawerTile(Icons.person_outline, 'Profile', '/profile'),
                    _drawerTile(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      '/dashboard',
                    ),
                    _drawerTile(
                      Icons.local_drink_outlined,
                      'Milk Collection',
                      '/milkCollection',
                    ),
                    _drawerTile(Icons.list_alt, 'Milk List', '/milkList'),
                    _drawerTile(
                      Icons.people_outline,
                      'Members List',
                      '/farmersList',
                    ),
                    _drawerTile(
                      Icons.summarize_outlined,
                      'Daily Summary',
                      '/dailySummary',
                    ),
                    const Divider(height: 1, thickness: 1),
                    _drawerTile(
                      Icons.print_outlined,
                      'Printer Settings',
                      null,
                      isPrinter: true,
                    ),
                    Opacity(
                      opacity: 0.0,
                      child: Column(
                        children: [
                          const Divider(height: 1, thickness: 1),
                          _drawerTile(
                            Icons.bug_report,
                            'Debug: Check Data',
                            null,
                            isDebug: true,
                          ),
                        ],
                      ),
                    ),
                    _drawerTile(Icons.logout, 'Logout', null, isLogout: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _drawerTile(
    IconData icon,
    String title,
    String? route, {
    bool isPrinter = false,
    bool isLogout = false,
    bool isDebug = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : isDebug
            ? Colors.orange
            : const Color(0xFF2E7D32),
        size: 26,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isLogout
              ? Colors.red
              : isDebug
              ? Colors.orange
              : Colors.black87,
        ),
      ),
      onTap: () async {
        Navigator.pop(context); // close drawer

        if (isLogout) {
          _logout();
          return;
        }

        if (isDebug) {
          await _debugCheckData();
          Fluttertoast.showToast(
            msg: "Check console logs for debug info",
            backgroundColor: Colors.orange,
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }

        if (isPrinter) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PrinterSettingsPage()),
          );
          return;
        }

        if (route == '/profile') {
          // Try to fetch profile from API
          final profile = await _getUserProfile();
          if (profile != null) {
            final displayName =
                profile['name'] ??
                profile['full_name'] ??
                profile['username'] ??
                '';
            final email = profile['email'] ?? '';
            final phone = profile['phone'] ?? profile['mobile'] ?? '';
            final role = profile['role'] ?? profile['position'] ?? '';

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(
                  name: displayName,
                  email: email,
                  phone: phone,
                  role: role,
                ),
              ),
            );
            return;
          }

          // Fallback: use saved prefs if API failed
          final prefs = await SharedPreferences.getInstance();
          final savedName =
              prefs.getString('name') ??
              prefs.getString('full_name') ??
              prefs.getString('user_name') ??
              '';
          final savedEmail = prefs.getString('email') ?? '';
          final savedPhone = prefs.getString('phone') ?? '';
          final savedRole = prefs.getString('role') ?? '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                name: savedName,
                email: savedEmail,
                phone: savedPhone,
                role: savedRole,
              ),
            ),
          );
          return;
        }

        if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    double width = 150,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------ Charts ------------------------
  Widget _buildDailyBarChart() {
    if (dailyData.isEmpty) return const SizedBox.shrink();

    // Show only last 7 days
    final limitedData = dailyData.length > 7
        ? dailyData.sublist(dailyData.length - 7)
        : dailyData;

    final maxY = limitedData
        .map((e) => (e['total_milk'] ?? e['total'] ?? 0) * 1.0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < limitedData.length; i++) {
      final item = limitedData[i];
      double y = 0;
      try {
        y = (item['total_milk'] ?? item['total'] ?? 0) * 1.0;
      } catch (_) {
        y = 0;
      }

      // safe parse date label
      String label = '';
      try {
        final d = DateTime.parse(item['date'].toString());
        label = DateFormat('MM/dd').format(d);
      } catch (_) {
        label = item['date']?.toString() ?? '';
      }

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              // color property is used by fl_chart - keep default color handling here
              color: Colors.green,
              width: 16,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Daily Milk Collection (Litres)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= limitedData.length) {
                            return const Text('');
                          }
                          final raw =
                              limitedData[idx]['date']?.toString() ?? '';
                          try {
                            final d = DateTime.parse(raw);
                            return Transform.rotate(
                              angle: -0.785398, // -45 degrees in radians
                              child: Text(
                                DateFormat('MM/dd').format(d),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          } catch (_) {
                            return Transform.rotate(
                              angle: -0.785398,
                              child: Text(
                                raw,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                      ),
                    ),
                  ),
                  barGroups: bars,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        if (idx < 0 || idx >= limitedData.length) {
                          return null;
                        }
                        final rawDate =
                            limitedData[idx]['date']?.toString() ?? '';
                        String dateLabel;
                        try {
                          final d = DateTime.parse(rawDate);
                          dateLabel = DateFormat('MMM dd, yyyy').format(d);
                        } catch (_) {
                          dateLabel = rawDate;
                        }
                        return BarTooltipItem(
                          "$dateLabel\n${rod.toY.toStringAsFixed(2)} L",
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyLineChart() {
    if (monthlyData.isEmpty) return const SizedBox.shrink();

    // Show only last 6 months
    final limitedMonthly = monthlyData.length > 6
        ? monthlyData.sublist(monthlyData.length - 6)
        : monthlyData;

    final spots = <FlSpot>[];
    final monthLabels = <String>[];

    for (int i = 0; i < limitedMonthly.length; i++) {
      final m = limitedMonthly[i];

      // determine the month token in the API response
      final monthToken = m['month'] ?? m['month_name'] ?? m['m'] ?? m['label'];
      final parsed = _parseMonth(monthToken);

      final label = DateFormat('MMM yyyy').format(parsed);
      monthLabels.add(label);

      // flexible total field names
      final totalVal = (m['total_milk'] ?? m['total'] ?? m['totalMilk'] ?? 0);
      final y = double.tryParse(totalVal.toString()) ?? 0.0;

      spots.add(FlSpot(i.toDouble(), y));
    }

    // adjust view if needed
    final minX = 0.0;
    final maxX = (spots.isNotEmpty) ? spots.last.x : 0.0;
    final maxY = spots.fold<double>(0.0, (prev, s) => s.y > prev ? s.y : prev);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Monthly Milk Collection Trend",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: (maxY * 1.2).clamp(1.0, double.infinity),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= monthLabels.length) {
                            return const Text('');
                          }
                          return Transform.rotate(
                            angle: -0.785398, // -45 degrees in radians
                            child: Text(
                              monthLabels[idx],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 4,
                      spots: spots,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.2),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spotItem) {
                          final idx = spotItem.x.toInt();
                          final label = (idx >= 0 && idx < monthLabels.length)
                              ? monthLabels[idx]
                              : '';
                          return LineTooltipItem(
                            "$label\n${spotItem.y.toStringAsFixed(2)} L",
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilkPieChart() {
    if (monthlyData.isEmpty) return const SizedBox.shrink();

    final totalMorning = monthlyData.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['total_morning'] ?? item['morning'] ?? 0) * 1.0),
    );
    final totalEvening = monthlyData.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['total_evening'] ?? item['evening'] ?? 0) * 1.0),
    );

    final total = totalMorning + totalEvening;
    if (total == 0) return const SizedBox.shrink();

    final morningPercent = totalMorning / total * 100;
    final eveningPercent = totalEvening / total * 100;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Morning vs Evening Milk",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.orange,
                      value: morningPercent,
                      title: "Morning\n${morningPercent.toStringAsFixed(1)}%",
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.blue,
                      value: eveningPercent,
                      title: "Evening\n${eveningPercent.toStringAsFixed(1)}%",
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
