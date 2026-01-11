import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/milk_collection.dart';
import '../services/printer_service.dart';

class DailyCollectionSummaryPage extends StatefulWidget {
  const DailyCollectionSummaryPage({super.key});

  @override
  State<DailyCollectionSummaryPage> createState() =>
      _DailyCollectionSummaryPageState();
}

class _DailyCollectionSummaryPageState
    extends State<DailyCollectionSummaryPage> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> dailyCollections = [];
  bool isLoading = false;

  double totalMorning = 0;
  double totalEvening = 0;
  double totalRejected = 0;
  double grandTotal = 0;
  int totalFarmers = 0;

  String? userType;
  int? userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// Load user information to determine access level
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getString('type');
      userId = prefs.getInt('user_id');
    });
    print('👤 User type: $userType, ID: $userId');
    await _loadDailyCollections();
  }

  /// Load collections for the selected date from Hive
  Future<void> _loadDailyCollections() async {
    setState(() {
      isLoading = true;
    });

    try {
      final box = Hive.box<MilkCollection>('milk_collections');
      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Filter collections for selected date
      var collections = box.values.where((collection) {
        return collection.date == dateString;
      }).toList();

      // Apply role-based filtering
      // Only employees (graders) can only see records they created
      // Users, admins, and owners can see all records
      if (userType != null &&
          (userType == 'employee' || userType == 'grader') &&
          userId != null) {
        collections = collections.where((collection) {
          // Show records created by this employee
          return collection.createdById == userId;
        }).toList();
        print(
          '🔒 Employee - filtered to ${collections.length} collections for user $userId',
        );
      } else {
        print(
          '👑 User/Admin/Owner - showing all ${collections.length} collections',
        );
      }

      // Convert to map and calculate totals
      dailyCollections = collections.map((collection) {
        final total =
            collection.morning + collection.evening - collection.rejected;
        return {
          'farmerId': collection.farmerId,
          'farmer_name': '${collection.fname ?? ''} ${collection.lname ?? ''}',
          'center_name': collection.center_name ?? 'N/A',
          'morning': collection.morning,
          'evening': collection.evening,
          'rejected': collection.rejected,
          'total': total,
          'is_synced': collection.isSynced,
        };
      }).toList();

      // Sort by farmer ID
      dailyCollections.sort((a, b) => a['farmerId'].compareTo(b['farmerId']));

      // Calculate summary totals
      totalMorning = dailyCollections.fold(
        0,
        (sum, item) => sum + (item['morning'] as double),
      );
      totalEvening = dailyCollections.fold(
        0,
        (sum, item) => sum + (item['evening'] as double),
      );
      totalRejected = dailyCollections.fold(
        0,
        (sum, item) => sum + (item['rejected'] as double),
      );
      grandTotal = totalMorning + totalEvening - totalRejected;
      totalFarmers = dailyCollections.length;

      print(
        '✅ Loaded $totalFarmers collections for $dateString (Total: $grandTotal L)',
      );
    } catch (e) {
      print('❌ Error loading daily collections: $e');
      Fluttertoast.showToast(
        msg: 'Error loading data: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Show date picker to select a different date
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadDailyCollections();
    }
  }

  /// Print daily summary report
  Future<void> _printDailySummary() async {
    if (dailyCollections.isEmpty) {
      Fluttertoast.showToast(
        msg: 'No collections to print',
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      // Build summary data for printing
      final summaryData = {
        'title': 'DAILY COLLECTION SUMMARY',
        'company_name': 'COMAZIWA DAIRY',
        'date': DateFormat('dd/MM/yyyy').format(selectedDate),
        'total_farmers': totalFarmers,
        'total_morning': totalMorning.toStringAsFixed(1),
        'total_evening': totalEvening.toStringAsFixed(1),
        'total_rejected': totalRejected.toStringAsFixed(1),
        'grand_total': grandTotal.toStringAsFixed(1),
        'collections': dailyCollections,
      };

      final success = await PrinterService.printDailySummary(
        summaryData,
        context,
      );

      if (success) {
        Fluttertoast.showToast(
          msg: 'Summary printed successfully',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      print('❌ Print error: $e');
      Fluttertoast.showToast(
        msg: 'Print failed: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Collection Summary'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printDailySummary,
            tooltip: 'Print Summary',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDailyCollections,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDailyCollections,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Date Selector Card
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                child: InkWell(
                  onTap: _selectDate,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Date',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'EEEE, MMMM dd, yyyy',
                              ).format(selectedDate),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.green,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Summary Statistics Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Farmers',
                        totalFarmers.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        '${grandTotal.toStringAsFixed(1)} L',
                        Icons.water_drop,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Morning, Evening, Rejected breakdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildBreakdownRow(
                          'Morning',
                          totalMorning,
                          Colors.orange,
                        ),
                        const Divider(),
                        _buildBreakdownRow(
                          'Evening',
                          totalEvening,
                          Colors.indigo,
                        ),
                        const Divider(),
                        _buildBreakdownRow(
                          'Rejected',
                          totalRejected,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Collections List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Collections Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${dailyCollections.length} records',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Collections List
              isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : dailyCollections.isEmpty
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No collections for this date',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _selectDate,
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Select Different Date'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: dailyCollections.length,
                      itemBuilder: (context, index) {
                        final collection = dailyCollections[index];
                        return _buildCollectionCard(collection);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a stat card widget
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Build breakdown row (morning/evening/rejected)
  Widget _buildBreakdownRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
        Text(
          '${value.toStringAsFixed(1)} L',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build collection item card
  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: collection['is_synced']
              ? Colors.green
              : Colors.orange,
          child: Text(
            '${collection['farmerId']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          collection['farmer_name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Center: ${collection['center_name']}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildMiniChip(
                  'M: ${collection['morning'].toStringAsFixed(1)}',
                  Colors.orange,
                ),
                const SizedBox(width: 4),
                _buildMiniChip(
                  'E: ${collection['evening'].toStringAsFixed(1)}',
                  Colors.indigo,
                ),
                const SizedBox(width: 4),
                if (collection['rejected'] > 0)
                  _buildMiniChip(
                    'R: ${collection['rejected'].toStringAsFixed(1)}',
                    Colors.red,
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${collection['total'].toStringAsFixed(1)} L',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              collection['is_synced'] ? 'Synced' : 'Local',
              style: TextStyle(
                fontSize: 10,
                color: collection['is_synced'] ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build mini chip for morning/evening/rejected display
  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
