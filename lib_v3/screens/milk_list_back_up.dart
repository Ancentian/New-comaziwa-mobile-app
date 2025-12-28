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

  String searchQuery = '';
  DateTimeRange? selectedRange;
  double totalLitres = 0.0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
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
        setState(() {
          milkList = data is List ? data : data['data'] ?? [];
          filteredList = milkList;
          _calculateTotal();
          isLoading = false;
          _controller.forward();
        });
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

  void _calculateTotal() {
    totalLitres = filteredList.fold(
        0.0,
        (sum, item) =>
            sum + (double.tryParse(item['total'].toString()) ?? 0.0));
  }

  void _filterData() {
    List<dynamic> results = milkList.where((item) {
      final name =
          "${item['fname'] ?? ''} ${item['lname'] ?? ''}".toLowerCase();
      final farmerId = (item['farmerID'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      bool matchSearch =
          query.isEmpty || name.contains(query) || farmerId.contains(query);

      bool matchDate = true;
      if (selectedRange != null && item['collection_date'] != null) {
        DateTime? date = DateTime.tryParse(item['collection_date']);
        if (date != null) {
          matchDate = date.isAfter(selectedRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(selectedRange!.end.add(const Duration(days: 1)));
        }
      }

      return matchSearch && matchDate;
    }).toList();

    setState(() {
      filteredList = results;
      _calculateTotal();
    });
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.green,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedRange = picked;
      });
      _filterData();
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return FadeTransition(
      opacity: _animation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 8),
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
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search by Farmer ID or Name",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => searchQuery = val);
                            _filterData();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickDateRange,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.date_range),
                                label: Text(selectedRange == null
                                    ? "Select Date Range"
                                    : "${DateFormat('dd MMM').format(selectedRange!.start)} - ${DateFormat('dd MMM').format(selectedRange!.end)}"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: _buildStatCard(
                            "Filtered Total (L)",
                            totalLitres.toStringAsFixed(2),
                            Icons.local_drink,
                            Colors.green),
                      ),
                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(child: Text("No records found"))
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            "Date: ${item['collection_date'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                          Text(
                                            "Center: ${item['center_name'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
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
