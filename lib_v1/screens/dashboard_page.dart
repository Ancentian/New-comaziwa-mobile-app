import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

import '../config/app_config.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';
import '../services/sync_service.dart';
import 'login_page.dart';

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

  List<dynamic> dailyData = [];
  List<dynamic> monthlyData = [];

  DateTimeRange? selectedRange;
  bool isLoading = true;

  int totalFarmers = 0;
  int unsyncedCollections = 0;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 4, now.day);
    selectedRange = DateTimeRange(start: start, end: now);

    fetchDashboardData(range: selectedRange);
    _loadSyncStats();

    // Auto refresh every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchDashboardData(range: selectedRange);
        _loadSyncStats();
      }
    });
  }

  Future<void> _loadSyncStats() async {
    final farmersBox = Hive.box<Farmer>('farmers');
    final milkBox = Hive.box<MilkCollection>('milk_collections');

    setState(() {
      totalFarmers = farmersBox.length;
      unsyncedCollections =
          milkBox.values.where((c) => !c.isSynced).length;
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchDashboardData({DateTimeRange? range}) async {
    setState(() => isLoading = true);
    try {
      final token = await _getAuthToken();

      String query = '';
      if (range != null) {
        final start = DateFormat('yyyy-MM-dd').format(range.start);
        final end = DateFormat('yyyy-MM-dd').format(range.end);
        query = '?start_date=$start&end_date=$end';
      }

      final res = await http.get(
        Uri.parse("$apiBase/dashboard_milk_data$query"),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          dailyData = List<dynamic>.from(data['daily'] ?? []);
          monthlyData = List<dynamic>.from(data['monthly'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        Fluttertoast.showToast(
          msg: "Failed to fetch data from server.",
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: Colors.redAccent,
      );
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
          msg: "All data synced successfully", backgroundColor: Colors.green);
    } else {
      Fluttertoast.showToast(
          msg: "Some data could not be synced", backgroundColor: Colors.red);
    }
    _loadSyncStats();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          '${dailyData.fold<double>(0, (p, c) => p + ((c['total_milk'] ?? 0) * 1.0)).toStringAsFixed(2)} L',
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
    );
  }

  Widget _buildGreetingRow(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hello, ${widget.name}!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded,
                color: Colors.green, size: 28),
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
        color: Colors.green.shade700,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.green.shade800),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.green),
              ),
              accountName: Text(
                widget.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: FutureBuilder<Map<String, dynamic>?>(
                future: _getUserProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading...');
                  } else if (snapshot.hasData) {
                    return Text(snapshot.data?['role'] ?? 'User');
                  } else {
                    return const Text('User');
                  }
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  _drawerTile(Icons.person, 'Profile', '/profile'),
                  _drawerTile(Icons.dashboard, 'Dashboard', '/dashboard'),
                  _drawerTile(Icons.local_drink, 'Milk Collection', '/milkCollection'),
                  _drawerTile(Icons.list, 'Milk List', '/milkList'),
                  _drawerTile(Icons.people, 'Members List', '/farmersList'),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _drawerTile(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {double width = 150}) {
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
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

    final maxY = dailyData
        .map((e) => (e['total_milk'] ?? 0) * 1.0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < dailyData.length; i++) {
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (dailyData[i]['total_milk'] ?? 0) * 1.0,
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
      ));
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Daily Milk Collection (Litres)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < dailyData.length) {
                            return Text(
                              DateFormat('MM/dd').format(
                                  DateTime.parse(dailyData[value.toInt()]['date'])),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                    ),
                  ),
                  barGroups: bars,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final date = DateFormat('MM/dd').format(
                            DateTime.parse(dailyData[groupIndex]['date']));
                        return BarTooltipItem(
                          "$date\n${rod.toY} L",
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

    final spots = <FlSpot>[];
    for (int i = 0; i < monthlyData.length; i++) {
      spots.add(FlSpot(i.toDouble(), (monthlyData[i]['total_milk'] ?? 0) * 1.0));
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Monthly Milk Collection Trend",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final months = [
                            'Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'
                          ];
                          return Text(
                            months[value.toInt() % 12],
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 36),
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
                        return touchedSpots.map((spot) {
                          final monthIndex = spot.x.toInt() % 12;
                          final months = [
                            'Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'
                          ];
                          return LineTooltipItem(
                            "${months[monthIndex]}\n${spot.y.toStringAsFixed(2)} L",
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
        0, (sum, item) => sum + ((item['total_morning'] ?? 0) * 1.0));
    final totalEvening = monthlyData.fold<double>(
        0, (sum, item) => sum + ((item['total_evening'] ?? 0) * 1.0));

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
            const Text("Morning vs Evening Milk",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          color: Colors.white),
                    ),
                    PieChartSectionData(
                      color: Colors.blue,
                      value: eveningPercent,
                      title: "Evening\n${eveningPercent.toStringAsFixed(1)}%",
                      radius: 60,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
