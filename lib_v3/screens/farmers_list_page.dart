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

      final res = await http.get(
        Uri.parse("$apiBase/farmers?tenant_id=$tenantId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));
      
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

    final uri = Uri.parse("$apiBase/farmers").replace(queryParameters: queryParams);

    try {
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

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
        Fluttertoast.showToast(msg: "Using offline data", backgroundColor: Colors.orange);
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

  void _fetchOfflineFarmers({bool loadMore = false}) {
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

    if (searchQuery.isNotEmpty) {
      allFarmers = allFarmers.where((f) {
        final name = "${f.fname} ${f.lname}".toLowerCase();
        return name.contains(searchQuery.toLowerCase()) ||
            f.farmerId.toString().contains(searchQuery);
      }).toList();
    }

    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize) > allFarmers.length ? allFarmers.length : (start + pageSize);

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
        title: const Text("Farmers List"),
        elevation: 1,
      ),
      body: Column(
        children: [
          // ---- TOP CARD WITH ICON AND GRADIENT ----
          Card(
            elevation: 4,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D773E), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.people_alt_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "Total Farmers",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${farmers.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_alt_rounded,
                          color: Colors.white, size: 28),
                      onPressed: pickDateRange,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- SEARCH BAR ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by Name or Farmer ID",
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.green.shade200),
                ),
              ),
            ),
          ),

          // ---- FARMERS LIST ----
          Expanded(
            child: isLoading && farmers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : farmers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No farmers found',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOnline ? 'Try syncing farmers from settings' : 'You are offline',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: farmers.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                      if (index == farmers.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final farmer = farmers[index];

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeIn,
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade700,
                              child: Text(
                                farmer.fname[0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              "${farmer.fname} ${farmer.lname}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "Farmer ID: ${farmer.farmerId}",
                              style:
                                  TextStyle(color: Colors.grey.shade600),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      // FarmerDetailPage(farmerId: farmer.id),
                                      FarmerDetailPage(farmerId: farmer.farmerId),

                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
