import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class FarmerDetailPage extends StatefulWidget {
  final int farmerId;

  const FarmerDetailPage({super.key, required this.farmerId});

  @override
  State<FarmerDetailPage> createState() => _FarmerDetailPageState();
}

class _FarmerDetailPageState extends State<FarmerDetailPage> {
  Map<String, dynamic>? farmer;
  List<dynamic> milkCollection = [];
  bool isLoading = true;
  late String apiBase;
  DateTimeRange? selectedRange;
  double totalMilk = 0;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";
    final now = DateTime.now();
    selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    fetchFarmerDetail();

    // 🚀 Auto refresh every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchFarmerDetail();
      }
    });
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchFarmerDetail() async {
    final token = await _getAuthToken();
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final queryParams = {
        'start_date': DateFormat('yyyy-MM-dd').format(selectedRange!.start),
        'end_date': DateFormat('yyyy-MM-dd').format(selectedRange!.end),
      };

      final uri = Uri.parse("$apiBase/farmer/${widget.farmerId}")
          .replace(queryParameters: queryParams);

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final milkData = data['data']['milkCollection'] ?? [];

        double sum = 0;
        for (var m in milkData) {
          sum += (m['total'] ?? 0).toDouble();
        }

        setState(() {
          farmer = data['data']['farmer'];
          milkCollection = milkData;
          totalMilk = sum;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        Fluttertoast.showToast(msg: "Failed to load farmer details");
      }
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
    );

    if (picked != null) {
      setState(() => selectedRange = picked);
      fetchFarmerDetail();
    }
  }

  List<BarChartGroupData> getBarGroups() {
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < milkCollection.length; i++) {
      final total = (milkCollection[i]['total'] ?? 0).toDouble();
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total,
              color: Colors.green,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Farmer Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: "Filter by Date",
            onPressed: pickDateRange,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : farmer == null
              ? const Center(child: Text("No details found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -------- FARMER INFO CARD --------
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${farmer!['fname'] ?? '--'} ${farmer!['lname'] ?? '--'}",
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: (farmer!['status']?.toString() == "1")
                                          ? Colors.lightGreen
                                          : Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    (farmer!['status']?.toString() == "1")
                                        ? "Active"
                                        : "Inactive",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Farmer ID: ${farmer!['farmerID'] ?? '--'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "Contact: ${farmer!['contact1'] ?? '--'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "Center: ${farmer!['center']?['center_name'] ?? '--'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "Bank: ${farmer!['bank']?['bank_name'] ?? '--'}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Total Milk: ${totalMilk.toStringAsFixed(2)} L",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -------- DATE RANGE HEADER --------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Milk Collection (${DateFormat('yyyy-MM-dd').format(selectedRange!.start)} - ${DateFormat('yyyy-MM-dd').format(selectedRange!.end)})",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                              icon: const Icon(Icons.filter_alt_rounded,
                                  color: Colors.green),
                              onPressed: pickDateRange)
                        ],
                      ),
                      const SizedBox(height: 12),

                      // -------- BAR CHART --------
milkCollection.isEmpty
    ? const Center(child: Text("No milk collection data"))
    : Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                "Daily Collection Trend",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),

                    // ---- TITLES (BOTTOM & LEFT) ----
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < milkCollection.length) {
                              return Text(
                                DateFormat('E').format(
                                  DateTime.parse(milkCollection[index]['date']),
                                ), // Mon, Tue...
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                    ),

                    // ---- BAR DATA ----
                    barGroups: List.generate(
                      milkCollection.length,
                      (i) {
                        final total = (milkCollection[i]['total'] ?? 0).toDouble();

                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: total,
                              width: 16,
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),

                              // Background bar (same as your provided design)
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: milkCollection
                                        .map<double>((e) => (e['total'] ?? 0).toDouble())
                                        .reduce((a, b) => a > b ? a : b) +
                                    5,
                                color: Colors.green.withOpacity(0.2),
                              ),
                            ),
                          ],
                        );
                      },
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
    );
  }
}
