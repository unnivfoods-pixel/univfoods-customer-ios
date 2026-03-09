import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import '../../core/location_service.dart';
import '../cart/cart_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import 'map_screen.dart';
import '../../core/notification_store.dart';
import '../../core/location_store.dart';
import '../../core/profile_store.dart';
import '../menu/menu_screen.dart';
import '../../core/menu_store.dart';
import '../../core/enums.dart';

// ─── Main HomeScreen with 5-Tab Layout ────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('index') && args['index'] is int) {
      final int newIndex = args['index'] as int;
      if (_selectedIndex != newIndex) {
        setState(() => _selectedIndex = newIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If not on first tab, go back to first tab instead of exiting
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const HomeTab(),
            const MapScreen(),
            CartScreen(onTabChange: (i) => setState(() => _selectedIndex = i)),
            const OrdersScreen(showBack: false),
            ProfileScreen(
                onTabChange: (i) => setState(() => _selectedIndex = i)),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5))
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: ProTheme.secondary,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: ProTheme.secondary),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.normal),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.delivery_dining_rounded), label: "Food"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.explore_rounded), label: "Explore"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_rounded), label: "Cart"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_rounded), label: "Orders"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HomeTab: The Premium Landing Page ────────────────────────────────────────

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Filtering & Search
  String _searchQuery = "";
  bool _isRatingFilter = false;
  bool _isFastDeliveryFilter = false;
  String? _selectedCategoryId;
  SortOption _sortOption = SortOption.nearest;

  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  bool _isLoadingVendors = true;
  bool _isLoadingCategories = true;

  // Real-time handles
  RealtimeChannel? _vendorChannel;
  RealtimeChannel? _productChannel;
  Timer? _poller;

  Map<String, List<String>> _vendorCategories = {};
  List<Map<String, dynamic>> _addressResults = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _setupRealtime();
    _fetchVendors();
    LocationStore().addListener(_fetchVendors);
    _poller =
        Timer.periodic(const Duration(seconds: 60), (_) => _fetchVendors());
    _setupProductsRealtime();
  }

  void _setupProductsRealtime() {
    _productChannel = SupabaseConfig.client
        .channel('public:products_home')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) => _fetchVendors())
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    LocationStore().removeListener(_fetchVendors);
    if (_vendorChannel != null) {
      SupabaseConfig.client.removeChannel(_vendorChannel!);
    }
    if (_productChannel != null) {
      SupabaseConfig.client.removeChannel(_productChannel!);
    }
    _poller?.cancel();
    super.dispose();
  }

  // ── Initialization Logic ────────────────────────────────────────

  void _setupRealtime() {
    _vendorChannel = SupabaseConfig.client
        .channel('public:vendors') // Match the standard channel name
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendors',
          callback: (payload) {
            debugPrint(
                ">>> REALTIME UPDATE: Vendors modified. Node: ${payload.newRecord['name']} Status: ${payload.newRecord['status']}");
            // Instant fetch on any vendor change
            _fetchVendors();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    "Cloud Sync: Grid node ${payload.newRecord['status']} updated."),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green[700],
              ));
            }
          },
        )
        .subscribe();
  }

  Future<void> _setAddress(String label, String sub,
      {String? pin,
      String? house,
      String? phone,
      double? lat,
      double? lng}) async {
    final store = LocationStore();
    final finalLat = lat ?? store.selectedLocation?.latitude ?? 0;
    final finalLng = lng ?? store.selectedLocation?.longitude ?? 0;

    await store.updateLocation(
      LatLng(finalLat, finalLng),
      sub,
      label,
      house: house ?? '',
      pincode: pin ?? '',
      phone: phone ?? '',
    );

    // 🚀 NEW: Save to Supabase so it shows up in "SAVED ADDRESSES"
    try {
      final String? uid = SupabaseConfig.client.auth.currentUser?.id ??
          SupabaseConfig.forcedUserId;
      if (uid != null && !uid.contains('guest')) {
        await SupabaseConfig.client.from('user_addresses').upsert({
          'user_id': uid,
          'label': label,
          'address_line1': sub,
          'house_number': house ?? '',
          'pincode': pin ?? '',
          'phone': phone ?? '',
          'latitude': finalLat,
          'longitude': finalLng,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint(">>> [ADDRESS] Saved to DB successfully");
      }
    } catch (e) {
      debugPrint(">>> [ADDRESS] DB Save Error: $e");
    }

    _fetchVendors();
  }

  Future<void> _showAddressDetailsDialog({
    String label = 'Current Location',
    required double lat,
    required double lng,
    required String address,
    required String pincode,
  }) async {
    final store = LocationStore();
    final houseCtrl = TextEditingController(text: store.houseNumber);
    final pinCtrl = TextEditingController(
        text: pincode.isNotEmpty ? pincode : store.pincode);
    final phoneCtrl = TextEditingController(
        text: store.phone.isNotEmpty
            ? store.phone
            : (ProfileStore().profile?['phone'] ?? ''));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Details',
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(address,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[600])),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddressPicker(context);
                  },
                  child: const Text("Change",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: houseCtrl,
              label: 'HOUSE / FLAT / BUILDING NUMBER *',
              hint: 'e.g. Flat 402, Sai Residency',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: pinCtrl,
                    label: 'PINCODE *',
                    hint: '6-digit code',
                    icon: Icons.pin_drop_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: phoneCtrl,
                    label: 'CONTACT PHONE *',
                    hint: '10-digit number',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (houseCtrl.text.isEmpty ||
                      pinCtrl.text.isEmpty ||
                      phoneCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text("Please fill all required fields (*)")));
                    return;
                  }
                  Navigator.pop(ctx);
                  _setAddress(
                    label,
                    address,
                    house: houseCtrl.text.trim(),
                    pin: pinCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    lat: lat,
                    lng: lng,
                  );
                },
                child: Text('Confirm Delivery Location',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey[500],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(icon, size: 20, color: ProTheme.primary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchCategories() async {
    // 1. Show cached categories immediately
    final cached = MenuStore().getCategories();
    if (cached.isNotEmpty) {
      setState(() {
        _categories = cached;
        _isLoadingCategories = false;
      });
    }

    try {
      final data =
          await SupabaseConfig.client.from('categories').select().order('name');
      if (mounted) {
        final List<Map<String, dynamic>> freshCats =
            List<Map<String, dynamic>>.from(data);
        MenuStore().updateCategories(freshCats);
        setState(() {
          _categories = freshCats;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Category fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  bool _isFetching = false;

  Future<void> _fetchVendors() async {
    if (!mounted || _isFetching) return;
    _isFetching = true;

    // 1. Show cached vendors immediately for 'instant' feel
    final cached = MenuStore().getVendors();
    if (cached.isNotEmpty && _vendors.isEmpty) {
      setState(() {
        _vendors = cached;
        _isLoadingVendors = false;
        _applyFilters();
      });
    }

    // Only show full loader if we have NO vendors in cache either
    if (_vendors.isEmpty) {
      setState(() => _isLoadingVendors = true);
    }

    try {
      final store = LocationStore();
      if (store.selectedLocation == null && !store.isInitialized) {
        await store.loadFromDisk();
      }

      final lat = store.selectedLocation?.latitude;
      final lng = store.selectedLocation?.longitude;

      if (lat == null || lng == null) {
        debugPrint("No location selected, skipping vendor fetch");
        if (mounted) setState(() => _isLoadingVendors = false);
        return;
      }

      // 🛰️ Calling V23 RPC for latest Logistics Grid data (includes is_open, open_time, close_time)
      final response = await SupabaseConfig.client.rpc(
        'get_nearby_vendors_v23',
        params: {'p_lat': lat, 'p_lng': lng},
      ).timeout(const Duration(seconds: 15));

      final list = List<dynamic>.from(response ?? []);

      if (mounted) {
        // 🚀 Category Enrichment: Fetch which categories each vendor serves
        final vendorIds = list.map((e) => e['id'].toString()).toList();
        if (vendorIds.isNotEmpty) {
          final catRes = await SupabaseConfig.client
              .from('products')
              .select('vendor_id, category_id, category')
              .inFilter('vendor_id', vendorIds)
              .eq('is_active', true);

          final Map<String, List<String>> newMapping = {};
          for (var row in (catRes as List)) {
            final vid = row['vendor_id'].toString();
            final cid = row['category_id']?.toString() ?? '';
            final cname = row['category']?.toString() ?? '';

            if (!newMapping.containsKey(vid)) newMapping[vid] = [];

            if (cid.isNotEmpty && !newMapping[vid]!.contains(cid)) {
              newMapping[vid]!.add(cid);
            }
            if (cname.isNotEmpty &&
                !newMapping[vid]!.contains(cname.toLowerCase())) {
              newMapping[vid]!.add(cname.toLowerCase());
            }
          }

          setState(() {
            final List<Map<String, dynamic>> freshVendors =
                list.map((e) => Map<String, dynamic>.from(e)).toList();
            _vendors = freshVendors;
            MenuStore().updateVendors(freshVendors);
            _vendorCategories = newMapping;
            _applyFilters();
            _isLoadingVendors = false;
          });
        } else {
          setState(() {
            _vendors = [];
            _vendorCategories = {};
            _applyFilters();
            _isLoadingVendors = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Vendor fetch error: $e");
      if (mounted) setState(() => _isLoadingVendors = false);
    } finally {
      _isFetching = false;
    }
  }

  void _applyFilters() {
    var rawList = _vendors.where((v) {
      final String vendorId = v['id']?.toString() ?? '';
      final name = (v['name'] ?? "").toString().toLowerCase();
      final cuisine = (v['cuisine_type'] ?? "").toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      // Filter chips
      if (_isRatingFilter) {
        final r = double.tryParse(v['rating']?.toString() ?? "0") ?? 0;
        if (r < 4.0) return false;
      }
      if (_isFastDeliveryFilter) {
        final dist =
            double.tryParse(v['distance_km']?.toString() ?? "99") ?? 99;
        final time = v['delivery_time']?.toString().toLowerCase() ?? "";
        // Fast delivery if either very close (<5km) OR explicitly marked fast
        if (dist > 5.0 && !time.contains('20') && !time.contains('15'))
          return false;
      }

      // Keyword & Category filters
      if (_selectedCategoryId != null) {
        final bool idMatch =
            _vendorCategories[vendorId]?.contains(_selectedCategoryId!) ??
                false;
        if (idMatch) return true;

        // Fallback: Check if the category name exists in the vendor's items (legacy support)
        final categoryName = _categories.firstWhere(
                (c) => c['id'] == _selectedCategoryId,
                orElse: () => {})['name'] ??
            "";
        if (categoryName.isNotEmpty) {
          final bool nameMatch = _vendorCategories[vendorId]
                  ?.any((c) => c.toLowerCase() == categoryName.toLowerCase()) ??
              false;
          if (nameMatch) return true;
        }
        return false;
      }

      if (query.isEmpty) return true;
      if (query == "veg") return v['is_pure_veg'] != false;
      if (query == "offer") return v['has_offers'] != false;

      // Search fallback: Check name or cuisine
      return name.contains(query) || cuisine.contains(query);
    }).toList();

    // Apply Sorting
    switch (_sortOption) {
      case SortOption.nearest:
        rawList.sort((a, b) =>
            (double.tryParse(a['distance_km']?.toString() ?? "999") ?? 999)
                .compareTo(
                    double.tryParse(b['distance_km']?.toString() ?? "999") ??
                        999));
        break;
      case SortOption.rating:
        rawList.sort((a, b) =>
            (double.tryParse(b['rating']?.toString() ?? "0") ?? 0).compareTo(
                double.tryParse(a['rating']?.toString() ?? "0") ?? 0));
        break;
      case SortOption.priceLowHigh:
        rawList.sort((a, b) =>
            (double.tryParse(a['price_for_two']?.toString() ?? "0") ?? 0)
                .compareTo(
                    double.tryParse(b['price_for_two']?.toString() ?? "0") ??
                        0));
        break;
      case SortOption.priceHighLow:
        rawList.sort((a, b) =>
            (double.tryParse(b['price_for_two']?.toString() ?? "0") ?? 0)
                .compareTo(
                    double.tryParse(a['price_for_two']?.toString() ?? "0") ??
                        0));
        break;
    }

    _filteredVendors = rawList;
  }

  // ── UI Building Blocks ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationStore(),
      builder: (context, _) {
        final store = LocationStore();

        // 🚀 SMART LABELLING: Use area/street as title if default label is generic
        // 🏷 ADDRESS LABEL LOGIC
        String displayLabel = store.selectedLabel;
        String displayAddress = store.selectedAddress;

        // If generic label, try to use first part of address for character
        if (displayLabel == "Current Location" || displayLabel == "Address") {
          final parts = displayAddress.split(',');
          if (parts.isNotEmpty) {
            displayLabel = parts[0].trim();
            displayAddress = parts.skip(1).join(', ').trim();
          }
        }

        final String fullDisplayAddress =
            "${store.houseNumber.isNotEmpty ? '${store.houseNumber}, ' : ''}$displayAddress${store.pincode.isNotEmpty ? ' - ${store.pincode}' : ''}";
        // The user's instruction had `final String displayLabel = store.selectedLabel;` here, but it was already defined above.
        // Keeping the original `displayLabel` definition and removing the redundant one.

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // 1. Header with Location & Notify
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.location_on,
                              color: ProTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _showAddressPicker(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(displayLabel,
                                        style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: ProTheme.dark)),
                                    const Icon(Icons.keyboard_arrow_down,
                                        size: 18, color: ProTheme.dark),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(fullDisplayAddress,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        height: 1.3)),
                              ],
                            ),
                          ),
                        ),
                        _buildNotificationIcon(),
                      ],
                    ),
                  ),
                ),

                // 2. Sticky Header: Search + Categories + Filters
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _HomeSearchDelegate(
                      controller: _searchController,
                      onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _applyFilters();
                          }),
                      categories: _categories,
                      isLoadingCategories: _isLoadingCategories,
                      isRatingFilter: _isRatingFilter,
                      isFastDeliveryFilter: _isFastDeliveryFilter,
                      sortOption: _sortOption,
                      searchQuery: _searchQuery,
                      selectedCategoryId: _selectedCategoryId,
                      onRatingFilter: () {
                        setState(() {
                          _isRatingFilter = !_isRatingFilter;
                          _applyFilters();
                        });
                      },
                      onFastDeliveryFilter: () {
                        setState(() {
                          _isFastDeliveryFilter = !_isFastDeliveryFilter;
                          _applyFilters();
                        });
                      },
                      onSortTap: () => _showSortBottomSheet(context),
                      onFilterTap: () {
                        // Reset all filters
                        setState(() {
                          _isRatingFilter = false;
                          _isFastDeliveryFilter = false;
                          _selectedCategoryId = null;
                          _sortOption = SortOption.nearest;
                          _searchQuery = "";
                          _searchController.clear();
                          _applyFilters();
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("All filters reset"),
                                duration: Duration(milliseconds: 500)));
                      },
                      onRefresh: _fetchVendors,
                      onCategoryTap: (cat) {
                        setState(() {
                          if (_selectedCategoryId == cat['id']) {
                            _selectedCategoryId = null;
                            _searchQuery = "";
                            _searchController.clear();
                          } else {
                            _selectedCategoryId = cat['id'];
                            _searchQuery = cat['name'] ?? "";
                            _searchController.text = _searchQuery;
                          }
                          _applyFilters();
                        });
                      }),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 3. Offer & Pure Veg Banners
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildBannerBox(
                                "OFFER",
                                "ZONE",
                                "https://cdn-icons-png.flaticon.com/128/3655/3655160.png",
                                Colors.orange,
                                _searchQuery == "offer", () {
                          setState(() {
                            _searchQuery =
                                (_searchQuery == "offer") ? "" : "offer";
                            _applyFilters();
                          });
                        })),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildBannerBox(
                                "PURE",
                                "VEG",
                                "https://cdn-icons-png.flaticon.com/128/4163/4163765.png",
                                Colors.green,
                                _searchQuery == "veg", () {
                          setState(() {
                            _searchQuery = (_searchQuery == "veg") ? "" : "veg";
                            _applyFilters();
                          });
                        })),
                      ],
                    ),
                  ),
                ),

                // 4. Vendor Feed Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _searchQuery.isEmpty
                                ? "${_vendors.length} Popular Curries Nearby"
                                : "Found ${_filteredVendors.length} results",
                            style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: ProTheme.dark),
                          ),
                        ),
                        Text("View All ",
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: Colors.green),
                      ],
                    ),
                  ),
                ),

                // 5. The List
                _isLoadingVendors && _vendors.isEmpty
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildShimmerCard(),
                          childCount: 3,
                        ),
                      )
                    : _filteredVendors.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildRestoCard(_filteredVendors[i]),
                              childCount: _filteredVendors.length,
                            ),
                          ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Sub-Widgets ────────────────────────────────────────

  Widget _buildNotificationIcon() {
    return ListenableBuilder(
      listenable: NotificationStore(),
      builder: (context, _) {
        final count = NotificationStore().count;
        return Stack(
          children: [
            IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 28, color: ProTheme.dark),
                onPressed: () {
                  NotificationStore().reset();
                  Navigator.pushNamed(context, '/notifications');
                }),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Text(count.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBannerBox(String t1, String t2, String iconUrl,
      Color activeColor, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 85, // Increased height to prevent overflow
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isActive ? activeColor : const Color(0xFFF1F5F9),
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t1,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: ProTheme.dark,
                          height: 1.1)),
                  Text(t2,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: ProTheme.dark,
                          height: 1.1)),
                ],
              ),
            ),
            CachedNetworkImage(
              imageUrl: SupabaseConfig.imageUrl(iconUrl),
              width: 32,
              height: 32,
              memCacheHeight: 100,
              placeholder: (context, url) => Container(
                width: 32,
                height: 32,
                color: const Color(0xFFF1F5F9),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 800.ms, color: Colors.white70),
              errorWidget: (c, e, s) =>
                  Icon(Icons.stars_rounded, color: activeColor),
            ),
          ],
        ),
      ),
    );
  }

  // 🕒 REAL-TIME OPEN/CLOSE LOGIC
  bool _isCurrentlyOpen(Map<String, dynamic> vendor) {
    // 1. Manual Master Kill-Switch (Admin Control)
    final String status = (vendor['status'] ?? "").toString().toUpperCase();
    if (status == 'OFFLINE' || status == 'INACTIVE' || status == 'PAUSED')
      return false;
    if (vendor['is_open'] == false) return false;

    // 🚀 CONNECT REALTIME OVERRIDE: If Admin says ONLINE, we show it ACTIVE for testing
    // This ensures the toggle has immediate visual feedback.
    if (status == 'ONLINE' && vendor['is_open'] == true) return true;

    final openTime = vendor['open_time']?.toString();
    final closeTime = vendor['close_time']?.toString();

    if (openTime == null || closeTime == null) return true;

    try {
      final now = DateTime.now();
      final nowTime = now.hour * 100 + now.minute;
      final openParts = openTime.split(':');
      final closeParts = closeTime.split(':');
      final openVal = int.parse(openParts[0]) * 100 + int.parse(openParts[1]);
      final closeVal =
          int.parse(closeParts[0]) * 100 + int.parse(closeParts[1]);

      if (closeVal < openVal) {
        return nowTime >= openVal || nowTime <= closeVal;
      }
      return nowTime >= openVal && nowTime <= closeVal;
    } catch (e) {
      return true;
    }
  }

  Widget _buildRestoCard(Map<String, dynamic> v) {
    String imageUrl = SupabaseConfig.imageUrl(
        v['banner_url'] ?? v['image_url'] ?? v['image']);
    final bool isOffline = !_isCurrentlyOpen(v);

    return InkWell(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => MenuScreen(vendor: v)));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            // 1. Large Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: isOffline
                          ? const ColorFilter.mode(
                              Colors.grey, BlendMode.saturation)
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl.trim(),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheHeight: 400,
                        maxWidthDiskCache: 800,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1200.ms, color: Colors.white70),
                        errorWidget: (c, e, s) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.grey, size: 40)),
                      ),
                    ),
                    if (isOffline)
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "CLOSED",
                            style: GoogleFonts.outfit(
                              color: Colors.red[900],
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 2. Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(v['name'] ?? "Curry Point",
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ProTheme.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.green, size: 12),
                            Text(" ${v['rating'] ?? '4.2'}",
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      "${v['cuisine_type'] ?? 'Premium Indian'} • ₹${v['price_for_two'] ?? '200'} for two",
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("${v['delivery_time'] ?? '25-30 mins'}",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                      const Icon(Icons.directions_bike,
                          size: 14, color: ProTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                          "${v['distance_km'] != null ? (v['distance_km'] is num ? v['distance_km'].toStringAsFixed(1) : v['distance_km']) : '1.2'} km",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[600])),
                      const Spacer(),
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(v['address'] ?? "Nearby Area",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(8),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color ?? ProTheme.dark)),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          Container(
              height: 190,
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(
              height: 20, width: double.infinity, color: Colors.grey[100]),
          const SizedBox(height: 8),
          Container(height: 15, width: 150, color: Colors.grey[100]),
        ],
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1.seconds, color: Colors.white.withOpacity(0.5)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: "https://cdn-icons-png.flaticon.com/512/7486/7486744.png",
            width: 120,
            color: Colors.grey.withOpacity(0.3),
            placeholder: (context, url) => const SizedBox(height: 120),
          ),
          const SizedBox(height: 20),
          Text("No results found for '$_searchQuery'",
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold)),
          Text("Try searching for something else like 'Biryani'",
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
          TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = "";
                  _searchController.clear();
                  _selectedCategoryId = null;
                  _isRatingFilter = false;
                  _isFastDeliveryFilter = false;
                  _applyFilters();
                });
              },
              child: const Text("Clear Filters",
                  style: TextStyle(
                      color: Color(0xFFFF4500), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _buildActionFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: ProTheme.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showAddressPicker(BuildContext context) {
    final uid = SupabaseConfig.forcedUserId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Deliver Where?",
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ProTheme.dark)),
                      IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  Text("Choose a saved address or use GPS",
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[500])),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Addresses List
            Expanded(
              child: StatefulBuilder(
                builder: (modalCtx, setModalState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // 🔍 LIVE SEARCH BOX
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16)),
                              child: TextField(
                                onChanged: (v) async {
                                  if (v.length > 2) {
                                    final results =
                                        await LocationService.searchPlaces(v);
                                    setModalState(() {
                                      _addressResults = results;
                                    });
                                  } else {
                                    setModalState(() {
                                      _addressResults = [];
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Search area, street or landmark...',
                                  hintStyle: GoogleFonts.inter(
                                      color: Colors.grey[400], fontSize: 14),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Colors.grey, size: 20),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),

                            // 🚀 SEARCH RESULTS (OVERLAY-STYLE)
                            if (_addressResults.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                constraints:
                                    const BoxConstraints(maxHeight: 250),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 10)
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _addressResults.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final res = _addressResults[i];
                                    return ListTile(
                                      leading: const Icon(
                                          Icons.location_on_outlined,
                                          size: 18),
                                      title: Text(res['display_name'] ?? "",
                                          maxLines: 2,
                                          style:
                                              GoogleFonts.inter(fontSize: 13)),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        _showAddressDetailsDialog(
                                          label: "Searched Location",
                                          lat: (res['lat'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                          lng: (res['lon'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                          address: res['display_name'] ?? "",
                                          pincode:
                                              "", // Will be filled in dialog or fetched
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 📍 CURRENT LOCATION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final pos =
                                await LocationService.getCurrentPosition();
                            if (pos != null) {
                              final details = await LocationService
                                  .getDetailedAddressFromLatLng(
                                      pos.latitude, pos.longitude);

                              final String addr = details['full_address'] ??
                                  await LocationService.getAddressFromLatLng(
                                      pos.latitude, pos.longitude);

                              if (mounted) {
                                _showAddressDetailsDialog(
                                  lat: pos.latitude,
                                  lng: pos.longitude,
                                  address: addr,
                                  pincode: details['postcode'] ?? '',
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFFEF08A)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFFFD700),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.my_location,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Use Current Location",
                                          style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: ProTheme.dark)),
                                      Text("Enable GPS for accurate delivery",
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Saved Addresses
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Container(
                                width: 3, height: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text("SAVED ADDRESSES",
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey[700],
                                    letterSpacing: 1.2)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: uid == null
                            ? const Center(
                                child: Text("Login to see saved addresses"))
                            : StreamBuilder<List<Map<String, dynamic>>>(
                                stream: SupabaseConfig.client
                                    .from('user_addresses')
                                    .stream(primaryKey: ['id']).eq(
                                        'user_id', uid),
                                builder: (ctx, snapshot) {
                                  if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return Center(
                                        child: Text("No saved addresses",
                                            style: TextStyle(
                                                color: Colors.grey[400])));
                                  }
                                  return ListView.builder(
                                      itemCount: snapshot.data!.length,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (ctx, i) {
                                        final a = snapshot.data![i];
                                        return ListTile(
                                          leading: Icon(
                                            a['label'] == 'Home'
                                                ? Icons.home_rounded
                                                : Icons.location_on,
                                            color: ProTheme.primary,
                                          ),
                                          title: Text(a['label'] ?? "Address",
                                              style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              "${a['address_line1'] ?? ''}${a['pincode'] != null ? ' | PIN: ' + a['pincode'] : ''}${a['phone'] != null ? ' | Ph: ' + a['phone'] : ''}",
                                              style: GoogleFonts.inter(
                                                  fontSize: 12)),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            final String label =
                                                a['label'] ?? "Address";
                                            final String line =
                                                a['address_line1'] ?? '';
                                            final String h =
                                                a['house_number']?.toString() ??
                                                    '';
                                            final String p =
                                                a['pincode']?.toString() ?? '';
                                            final String ph = (a['phone'] ??
                                                        a['phone_number'])
                                                    ?.toString() ??
                                                '';

                                            if (h.isEmpty ||
                                                p.isEmpty ||
                                                ph.isEmpty) {
                                              _showAddressDetailsDialog(
                                                label: label,
                                                lat: (a['latitude'] as num?)
                                                        ?.toDouble() ??
                                                    0,
                                                lng: (a['longitude'] as num?)
                                                        ?.toDouble() ??
                                                    0,
                                                address: line,
                                                pincode: p,
                                              );
                                            } else {
                                              await _setAddress(label, line,
                                                  pin: p,
                                                  house: h,
                                                  phone: ph,
                                                  lat: (a['latitude'] as num?)
                                                      ?.toDouble(),
                                                  lng: (a['longitude'] as num?)
                                                      ?.toDouble());
                                            }
                                          },
                                        );
                                      });
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text("Sort By",
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ProTheme.dark)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sortItem("Nearest (Distance)", SortOption.nearest),
            _sortItem("Top Rated", SortOption.rating),
            _sortItem("Price: Low to High", SortOption.priceLowHigh),
            _sortItem("Price: High to Low", SortOption.priceHighLow),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption opt) {
    bool isSel = _sortOption == opt;
    return ListTile(
      leading: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSel ? ProTheme.secondary : Colors.grey),
      title: Text(label,
          style: GoogleFonts.inter(
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              color: isSel ? ProTheme.secondary : ProTheme.dark)),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortOption = opt;
          _applyFilters();
        });
      },
    );
  }
}

// ─── Sticky Header Delegate ──────────────────────────────────────────────────

class _HomeSearchDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<Map<String, dynamic>> categories;
  final bool isLoadingCategories;
  final bool isRatingFilter;
  final bool isFastDeliveryFilter;
  final SortOption sortOption;
  final VoidCallback onRatingFilter;
  final VoidCallback onFastDeliveryFilter;
  final VoidCallback onSortTap;
  final VoidCallback onFilterTap;
  final VoidCallback onRefresh;
  final String searchQuery;
  final String? selectedCategoryId;
  final Function(Map<String, dynamic>) onCategoryTap;

  _HomeSearchDelegate(
      {required this.controller,
      required this.onChanged,
      required this.categories,
      required this.isLoadingCategories,
      required this.isRatingFilter,
      required this.isFastDeliveryFilter,
      required this.sortOption,
      required this.onRatingFilter,
      required this.onFastDeliveryFilter,
      required this.onSortTap,
      required this.onFilterTap,
      required this.onRefresh,
      required this.searchQuery,
      required this.selectedCategoryId,
      required this.onCategoryTap});

  @override
  double get minExtent => 250;
  @override
  double get maxExtent => 250;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: EdgeInsets.only(top: shrinkOffset > 20 ? 4 : 0),
      color: Colors.white,
      child: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search dishes or curries...',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // 2. Horizontal Categories
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: isLoadingCategories
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (ctx, i) => _loadingCat())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final c = categories[i];
                      final bool isSel = selectedCategoryId == c['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: InkWell(
                          onTap: () => onCategoryTap(c),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(
                                        color: isSel
                                            ? ProTheme.primary
                                            : Colors.transparent,
                                        width: 2.5)),
                                child: ClipOval(
                                    child: CachedNetworkImage(
                                        imageUrl: SupabaseConfig.imageUrl(
                                            c['image_url'] ?? c['image']),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(color: Colors.grey[100]),
                                        errorWidget: (a, b, c) => const Icon(
                                            Icons.fastfood,
                                            color: Colors.grey,
                                            size: 20))),
                              ),
                              const SizedBox(height: 6),
                              Text(c['name'] ?? "",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSel
                                          ? ProTheme.secondary
                                          : Colors.grey[700])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. Filters
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('', false, onFilterTap, icon: Icons.tune),
                _chip(
                    sortOption == SortOption.nearest
                        ? 'Sort By'
                        : sortOption.name
                            .replaceAll('LowHigh', ': Low to High')
                            .replaceAll('HighLow', ': High to Low')
                            .toUpperCase(),
                    sortOption != SortOption.nearest,
                    onSortTap,
                    showChevron: true),
                _chip('Rating 4.0+', isRatingFilter, () {
                  onRatingFilter();
                  // No need for separate call if onRatingFilter triggers setState in parent
                }),
                _chip('Fast Delivery', isFastDeliveryFilter, () {
                  onFastDeliveryFilter();
                }, icon: Icons.timer_outlined),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _loadingCat() {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(children: [
        Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFF1F5F9))),
        const SizedBox(height: 8),
        Container(width: 50, height: 10, color: const Color(0xFFF1F5F9))
      ]),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds);
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {IconData? icon, bool showChevron = false}) {
    final color = active ? ProTheme.secondary : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: active ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      active ? ProTheme.secondary : const Color(0xFFE2E8F0))),
          child: Row(
            children: [
              if (icon != null) Icon(icon, size: 14, color: color),
              if (icon != null) const SizedBox(width: 4),
              if (label.isNotEmpty)
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: color,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500)),
              if (showChevron) const SizedBox(width: 2),
              if (showChevron)
                Icon(Icons.keyboard_arrow_down, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
