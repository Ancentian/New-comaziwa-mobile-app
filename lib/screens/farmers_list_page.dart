import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import '../models/farmer.dart';
import 'farmer_detail_page.dart';

class FarmersListPage extends StatefulWidget {
  const FarmersListPage({super.key});

  @override
  State<FarmersListPage> createState() => _FarmersListPageState();
}

class _FarmersListPageState extends State<FarmersListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Farmer> farmers = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;

  int currentPage = 1;
  final int pageSize = 20;
  String searchQuery = '';
  Timer? _debounce;

  late String apiBase;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";

    _checkConnectivityAndFetch();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivityAndFetch() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        isOnline = false;
        fetchFarmers();
        return;
      }

      final tenantId = await _getTenantId();
      if (tenantId == null) {
        isOnline = false;
        fetchFarmers();
        return;
      }

      final res = await http
          .get(
            Uri.parse("$apiBase/farmers?tenant_id=$tenantId"),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 5));

      isOnline = res.statusCode == 200;
    } catch (e) {
      isOnline = false;
    }
    fetchFarmers();
  }

  Future<int?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tenant_id');
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = _searchController.text;
        farmers.clear();
        currentPage = 1;
        hasMore = true;
      });
      fetchFarmers();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !isLoadingMore &&
        hasMore) {
      fetchFarmers(loadMore: true);
    }
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchFarmers({bool loadMore = false}) async {
    if (loadMore && isLoadingMore) return;

    if (loadMore) {
      setState(() => isLoadingMore = true);
      currentPage++;
    } else {
      setState(() => isLoading = true);
    }

    try {
      if (isOnline) {
        await _fetchOnlineFarmers(loadMore: loadMore);
      } else {
        _fetchOfflineFarmers(loadMore: loadMore);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  Future<void> _fetchOnlineFarmers({bool loadMore = false}) async {
    final token = await _getAuthToken();
    if (token == null) {
      setState(() {
        isOnline = false;
        isLoading = false;
        isLoadingMore = false;
      });
      _fetchOfflineFarmers(loadMore: loadMore);
      return;
    }

    final tenantId = await _getTenantId();
    if (tenantId == null) {
      setState(() {
        isOnline = false;
        isLoading = false;
        isLoadingMore = false;
      });
      _fetchOfflineFarmers(loadMore: loadMore);
      return;
    }

    final queryParams = {
      'tenant_id': tenantId.toString(),
      'page': currentPage.toString(),
      'limit': pageSize.toString(),
      if (searchQuery.isNotEmpty) 'name': searchQuery,
      if (searchQuery.isNotEmpty) 'farmerID': searchQuery,
    };

    final uri = Uri.parse(
      "$apiBase/farmers",
    ).replace(queryParameters: queryParams);

    try {
      final res = await http
          .get(uri, headers: {"Authorization": "Bearer $token"})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final responseBody = json.decode(res.body);
        final data = (responseBody['data'] as List<dynamic>)
            .map((e) => Farmer.fromJson(e))
            .toList();

        // Save to Hive
        final box = Hive.box<Farmer>('farmers');
        for (var f in data) {
          box.put(f.farmerId, f);
        }

        setState(() {
          if (loadMore) {
            farmers.addAll(data);
          } else {
            farmers = data;
          }
          hasMore = data.length == pageSize;
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          isOnline = false;
          isLoading = false;
          isLoadingMore = false;
        });
        _fetchOfflineFarmers(loadMore: loadMore);
        Fluttertoast.showToast(
          msg: "Using offline data",
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      setState(() {
        isOnline = false;
        isLoading = false;
        isLoadingMore = false;
      });
      _fetchOfflineFarmers(loadMore: loadMore);
    }
  }

  void _fetchOfflineFarmers({bool loadMore = false}) async {
    final box = Hive.box<Farmer>('farmers');

    List<Farmer> allFarmers = box.values.toList();

    if (allFarmers.isEmpty) {
      setState(() {
        farmers = [];
        hasMore = false;
        isLoading = false;
        isLoadingMore = false;
      });
      return;
    }

    // 🔥 Apply grader center filter
    final prefs = await SharedPreferences.getInstance();
    final graderCenters = prefs.getStringList('grader_centers');
    print('🔍 Farmers list - Grader centers: $graderCenters');
    print(
      '🔍 Farmers list - Total farmers before filter: ${allFarmers.length}',
    );

    if (graderCenters != null && graderCenters.isNotEmpty) {
      final beforeFilter = allFarmers.length;
      allFarmers = allFarmers.where((f) {
        return f.centerId != null &&
            graderCenters.contains(f.centerId.toString());
      }).toList();
      print(
        '🔍 Farmers list - After filter: ${allFarmers.length} (filtered out ${beforeFilter - allFarmers.length})',
      );
    } else {
      print('🔍 Farmers list - No filter applied');
    }

    if (searchQuery.isNotEmpty) {
      allFarmers = allFarmers.where((f) {
        final name = "${f.fname} ${f.lname}".toLowerCase();
        return name.contains(searchQuery.toLowerCase()) ||
            f.farmerId.toString().contains(searchQuery);
      }).toList();
    }

    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize) > allFarmers.length
        ? allFarmers.length
        : (start + pageSize);

    if (start >= allFarmers.length) {
      setState(() {
        hasMore = false;
        isLoading = false;
        isLoadingMore = false;
      });
      return;
    }

    final pageFarmers = allFarmers.sublist(start, end);

    setState(() {
      if (loadMore) {
        farmers.addAll(pageFarmers);
      } else {
        farmers = pageFarmers;
      }
      hasMore = end < allFarmers.length;
      isLoading = false;
      isLoadingMore = false;
    });
  }

  void pickDateRange() {
    Fluttertoast.showToast(msg: "Filter tapped (not implemented)");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Farmers Directory"),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        actions: [
          // Online/Offline indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.shade400.withOpacity(0.3)
                      : Colors.orange.shade400.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            farmers.clear();
            currentPage = 1;
            hasMore = true;
          });
          await fetchFarmers();
        },
        color: Colors.green,
        child: Column(
          children: [
            // ---- ENHANCED HEADER CARD ----
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        // Animated counter
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.group,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Total Members",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: farmers.length.toDouble(),
                                ),
                                duration: const Duration(milliseconds: 500),
                                builder: (context, value, child) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      letterSpacing: -1,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Stats badges
                        Column(
                          children: [
                            _buildStatBadge(
                              Icons.sync,
                              'Synced',
                              farmers.length.toString(),
                              Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(height: 8),
                            _buildStatBadge(
                              Icons.person_add,
                              'Active',
                              farmers.length.toString(),
                              Colors.lightGreen.shade300,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ---- SEARCH BAR (Inside header) ----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search by name or ID...",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.green.shade600,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade400,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.green.shade400,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- FARMERS LIST ----
            Expanded(
              child: isLoading && farmers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading farmers...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : farmers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No farmers found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : isOnline
                                ? 'Pull down to refresh'
                                : 'You are offline',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: farmers.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == farmers.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Loading more...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final farmer = farmers[index];

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FarmerDetailPage(
                                      farmerId: farmer.farmerId,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Avatar with gradient
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade700,
                                            Colors.green.shade500,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.shade200,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          farmer.fname.isNotEmpty
                                              ? farmer.fname[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Farmer info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${farmer.fname} ${farmer.lname}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.badge,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "ID: ${farmer.farmerId}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  farmer.centerName.isNotEmpty
                                                      ? farmer.centerName
                                                      : 'No center',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrow indicator
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _buildStatBadge(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
