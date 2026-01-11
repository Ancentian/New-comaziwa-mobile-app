import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/farmer.dart';
import '../models/milk_collection.dart';
import '../services/printer_service.dart';
import '../utils/error_helper.dart';

class MilkListPage extends StatefulWidget {
  const MilkListPage({super.key});

  @override
  State<MilkListPage> createState() => _MilkListPageState();
}

class _MilkListPageState extends State<MilkListPage> {
  List<Map<String, dynamic>> collections = [];
  List<Map<String, dynamic>> filteredCollections = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Load collections from Hive (offline-first)
  Future<void> _loadCollections() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('type');
      final userId = prefs.getInt('user_id');

      final box = Hive.box<MilkCollection>('milk_collections');

      // Filter collections based on user type
      Iterable<MilkCollection> filteredBox;

      if (userType == 'grader' || userType == 'employee') {
        // Graders only see collections they created
        filteredBox = box.values.where((e) => e.createdById == userId);
        print(
          '🔒 Grader filter: Showing only collections created by user $userId',
        );
      } else {
        // Admins see everything
        filteredBox = box.values;
        print('👑 Admin view: Showing all collections');
      }

      // Map Hive collections to display format
      final records = filteredBox.map((e) {
        return {
          'id': e.serverId ?? 0,
          'farmer_id': e.farmerId, // Numeric DB ID
          'farmerID':
              e.memberNo ?? e.farmerId.toString(), // Display member number
          'fname': e.fname ?? '',
          'lname': e.lname ?? '',
          'center_name': e.center_name ?? 'N/A',
          'collection_date': e.date,
          'morning': e.morning,
          'evening': e.evening,
          'rejected': e.rejected,
          'total': e.morning + e.evening,
          'is_synced': e.isSynced,
        };
      }).toList();

      // Sort by date (newest first)
      records.sort((a, b) {
        final dateA = a['collection_date'] as String;
        final dateB = b['collection_date'] as String;
        return dateB.compareTo(dateA);
      });

      setState(() {
        collections = records;
        filteredCollections = records;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading collections: $e');
      setState(() => isLoading = false);
    }
  }

  /// Sync collections from server
  Future<void> _syncFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final tenantId = prefs.getInt('tenant_id');

      if (token == null || tenantId == null) {
        _showMessage('Login required', Colors.red);
        return;
      }

