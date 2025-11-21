import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class MilkListPage extends StatefulWidget {
  const MilkListPage({super.key});

  @override
  State<MilkListPage> createState() => _MilkListPageState();
}

class _MilkListPageState extends State<MilkListPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> milkList = [];
  List<dynamic> filteredList = [];
  bool isLoading = true;
  bool hasError = false;
  late String apiBase;

  // filters
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Default date range: current month
    DateTime now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);

    fetchMilkList();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchMilkList() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse("$apiBase/all_milk_collection"),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        milkList = data is List ? data : data['data'] ?? [];
        _applyFilters();
        _controller.forward();
        setState(() => isLoading = false);
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Error: ${response.statusCode}",
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Failed to connect to server.",
        backgroundColor: Colors.redAccent,
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredList = milkList.where((item) {
        final nameMatch = "${item['fname'] ?? ''} ${item['lname'] ?? ''}"
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
        final idMatch = (item['farmerID'] ?? '')
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase());

        final date = DateTime.tryParse(item['collection_date'] ?? '');
        final dateMatch = (startDate == null ||
                (date != null && !date.isBefore(startDate!))) &&
            (endDate == null || (date != null && !date.isAfter(endDate!)));

        return (nameMatch || idMatch) && dateMatch;
      }).toList();
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
                      // 🔍 Search + Filter Row
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search by Farmer ID or Name',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
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

                      // 🧾 Summary Card
                      _buildStatCard(
                        "Total Milk Collected",
                        "$totalLitres L",
                        Icons.local_drink,
                        Colors.green,
                      ),

                      // 📋 Filtered List
                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(
                                child: Text("No milk records found."),
                              )
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
                                        "${item['farmerID'] ?? ''} - ${item['fname'] ?? ''} ${item['lname'] ?? ''}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            "Date: ${item['collection_date'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey),
                                          ),
                                          Text(
                                            "Center: ${item['center_name'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey),
                                          ),
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
                                      trailing: const Icon(Icons.chevron_right,
                                          color: Colors.grey),
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
