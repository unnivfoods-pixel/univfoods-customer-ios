import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_config.dart';
import '../../core/location_store.dart';
import '../../core/enums.dart';
import '../menu/menu_screen.dart';
import '../../core/pro_theme.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialCenter;
  const MapScreen({super.key, this.initialCenter});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late LatLng _center;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  bool _loading = true;
  String? _selectedCategoryId;
  Map<String, List<String>> _vendorCategories = {};
  RealtimeChannel? _vendorChannel;
  bool _isMapView = true;
  bool _isRatingFilter = false;
  bool _isFastDeliveryFilter = false;

  SortOption _sortOption = SortOption.nearest;
  RealtimeChannel? _productChannel;
  Timer? _poller;

  List<Map<String, dynamic>> _categories = [];
  String _searchQuery = "";
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final store = LocationStore();
    _center = widget.initialCenter ??
        store.selectedLocation ??
        const LatLng(9.5126, 77.6335);

    _fetchCategories();
    _fetchVendors();
    _setupRealtime();
    store.addListener(_fetchVendors);
    _poller =
        Timer.periodic(const Duration(seconds: 60), (_) => _fetchVendors());
    _setupProductsRealtime();
  }

  void _setupProductsRealtime() {
    _productChannel = SupabaseConfig.client // Assign to _productChannel
        .channel('public:products') // Changed channel name
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) => _fetchVendors())
        .subscribe();
  }

  @override
  void dispose() {
    if (_vendorChannel != null) {
      SupabaseConfig.client.removeChannel(_vendorChannel!);
    }
    if (_productChannel != null) {
      SupabaseConfig.client.removeChannel(_productChannel!);
    }
    _poller?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    _vendorChannel = SupabaseConfig.client
        .channel('map-vendors')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vendors',
            callback: (payload) => _fetchVendors())
        .subscribe();
  }

  Future<void> _fetchCategories() async {
    try {
      final data =
          await SupabaseConfig.client.from('categories').select().order('name');
      if (mounted) {
        setState(() {
          _categories = [
            {'id': 'all', 'name': 'All'},
            ...List<Map<String, dynamic>>.from(data)
          ];
        });
      }
    } catch (e) {
      debugPrint("Category fetch error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_center, 14.0);
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _fetchVendors() async {
    try {
      if (_vendors.isEmpty) setState(() => _loading = true);

      final response = await SupabaseConfig.client.rpc(
        'get_nearby_vendors_v23',
        params: {'p_lat': _center.latitude, 'p_lng': _center.longitude},
      ).timeout(const Duration(seconds: 15));

      final list = List<dynamic>.from(response ?? []);
      final activeVendors =
          list.map((e) => Map<String, dynamic>.from(e)).toList();

      if (mounted) {
        // Enforce Category Enrichment
        final vendorIds = activeVendors.map((e) => e['id'].toString()).toList();
        final Map<String, List<String>> newMapping = {};

        if (vendorIds.isNotEmpty) {
          final catRes = await SupabaseConfig.client
              .from('products')
              .select('vendor_id, category_id, category')
              .inFilter('vendor_id', vendorIds)
              .eq('is_active', true);

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
        }

        setState(() {
          _vendors = activeVendors;
          _vendorCategories = newMapping;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      var rawList = _vendors.where((v) {
        final String vendorId = v['id']?.toString() ?? '';
        final name = (v['name'] ?? "").toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        // 1. Rating Filter
        if (_isRatingFilter) {
          final r = double.tryParse(v['rating']?.toString() ?? "0") ?? 0;
          if (r < 4.0) return false;
        }

        // 2. Fast Delivery Filter
        if (_isFastDeliveryFilter) {
          final dist =
              double.tryParse(v['distance_km']?.toString() ?? "99") ?? 99;
          final time = v['delivery_time']?.toString().toLowerCase() ?? "";
          if (dist > 5.0 && !time.contains('20') && !time.contains('15'))
            return false;
        }

        // 3. Category Filter
        if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
          final bool idMatch =
              _vendorCategories[vendorId]?.contains(_selectedCategoryId!) ??
                  false;
          if (idMatch) return true;

          final categoryName = _categories.firstWhere(
                  (c) => c['id'] == _selectedCategoryId,
                  orElse: () => {})['name'] ??
              "";
          if (categoryName.isNotEmpty) {
            final bool nameMatch = _vendorCategories[vendorId]
                    ?.contains(categoryName.toLowerCase()) ??
                false;
            if (!nameMatch) return false;
          } else {
            return false;
          }
        }

        // 4. Search Filter
        if (query.isNotEmpty) {
          return name.contains(query);
        }

        return true;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationStore(),
      builder: (context, _) {
        final store = LocationStore();
        if (store.selectedLocation != null) {
          _center = store.selectedLocation!;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // 1. Content (Map or List)
              _isMapView ? _buildMapView() : _buildListView(),

              // 2. Top UI (Search & Categories)
              _buildTopUI(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: _isSatellite
                  ? 'https://server.arcgisononline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: _isSatellite ? [] : const ['a', 'b', 'c'],
              userAgentPackageName: 'com.univfoods.curry',
            ),
            MarkerLayer(
              markers: [
                // Vendor Markers
                ..._filteredVendors.map((v) {
                  final lat = v['latitude'];
                  final lng = v['longitude'];
                  if (lat == null || lng == null)
                    return Marker(point: _center, child: const SizedBox());

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(LatLng(lat, lng), 15.0);
                        _scrollToVendor(v['id']);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ]),
                        child: const Center(
                            child: Icon(Icons.restaurant_rounded,
                                color: Colors.white, size: 14)),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
        // Locate & Layers Buttons
        Positioned(
          right: 16,
          bottom: 220,
          child: Column(
            children: [
              _mapBtn(Icons.gps_fixed, _getCurrentLocation),
              const SizedBox(height: 12),
              _mapBtn(Icons.layers_rounded, _toggleMapType),
            ],
          ),
        ),
        // Bottom Horizontal Cards
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 190,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredVendors.length,
                    itemBuilder: (ctx, i) =>
                        _buildVendorCard(_filteredVendors[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.only(top: 150), // Below search/categories
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredVendors.isEmpty
              ? const Center(child: Text("No vendors found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredVendors.length,
                  itemBuilder: (ctx, i) => _buildListCard(_filteredVendors[i]),
                ),
    );
  }

  Widget _buildTopUI() {
    return SafeArea(
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ]),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFFFD700)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                              hintText: "Search for curries...",
                              border: InputBorder.none,
                              hintStyle: GoogleFonts.inter(
                                  color: Colors.grey[500], fontSize: 14)))),
                  IconButton(
                    icon: Icon(
                        _isMapView ? Icons.list_rounded : Icons.map_rounded,
                        color: const Color(0xFFFFD700)),
                    onPressed: () => setState(() => _isMapView = !_isMapView),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('', false, _showSortSheet, icon: Icons.tune),
                _chip(
                    _sortOption == SortOption.nearest
                        ? 'Sort By'
                        : _sortOption.name
                            .replaceAll('LowHigh', ': Low to High')
                            .replaceAll('HighLow', ': High to Low')
                            .toUpperCase(),
                    _sortOption != SortOption.nearest,
                    _showSortSheet,
                    showChevron: true),
                _chip('Rating 4.0+', _isRatingFilter, () {
                  setState(() => _isRatingFilter = !_isRatingFilter);
                  _applyFilters();
                }),
                _chip('Fast Delivery', _isFastDeliveryFilter, () {
                  setState(
                      () => _isFastDeliveryFilter = !_isFastDeliveryFilter);
                  _applyFilters();
                }, icon: Icons.timer_outlined),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final catId = cat['id'].toString();
                final bool isSel = (_selectedCategoryId == catId) ||
                    (_selectedCategoryId == null && catId == 'all');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = (catId == 'all') ? null : catId;
                      });
                      _applyFilters();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFFFCF26) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSel
                                ? const Color(0xFFFFCF26)
                                : Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          if (isSel)
                            const Icon(Icons.check,
                                size: 14, color: Colors.black),
                          if (isSel) const SizedBox(width: 6),
                          Text(cat['name'] ?? "",
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSel ? Colors.black : Colors.black87)),
                        ],
                      ),
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

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SortSheet(
        selected: _sortOption,
        onSelect: (opt) {
          setState(() {
            _sortOption = opt;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {IconData? icon, bool showChevron = false}) {
    final color = active ? const Color(0xFFFFCF26) : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: active ? const Color(0xFFFFF9E6) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active
                      ? const Color(0xFFFFCF26)
                      : const Color(0xFFE2E8F0))),
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

  Widget _buildListCard(Map<String, dynamic> v) {
    String imageUrl = v['banner_url'] ?? v['image_url'] ?? v['logo_url'] ?? "";
    if (!imageUrl.startsWith('http'))
      imageUrl = "https://via.placeholder.com/300?text=${v['name'] ?? 'Curry'}";
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => MenuScreen(vendor: v))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                  imageUrl: SupabaseConfig.imageUrl(imageUrl),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: Colors.grey[50]),
                  errorWidget: (a, b, c) => Container(
                      color: Colors.grey[100], width: 80, height: 80)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['name'] ?? "",
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                      "${v['cuisine_type'] ?? 'Fast Food'}, ${v['address'] ?? 'Nearby'}",
                      style:
                          GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                      maxLines: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.green, size: 14),
                      Text(" ${v['rating'] ?? '4.5'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time,
                          color: Colors.grey, size: 14),
                      Text(" 25-30 min",
                          style: GoogleFonts.inter(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  bool _isSatellite = false;
  void _toggleMapType() {
    setState(() => _isSatellite = !_isSatellite);
  }

  void _scrollToVendor(dynamic id) {
    final idx = _filteredVendors.indexWhere((v) => v['id'] == id);
    if (idx != -1) {
      _scrollController.animateTo(idx * 266.0, // Fixed width + margin
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    }
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> v) {
    String imageUrl = v['banner_url'] ?? v['image_url'] ?? v['logo_url'] ?? "";
    if (!imageUrl.startsWith('http'))
      imageUrl = "https://via.placeholder.com/300?text=${v['name'] ?? 'Curry'}";
    return GestureDetector(
      onTap: () {
        final lat = v['latitude'];
        final lng = v['longitude'];
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 15.0);
        }
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => MenuScreen(vendor: v)));
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ]),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                    imageUrl: SupabaseConfig.imageUrl(imageUrl),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[50]),
                    errorWidget: (a, b, c) =>
                        Container(color: Colors.grey[100])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['name'] ?? "Curry House",
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ProTheme.dark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(v['address'] ?? "Nearby Area",
                      style: GoogleFonts.inter(
                          color: Colors.grey[500], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.green, size: 14),
                          Text(" ${v['rating'] ?? '5'}",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: ProTheme.dark)),
                        ],
                      ),
                      const Icon(Icons.delivery_dining_rounded,
                          color: Color(0xFFFFD700), size: 18),
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

  void _showVendorDetails(Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VendorSheet(vendor: v),
    );
  }
}

