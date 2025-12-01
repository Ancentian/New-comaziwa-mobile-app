import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:comaziwa/screens/login_page.dart';
import '../config/app_config.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
// import 'bluetooth_device_list_page.dart';

import '../models/record.dart';
import '../services/local_storage_service.dart';

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

    // 🚀 Auto refresh every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchDashboardData(range: selectedRange);
      }
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchDashboardData({DateTimeRange? range}) async {
    setState(() {
      isLoading = true;
    });
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
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Failed to fetch data from server.",
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedRange,
    );

    if (picked != null) {
      setState(() {
        selectedRange = picked;
      });
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
      Uri.parse("$apiBase/employee/profile"), // your API endpoint
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['employee']; // adapt to your API response
    }
  } catch (e) {
    debugPrint("Error fetching profile: $e");
  }
  return null;
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
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout))
        ],
      ),
      
      drawer: Drawer(
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
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.green),
                      title: const Text('Profile'),
                      onTap: () async {
                        final userData = await _getUserProfile();
                        if (userData != null) {
                          Navigator.pushNamed(context, '/profile', arguments: {
                            'name': userData['name'],
                            'email': userData['email'],
                            'phone': userData['phone_no'],
                            'role': userData['role'],
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard, color: Colors.green),
                      title: const Text('Dashboard'),
                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_drink, color: Colors.green),
                      title: const Text('Milk Collection'),
                      onTap: () => Navigator.pushNamed(context, '/milkCollection'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.list, color: Colors.green),
                      title: const Text('Milk List'),
                      onTap: () => Navigator.pushNamed(context, '/milkList'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people, color: Colors.green),
                      title: const Text('Members List'),
                      onTap: () => Navigator.pushNamed(context, '/farmersList'),
                    ),
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
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Print Button
                  // Padding(
                  //   padding:
                  //       const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  //   child: ElevatedButton.icon(
                  //     onPressed: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => const BluetoothDeviceListPage(),
                  //         ),
                  //       );
                  //     },
                  //     icon: const Icon(Icons.print),
                  //     label: const Text("Print Milk Report"),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.green,
                  //       minimumSize: Size(screenWidth, 50),
                  //       shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12)),
                  //     ),
                  //   ),
                  // ),

                  // Greeting + Filter
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ),

                  // Stat Cards
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Charts
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

  // Stat Card
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

  // Daily Bar Chart
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

  // Monthly Line Chart
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
                        return touchedSpots.map((spot) {
                          final monthIndex = spot.x.toInt() % 12;
                          final months = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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

  // Milk Pie Chart
  Widget _buildMilkPieChart() {
    if (monthlyData.isEmpty) return const SizedBox.shrink();

    final totalMorning = monthlyData.fold<double>(
        0, (sum, item) => sum + ((item['total_morning'] ?? 0) * 1.0));
    final totalEvening = monthlyData.fold<double>(
        0, (sum, item) => sum + ((item['total_evening'] ?? 0) * 1.0));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Milk Distribution (Litres)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: totalMorning,
                      title: 'Morning',
                      color: Colors.green,
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: totalEvening,
                      title: 'Evening',
                      color: Colors.blue,
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
