import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../services/printer_service.dart';

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

  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id');
  }

  Future<void> fetchFarmerDetail() async {
    final token = await _getAuthToken();
    if (token == null) return;

    final tenantId = await _getTenantId();
    if (tenantId == null) {
      Fluttertoast.showToast(
        msg: "Missing tenant info. Please login again.",
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final queryParams = {
        'tenant_id': tenantId.toString(),
        'start_date': DateFormat('yyyy-MM-dd').format(selectedRange!.start),
        'end_date': DateFormat('yyyy-MM-dd').format(selectedRange!.end),
      };

      final uri = Uri.parse(
        "$apiBase/farmer/${widget.farmerId}",
      ).replace(queryParameters: queryParams);

      final res = await http
          .get(uri, headers: {"Authorization": "Bearer $token"})
          .timeout(const Duration(seconds: 10));

      List<dynamic> serverData = [];
      Map<String, dynamic>? farmerData;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        farmerData = data['data']['farmer'];
        serverData = data['data']['milkCollection'] ?? [];
      }

      // Merge with local unsynced data from Hive
      final localData = await _getLocalCollections();

      // Combine server and local data
      final allCollections = [...serverData, ...localData];

      // Remove duplicates and sort by date
      final uniqueCollections = <String, dynamic>{};
      for (var item in allCollections) {
        final dateKey = item['date'];
        if (!uniqueCollections.containsKey(dateKey)) {
          uniqueCollections[dateKey] = item;
        }
      }

      final sortedCollections = uniqueCollections.values.toList()
        ..sort((a, b) => a['date'].compareTo(b['date']));

      // Calculate total milk
      double sum = 0;
      for (var m in sortedCollections) {
        sum += (m['total'] ?? 0).toDouble();
      }

      setState(() {
        farmer = farmerData;
        milkCollection = sortedCollections;
        totalMilk = sum;
        isLoading = false;
      });
    } catch (e) {
      // If online fetch fails, try local data only
      print("API error: $e");

      // Load farmer details from local Hive
      try {
        final farmersBox = Hive.box<dynamic>('farmers');
        final localFarmer = farmersBox.get(widget.farmerId);

        if (localFarmer != null) {
          // Convert Hive Farmer object to Map for UI compatibility
          final farmerData = {
            'fname': localFarmer.fname ?? '',
            'lname': localFarmer.lname ?? '',
            'farmerID': localFarmer.farmerId,
            'contact1': localFarmer.contact ?? '',
            'center': {'center_name': localFarmer.centerName ?? 'N/A'},
            'bank': {'bank_name': 'N/A'},
            'status': '1', // Assume active
          };

          final localData = await _getLocalCollections();

          double sum = 0;
          for (var m in localData) {
            sum += (m['total'] ?? 0).toDouble();
          }

          setState(() {
            farmer = farmerData;
            milkCollection = localData;
            totalMilk = sum;
            isLoading = false;
          });

          Fluttertoast.showToast(
            msg: "Using offline data",
            backgroundColor: Colors.orange,
          );
        } else {
          // Farmer not found in local storage either
          setState(() {
            isLoading = false;
          });

          Fluttertoast.showToast(
            msg: "Farmer not found. Please sync data first.",
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      } catch (hiveError) {
        print("Hive error: $hiveError");
        setState(() {
          isLoading = false;
        });

        Fluttertoast.showToast(
          msg: "Error loading farmer details",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// Get local unsynced collections for this farmer from Hive
  Future<List<Map<String, dynamic>>> _getLocalCollections() async {
    try {
      // Check if box is already open, otherwise open it
      final box = Hive.isBoxOpen('milk_collections')
          ? Hive.box('milk_collections')
          : await Hive.openBox('milk_collections');
      final collections = box.values
          .where((item) {
            // Filter by farmer ID and date range
            final farmerId = item.farmerId ?? item['farmer_id'];
            final collectionDate = item.date ?? item['collection_date'];

            if (farmerId != widget.farmerId) return false;
            if (collectionDate == null) return false;

            try {
              final date = DateTime.parse(collectionDate);
              return date.isAfter(
                    selectedRange!.start.subtract(const Duration(days: 1)),
                  ) &&
                  date.isBefore(
                    selectedRange!.end.add(const Duration(days: 1)),
                  );
            } catch (e) {
              return false;
            }
          })
          .map((item) {
            final morning = (item.morning ?? item['morning'] ?? 0).toDouble();
            final evening = (item.evening ?? item['evening'] ?? 0).toDouble();
            final rejected = (item.rejected ?? item['rejected'] ?? 0)
                .toDouble();
            final total = morning + evening - rejected;

            return {
              'date': item.date ?? item['collection_date'],
              'morning': morning,
              'evening': evening,
              'rejected': rejected,
              'total': total,
              'is_local': true, // Flag to identify local data
            };
          })
          .toList();

      return collections;
    } catch (e) {
      print('Error loading local collections: $e');
      return [];
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
            ),
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
            icon: const Icon(Icons.print),
            tooltip: "Print Summary",
            onPressed: _printSummary,
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: "Filter by Date",
            onPressed: pickDateRange,
          ),
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
                        ),
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (farmer!['status']?.toString() == "1")
                                    ? Colors.lightGreen
                                    : Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (farmer!['status']?.toString() == "1")
                                    ? "Active"
                                    : "Inactive",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                            color: Colors.white,
                          ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.filter_alt_rounded,
                          color: Colors.green,
                        ),
                        onPressed: pickDateRange,
                      ),
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
                                              if (index <
                                                  milkCollection.length) {
                                                return Text(
                                                  DateFormat('E').format(
                                                    DateTime.parse(
                                                      milkCollection[index]['date'],
                                                    ),
                                                  ), // Mon, Tue...
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                          ),
                                        ),
                                      ),

                                      // ---- BAR DATA ----
                                      barGroups: List.generate(
                                        milkCollection.length,
                                        (i) {
                                          final total =
                                              (milkCollection[i]['total'] ?? 0)
                                                  .toDouble();

                                          return BarChartGroupData(
                                            x: i,
                                            barRods: [
                                              BarChartRodData(
                                                toY: total,
                                                width: 16,
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(6),

                                                // Background bar (same as your provided design)
                                                backDrawRodData:
                                                    BackgroundBarChartRodData(
                                                      show: true,
                                                      toY:
                                                          milkCollection
                                                              .map<double>(
                                                                (e) =>
                                                                    (e['total'] ??
                                                                            0)
                                                                        .toDouble(),
                                                              )
                                                              .reduce(
                                                                (a, b) => a > b
                                                                    ? a
                                                                    : b,
                                                              ) +
                                                          5,
                                                      color: Colors.green
                                                          .withOpacity(0.2),
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
                  const SizedBox(height: 24),

                  // -------- PRODUCTION STATISTICS --------
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Collections',
                          milkCollection.length.toString(),
                          Icons.event_note,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Average/Day',
                          milkCollection.isEmpty
                              ? '0.0 L'
                              : '${(totalMilk / milkCollection.length).toStringAsFixed(1)} L',
                          Icons.analytics,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Highest Day',
                          _getHighestDay(),
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Lowest Day',
                          _getLowestDay(),
                          Icons.trending_down,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // -------- DAILY BREAKDOWN TABLE --------
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Daily Production Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: milkCollection.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = milkCollection[index];
                            final date = DateTime.parse(item['date']);
                            final morning = (item['morning'] ?? 0).toDouble();
                            final evening = (item['evening'] ?? 0).toDouble();
                            final total = (item['total'] ?? 0).toDouble();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(date),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE').format(date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.wb_sunny_outlined,
                                              size: 14,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${morning.toStringAsFixed(1)}L',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.nightlight_outlined,
                                              size: 14,
                                              color: Colors.indigo.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${evening.toStringAsFixed(1)}L',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade600,
                                          Colors.green.shade700,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${total.toStringAsFixed(1)} L',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getHighestDay() {
    if (milkCollection.isEmpty) return '0.0 L';
    var highest = milkCollection.reduce(
      (a, b) => ((a['total'] ?? 0) > (b['total'] ?? 0)) ? a : b,
    );
    return '${(highest['total'] ?? 0).toStringAsFixed(1)} L';
  }

  String _getLowestDay() {
    if (milkCollection.isEmpty) return '0.0 L';
    var lowest = milkCollection.reduce(
      (a, b) => ((a['total'] ?? 0) < (b['total'] ?? 0)) ? a : b,
    );
    return '${(lowest['total'] ?? 0).toStringAsFixed(1)} L';
  }

  Future<void> _printSummary() async {
    if (farmer == null || milkCollection.isEmpty) {
      Fluttertoast.showToast(msg: "No data to print");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name') ?? 'Dairy Cooperative';

    // Check Bluetooth connection
    final canPrint = await PrinterService.checkBluetoothConnection(context);
    if (!canPrint) return;

    try {
      final receiptData = {
        'title': 'FARMER PRODUCTION SUMMARY',
        'company_name': companyName,
        'farmer_name': '${farmer!['fname']} ${farmer!['lname']}',
        'farmer_id': farmer!['farmerID'].toString(),
        'contact': farmer!['contact1'] ?? 'N/A',
        'center': farmer!['center']?['center_name'] ?? 'N/A',
        'period':
            '${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}',
        'total_collections': milkCollection.length.toString(),
        'total_milk': totalMilk.toStringAsFixed(2),
        'average_per_day': (totalMilk / milkCollection.length).toStringAsFixed(
          2,
        ),
        'highest_day': _getHighestDay(),
        'lowest_day': _getLowestDay(),
        'collections': milkCollection
            .take(10)
            .map(
              (item) => {
                'date': DateFormat(
                  'dd/MM/yyyy',
                ).format(DateTime.parse(item['date'])),
                'morning': (item['morning'] ?? 0).toStringAsFixed(1),
                'evening': (item['evening'] ?? 0).toStringAsFixed(1),
                'total': (item['total'] ?? 0).toStringAsFixed(1),
              },
            )
            .toList(),
      };

      final success = await PrinterService.printReceiptWidget(
        ReceiptBuilder.farmerSummary(receiptData),
        context,
      );

      if (success) {
        Fluttertoast.showToast(
          msg: "Summary printed successfully",
          backgroundColor: Colors.green,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Print cancelled or failed",
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Print failed: $e",
        backgroundColor: Colors.red,
      );
    }
  }
}