class _VendorSheet extends StatelessWidget {
  final Map<String, dynamic> vendor;
  const _VendorSheet({required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                      imageUrl: SupabaseConfig.imageUrl(vendor['image_url'] ??
                          vendor['banner_url'] ??
                          vendor['image']),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: Colors.grey[50]),
                      errorWidget: (a, b, c) => const Icon(Icons.restaurant))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(vendor['name'] ?? "",
                        style: GoogleFonts.outfit(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(vendor['cuisine_type'] ?? "Premium Curry",
                        style: GoogleFonts.inter(color: Colors.grey))
                  ])),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MenuScreen(vendor: vendor))),
            style: ElevatedButton.styleFrom(
                backgroundColor: ProTheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text("View Menu",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final SortOption selected;
  final ValueChanged<SortOption> onSelect;

  const _SortSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sort By",
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          _opt(SortOption.nearest, "Nearest (Distance)"),
          _opt(SortOption.rating, "Top Rated"),
          _opt(SortOption.priceLowHigh, "Price: Low to High"),
          _opt(SortOption.priceHighLow, "Price: High to Low"),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _opt(SortOption opt, String label) {
    final isSel = selected == opt;
    return InkWell(
      onTap: () => onSelect(opt),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          isSel ? const Color(0xFFFFCF26) : Colors.grey[400]!,
                      width: 2)),
              child: isSel
                  ? Center(
                      child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFCF26))))
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.black : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