      setState(() => isLoading = true);

      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.baseUrl}/api/milk-collections-sync?tenant_id=$tenantId&limit=1000',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final syncedCollections = (data['data'] as List)
            .map((item) => MilkCollection.fromJson(item))
            .toList();

        // Get user info for filtering
        final userType = prefs.getString('type');
        final userId = prefs.getInt('user_id');

        // Save to Hive
        final box = Hive.box<MilkCollection>('milk_collections');
        await box.clear(); // Clear old data

        // Filter before saving if grader
        List<MilkCollection> collectionsToSave;
        if (userType == 'grader' || userType == 'employee') {
          collectionsToSave = syncedCollections
              .where((c) => c.createdById == userId)
              .toList();
          print(
            '🔒 Grader sync: Saving only ${collectionsToSave.length} collections created by user $userId',
          );
        } else {
          collectionsToSave = syncedCollections;
          print(
            '👑 Admin sync: Saving all ${collectionsToSave.length} collections',
          );
        }

        for (var collection in collectionsToSave) {
          await box.add(collection);
        }

        _showMessage(
          'Synced ${collectionsToSave.length} collections',
          Colors.green,
        );
        await _loadCollections();
      } else {
        _showMessage(
          'Sync failed: Server returned ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (e) {
      // Provide user-friendly offline messages
      final userMessage = ErrorHelper.getUserFriendlyMessage(e);
      final logMessage = ErrorHelper.getLogMessage(e);

      print('📡 Sync error: $logMessage');
      _showMessage(userMessage, Colors.orange);
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Filter collections by search query and date range
  void _filterCollections() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        filteredCollections = collections.where((item) {
          // Search filter (by farmerID, name)
          final matchesSearch =
              searchQuery.isEmpty ||
              item['farmerID'].toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              '${item['fname']} ${item['lname']}'.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );

          // Date filter
          final collectionDate = DateTime.parse(item['collection_date']);
          final matchesDateRange =
              (startDate == null ||
                  collectionDate.isAfter(
                    startDate!.subtract(const Duration(days: 1)),
                  )) &&
              (endDate == null ||
                  collectionDate.isBefore(
                    endDate!.add(const Duration(days: 1)),
                  ));

          return matchesSearch && matchesDateRange;
        }).toList();
      });
    });
  }

  /// Pick date range
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _filterCollections();
    }
  }

  /// Clear date filter
  void _clearDateFilter() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _filterCollections();
  }

  /// Print receipt for a collection
  Future<void> _printReceipt(Map<String, dynamic> collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyName = prefs.getString('company_name') ?? 'Comaziwa';

      // Calculate farmer's totals using server base + local additions
      final farmerId = collection['farmer_id'];
      final farmerMemberNo = collection['farmerID']; // Member number like "33"
      final collectionDate = DateTime.parse(collection['collection_date']);
      final now = DateTime.now();

      print(
        '🖨️ Printing receipt for farmer_id: $farmerId, memberNo: $farmerMemberNo',
      );
      print('📅 Collection date: $collectionDate');
      print('📦 Total collections available: ${collections.length}');

      // Get farmer from Hive using member number (Hive key is farmerID, not database ID)
      final farmersBox = Hive.box<Farmer>('farmers');
      int farmerKey = 0;
      try {
        // farmerID from collection is a string like "33", convert to int
        farmerKey = int.parse(farmerMemberNo.toString());
      } catch (e) {
        print('❌ Error parsing farmerID: $e');
      }

      final farmer = farmersBox.get(farmerKey);

      if (farmer == null) {
        print('❌ Farmer not found in Hive with key: $farmerKey');
      } else {
        print('✅ Found farmer: ${farmer.fname} ${farmer.lname}');
      }

      // Use server totals directly (from last sync)
      double monthlyTotal = farmer?.monthlyTotal ?? 0;
      double yearlyTotal = farmer?.yearlyTotal ?? 0;

      print('📊 Server totals - Monthly: $monthlyTotal, Yearly: $yearlyTotal');

      // Today's total (for TODAY only)
      final todaysTotal = collections
          .where(
            (c) =>
                c['farmer_id'] == farmerId &&
                DateTime.parse(c['collection_date']).year == now.year &&
                DateTime.parse(c['collection_date']).month == now.month &&
                DateTime.parse(c['collection_date']).day == now.day,
          )
          .fold<double>(0, (sum, c) => sum + (c['total'] as num).toDouble());

      print('📊 Today\'s total: $todaysTotal');
      print('📊 Monthly total: $monthlyTotal, Yearly total: $yearlyTotal');

      final receiptData = {
        'farmerID': collection['farmerID'],
        'fname': collection['fname'],
        'lname': collection['lname'],
        'center_name': collection['center_name'],
        'collection_date': collection['collection_date'],
        'morning': collection['morning'].toString(),
        'evening': collection['evening'].toString(),
        'rejected': collection['rejected'].toString(),
        'total': collection['total'].toStringAsFixed(2),
        'company_name': companyName,
        'todays_total': todaysTotal.toStringAsFixed(2),
        'monthly_total': monthlyTotal.toStringAsFixed(2),
        'yearly_total': yearlyTotal.toStringAsFixed(2),
      };

      final result = await PrinterService.printDirectlyFast(
        receiptData,
        context,
      );

      if (result) {
        _showMessage('Printing...', Colors.green);
      } else {
        _showMessage('Printer not connected', Colors.orange);
      }
    } catch (e) {
      _showMessage('Print failed: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMilk = filteredCollections.fold<double>(
      0,
      (sum, item) => sum + (item['total'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Collections'),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncFromServer,
            tooltip: 'Sync from server',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    searchQuery = value;
                    _filterCollections();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Farmer ID or Name',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.green.shade700,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Filter Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          startDate != null && endDate != null
                              ? '${DateFormat('MMM dd').format(startDate!)} - ${DateFormat('MMM dd').format(endDate!)}'
                              : 'Select Date Range',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.green.shade200),
                          ),
                        ),
                      ),
                    ),
                    if (startDate != null || endDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.clear),
                        color: Colors.red.shade700,
                        tooltip: 'Clear filter',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Collections',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${filteredCollections.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Milk',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          totalMilk.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'L',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collections List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCollections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No collections found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _syncFromServer,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync from server'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _syncFromServer,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredCollections.length,
                      itemBuilder: (context, index) {
                        final item = filteredCollections[index];
                        return _buildCollectionCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Farmer Info and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['farmerID']} - ${item['fname']} ${item['lname']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['center_name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat(
                        'MMM dd, yyyy',
                      ).format(DateTime.parse(item['collection_date'])),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (!item['is_synced'])
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Milk Details
            Row(
              children: [
                Expanded(
                  child: _buildMilkDetail(
                    'Morning',
                    item['morning'],
                    Icons.wb_sunny_outlined,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMilkDetail(
                    'Evening',
                    item['evening'],
                    Icons.nightlight_outlined,
                    Colors.indigo,
                  ),
                ),
                Expanded(
                  child: _buildMilkDetail(
                    'Rejected',
                    item['rejected'],
                    Icons.remove_circle_outline,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total and Print Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        'Total: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${item['total'].toStringAsFixed(2)} L',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _printReceipt(item),
                    icon: Icon(Icons.print, color: Colors.green.shade700),
                    tooltip: 'Print Receipt',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilkDetail(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)}L',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
