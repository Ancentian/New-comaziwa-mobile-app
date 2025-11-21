import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'farmer_detail_page.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FarmersListPage extends StatefulWidget {
  const FarmersListPage({super.key});

  @override
  State<FarmersListPage> createState() => _FarmersListPageState();
}

class _FarmersListPageState extends State<FarmersListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> farmers = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;

  int currentPage = 1;
  final int pageSize = 20;
  String searchQuery = '';
  Timer? _debounce;

  late String apiBase;

  @override
  void initState() {
    super.initState();
    apiBase = "${AppConfig.baseUrl}/api";
    fetchFarmers();

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

    final token = await _getAuthToken();
    if (token == null) {
      Fluttertoast.showToast(msg: "Please login first");
      return;
    }

    try {
      final queryParams = {
        'page': currentPage.toString(),
        'limit': pageSize.toString(),
        if (searchQuery.isNotEmpty) 'name': searchQuery,
        if (searchQuery.isNotEmpty) 'farmerID': searchQuery,
      };

      final uri = Uri.parse("$apiBase/farmers").replace(queryParameters: queryParams);

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] as List<dynamic>;
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
          isLoading = false;
          isLoadingMore = false;
        });
        Fluttertoast.showToast(msg: "Failed to fetch farmers");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  void pickDateRange() {
    // Implement date filter if needed
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
                  // LEFT SIDE
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
                  // RIGHT SIDE FILTER ICON
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
                                farmer['fname'][0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              "${farmer['fname']} ${farmer['lname']}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "Farmer ID: ${farmer['farmerID']}",
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
                                      FarmerDetailPage(farmerId: farmer['id']),
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
