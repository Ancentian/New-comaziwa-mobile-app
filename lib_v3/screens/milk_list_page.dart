import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

import '../config/app_config.dart';
import '../models/milk_collection.dart';
import '../services/printer_service.dart';

class MilkListPage extends StatefulWidget {
  const MilkListPage({super.key});

  @override
  State<MilkListPage> createState() => _MilkListPageState();
}

class _MilkListPageState extends State<MilkListPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> milkList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool isLoading = true;
  bool hasError = false;
  late String apiBase;

  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;
  Map<String, String> printStatus = {}; // Track print status per item ID

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    DateTime now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);

    fetchMilkList();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Fetch both offline (Hive) and online milk records
  Future<void> fetchMilkList() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    List<Map<String, dynamic>> combinedList = [];

    // 1️⃣ Load offline Hive records
    final box = Hive.box<MilkCollection>('milk_collections');
    final offlineList = box.values.map((e) {
      return {
        'id': 'hive_${e.key}', // Unique ID for offline records
        'farmerID': e.farmerId,
        'collection_date': e.date,
        'morning': e.morning,
        'evening': e.evening,
        'rejected': e.rejected,
        'total': e.morning + e.evening,
        'center_name': e.center_name ?? 'N/A',
        'is_synced': e.isSynced,
        'hiveKey': e.key,
        'fname': e.fname ?? '',
        'lname': e.lname ?? '',
      };
    }).toList();
    combinedList.addAll(offlineList);

    // 2️⃣ Load online records
    try {
      final token = await _getAuthToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse("$apiBase/all_milk_collection"),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final onlineList = data is List ? data : data['data'] ?? [];
          onlineList.forEach((item) => item['is_synced'] = true);
          combinedList.addAll(onlineList);
        }
      }
    } catch (_) {
      Fluttertoast.showToast(
        msg: "Offline mode only",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }

    milkList = combinedList;
    _applyFilters();
    _controller.forward();
    setState(() => isLoading = false);
  }

  void _applyFilters() {
    setState(() {
      filteredList = milkList.where((item) {
        final nameMatch =
            "${item['fname'] ?? ''} ${item['lname'] ?? ''}"
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
        final idMatch =
            (item['farmerID'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());

        final date = DateTime.tryParse(item['collection_date'] ?? '');
        final dateMatch = (startDate == null || (date != null && !date.isBefore(startDate!))) &&
            (endDate == null || (date != null && !date.isAfter(endDate!)));

        return (nameMatch || idMatch) && dateMatch;
      }).toList();
      
      // Sort by date - latest first
      filteredList.sort((a, b) {
        final dateA = DateTime.tryParse(a['collection_date'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['collection_date'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA); // Descending order (latest first)
      });
    });
  }

  double _getTotalLitres() {
    double total = 0;
    for (var item in filteredList) {
      total += double.tryParse(item['total'].toString()) ?? 0;
    }
    return total;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _applyFilters();
    }
  }

  /// Sync single offline record
  Future<bool> syncSingleCollection(int hiveKey) async {
    final box = Hive.box<MilkCollection>('milk_collections');
    final record = box.get(hiveKey);
    if (record == null) return false;

    final token = await _getAuthToken();
    if (token == null) return false;

    try {
      final res = await http.post(
        Uri.parse("$apiBase/store-milk-collection"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(record.toJson()),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        record.isSynced = true;
        await box.put(hiveKey, record);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  int getUnsyncedCount() {
    return milkList.where((item) => item['is_synced'] == false).length;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return FadeTransition(
      opacity: _animation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Printing method with auto-print support
  /// When auto-print is enabled, it uses the default printer automatically
  /// When disabled, user is prompted to select a printer
  Widget _buildPrintButton(Map<String, dynamic> item) {
    final itemId = item['id'].toString();
    final status = printStatus[itemId];
    
    if (status == 'printing') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          ),
        ),
      );
    }
    
    if (status == 'success') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          Icons.check_circle,
          color: Colors.green[700],
          size: 24,
        ),
      );
    }
    
    if (status == 'error') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          onTap: () => _printReceipt(item),
          child: Icon(
            Icons.error_outline,
            color: Colors.red[700],
            size: 24,
          ),
        ),
      );
    }
    
    return IconButton(
      icon: const Icon(Icons.print, color: Colors.blue),
      onPressed: () => _printReceipt(item),
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> item) async {
    final itemId = item['id'].toString();
    
    try {
      // Set status to printing
      setState(() {
        printStatus[itemId] = 'printing';
      });

      // Calculate today's total for this farmer
      final farmerId = item['farmerID'];
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      
      double todayTotal = 0;
      double monthlyTotal = 0;
      
      for (var record in milkList) {
        if (record['farmerID'] == farmerId) {
          final recordDate = DateTime.tryParse(record['collection_date'] ?? '');
          if (recordDate != null) {
            final recordTotal = double.tryParse(record['total'].toString()) ?? 0;
            
            // Today's total
            if (DateFormat('yyyy-MM-dd').format(recordDate) == todayStr) {
              todayTotal += recordTotal;
            }
            
            // Monthly total
            if (recordDate.year == today.year && recordDate.month == today.month) {
              monthlyTotal += recordTotal;
            }
          }
        }
      }
      
      // Get company name from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final companyName = prefs.getString('company_name');

      // Add totals to item data
      final enrichedItem = Map<String, dynamic>.from(item);
      enrichedItem['today_total'] = todayTotal.toStringAsFixed(2);
      enrichedItem['monthly_total'] = monthlyTotal.toStringAsFixed(2);
      enrichedItem['company_name'] = companyName;

      final receiptWidget = ReceiptBuilder.milkReceipt(enrichedItem);
      final ok = await PrinterService.printWithRetry(receiptWidget, context, retries: 2);
      if (!ok) throw Exception('Print failed');
      
      // Set status to success
      setState(() {
        printStatus[itemId] = 'success';
      });
      
      Fluttertoast.showToast(
        msg: "Printed successfully",
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_SHORT,
      );
      
      // Clear status after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            printStatus.remove(itemId);
          });
        }
      });
    } catch (e) {
      // Set status to error
      setState(() {
        printStatus[itemId] = 'error';
      });
      
      Fluttertoast.showToast(
        msg: "Print failed: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      
      // Clear status after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            printStatus.remove(itemId);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLitres = _getTotalLitres().toStringAsFixed(2);

    String rangeText = startDate != null && endDate != null
        ? "${DateFormat('MM/dd/yyyy').format(startDate!)} - ${DateFormat('MM/dd/yyyy').format(endDate!)}"
        : "Select Date Range";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        title: const Text("Milk Collections"),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.sync_alt),
                tooltip: 'Sync All',
                onPressed: getUnsyncedCount() == 0
                    ? null
                    : () async {
                        final unsynced =
                            milkList.where((item) => item['is_synced'] == false);
                        bool allSuccess = true;

                        for (var item in unsynced) {
                          final hiveKey = item['hiveKey'];
                          if (hiveKey != null) {
                            bool success = await syncSingleCollection(hiveKey);
                            if (!success) allSuccess = false;
                            if (success) setState(() => item['is_synced'] = true);
                          }
                        }

                        Fluttertoast.showToast(
                          msg: allSuccess ? "All collections synced" : "Some collections failed",
                          backgroundColor: allSuccess ? Colors.green : Colors.red,
                        );
                      },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: getUnsyncedCount() > 0
                      ? Container(
                          key: ValueKey(getUnsyncedCount()),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${getUnsyncedCount()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: fetchMilkList,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchMilkList,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : hasError
                ? const Center(
                    child: Text(
                      "Failed to load milk list. Please try again.",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  )
                : Column(
                    children: [
                      // Search + Filter Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search by Farmer ID or Name',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() => searchQuery = value);
                                  _applyFilters();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  backgroundColor: Colors.green.shade50),
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.filter_alt_rounded,
                                  color: Colors.green),
                              label: Text(
                                rangeText,
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatCard(
                        "Total Milk Collected",
                        "$totalLitres L",
                        Icons.local_drink,
                        Colors.green,
                      ),
                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(child: Text("No milk records found."))
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.green.shade100,
                                        child: const Icon(Icons.local_drink,
                                            color: Colors.green),
                                      ),
                                      title: Text(
                                        "${item['farmerID']} - ${item['fname']} ${item['lname']}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                              "Date: ${item['collection_date'] ?? 'N/A'}",
                                              style: const TextStyle(
                                                  fontSize: 14, color: Colors.grey)),
                                          Text(
                                              "Center: ${item['center_name'] ?? 'N/A'}",
                                              style: const TextStyle(
                                                  fontSize: 14, color: Colors.grey)),
                                          Text(
                                            "Total: ${item['total'] ?? 0} L",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          item['is_synced'] == true
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.green)
                                              : IconButton(
                                                  icon: const Icon(Icons.sync,
                                                      color: Colors.orange),
                                                  onPressed: () async {
                                                    final hiveKey = item['hiveKey'];
                                                    if (hiveKey != null) {
                                                      bool success =
                                                          await syncSingleCollection(
                                                              hiveKey);
                                                      if (success) {
                                                        setState(() => item['is_synced'] = true);
                                                        Fluttertoast.showToast(
                                                          msg: "Synced successfully",
                                                          backgroundColor: Colors.green,
                                                        );
                                                      } else {
                                                        Fluttertoast.showToast(
                                                          msg: "Sync failed",
                                                          backgroundColor: Colors.red,
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                          _buildPrintButton(item)
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
