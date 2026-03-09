import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../menu/menu_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  Stream<List<Map<String, dynamic>>>? _favoritesStream;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initFavoritesStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initFavoritesStream() {
    final user = SupabaseConfig.client.auth.currentUser;
    final userId = user?.id ?? SupabaseConfig.forcedUserId;

    // We use a stream controller to emit combined data
    // Or we hack the stream to start with empty or initial load.
    // Simpler: Just refresh on init.
    // But since this is a StreamBuilder, we should construct a stream that merges both.

    // Actually, let's just use a Future + Stream or a custom Stream.
    // For simplicity given the constraints:
    // We will listen to DB stream, AND load local prefs.
    // Then combine them in the stream transformation.

    if (userId == null) {
      _favoritesStream = Stream.value([]);
      return;
    }

    _favoritesStream = SupabaseConfig.client
        .from('user_favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((data) async {
          // 1. Fetch Local Favorites
          final prefs = await SharedPreferences.getInstance();
          final localVendorIds =
              prefs.getStringList('local_fav_vendors_$userId') ?? [];
          final localProductIds =
              prefs.getStringList('local_fav_products_$userId') ?? [];

          // 2. Convert DB data
          var favorites = List<Map<String, dynamic>>.from(data);

          // 3. Merge Local Data Stub (Create fake records for local favs if they don't exist in DB result)
          // This is tricky because we need the ID to delete it later.
          // For local-only items, we can assign a fake ID prefix 'local_'.

          final dbVendorIds =
              favorites.map((f) => f['vendor_id'].toString()).toSet();
          final dbProductIds =
              favorites.map((f) => f['product_id'].toString()).toSet();

          for (var vid in localVendorIds) {
            if (!dbVendorIds.contains(vid)) {
              favorites.add({
                'id': 'local_v_$vid',
                'user_id': userId,
                'vendor_id': vid,
                'product_id': null,
              });
            }
          }

          for (var pid in localProductIds) {
            if (!dbProductIds.contains(pid)) {
              favorites.add({
                'id': 'local_p_$pid',
                'user_id': userId,
                'vendor_id':
                    null, // We need to fetch vendor later, potentially tricky if we don't know it.
                'product_id': pid,
              });
            }
          }

          if (favorites.isEmpty) return [];

          final vendorIds = favorites
              .map((f) => f['vendor_id'])
              .where((id) => id != null)
              .map((e) => e.toString())
              .toSet()
              .toList();

          final productIds = favorites
              .map((f) => f['product_id'])
              .where((id) => id != null)
              .map((e) => e.toString())
              .toSet()
              .toList();

          Map<String, dynamic> vendorMap = {};
          Map<String, dynamic> productMap = {};

          if (vendorIds.isNotEmpty) {
            final vendors = await SupabaseConfig.client
                .from('vendors')
                .select()
                .filter('id', 'in', vendorIds);
            vendorMap = {for (var v in vendors) v['id'].toString(): v};
          }

          if (productIds.isNotEmpty) {
            final products = await SupabaseConfig.client
                .from('products')
                .select()
                .filter('id', 'in', productIds);
            productMap = {for (var p in products) p['id'].toString(): p};

            // For products, we also need their vendors to show context
            final productVendorIds =
                products.map((p) => p['vendor_id'].toString()).toSet().toList();
            if (productVendorIds.isNotEmpty) {
              final pVendors = await SupabaseConfig.client
                  .from('vendors')
                  .select()
                  .filter('id', 'in', productVendorIds);
              // Merge into vendorMap if not present
              for (var v in pVendors) {
                if (!vendorMap.containsKey(v['id'].toString())) {
                  vendorMap[v['id'].toString()] = v;
                }
              }
            }
          }

          return favorites.map((f) {
            final newMap = Map<String, dynamic>.from(f);
            if (f['vendor_id'] != null) {
              newMap['vendors'] = vendorMap[f['vendor_id'].toString()];
            }
            if (f['product_id'] != null) {
              final p = productMap[f['product_id'].toString()];
              newMap['products'] = p;
              if (p != null && p['vendor_id'] != null) {
                newMap['vendors'] = vendorMap[p['vendor_id'].toString()];
              }
            }
            return newMap;
          }).where((f) {
            // BOUTIQUE AVAILABILITY SYNC
            if (f['products'] != null &&
                (f['products']['is_available'] ?? true) == false) {
              return false;
            }
            return (f['vendors'] != null || f['products'] != null);
          }).toList();
        });
  }

  Future<void> _removeFavorite(String favoriteId,
      {String? vendorId, String? productId}) async {
    try {
      if (favoriteId.startsWith('local_')) {
        final prefs = await SharedPreferences.getInstance();
        final user = SupabaseConfig.client.auth.currentUser;
        final userId = user?.id ?? SupabaseConfig.forcedUserId;

        if (userId != null) {
          if (vendorId != null) {
            final list = prefs.getStringList('local_fav_vendors_$userId') ?? [];
            list.remove(vendorId.toString());
            await prefs.setStringList('local_fav_vendors_$userId', list);
          } else if (productId != null) {
            final list =
                prefs.getStringList('local_fav_products_$userId') ?? [];
            list.remove(productId.toString());
            await prefs.setStringList('local_fav_products_$userId', list);
          }
        }
        setState(() {
          // Force refresh logic if needed, but the StreamBuilder might not update automatically for local changes
          // unless we re-trigger the stream or use a hybrid implementation.
          // Simpler: Just call setState, the stream will naturally tick on next DB event,
          // BUT for local only changes, we need to manually trigger a UI update.
          // Since stream is listening to DB, it won't see local changes.
          // We need to re-initialize stream?
          _initFavoritesStream();
        });
      } else {
        await SupabaseConfig.client
            .from('user_favorites')
            .delete()
            .eq('id', favoriteId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from favorites")),
        );
      }
    } catch (e) {
      debugPrint("Remove Favorite Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("MY FAVORITES",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
                color: Colors.black)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: ProTheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ProTheme.primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "RESTAURANTS"),
            Tab(text: "CURRIES"),
          ],
        ),
      ),
      body: _favoritesStream == null
          ? const Center(child: Text("Please login to see favorites"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _favoritesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final favorites = snapshot.data ?? [];

                final vendorFavs =
                    favorites.where((f) => f['product_id'] == null).toList();
                final productFavs =
                    favorites.where((f) => f['product_id'] != null).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFavList(vendorFavs, true),
                    _buildFavList(productFavs, false),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildFavList(List<Map<String, dynamic>> items, bool isVendor) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isVendor ? Icons.restaurant : Icons.ramen_dining,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 24),
              Text(
                "NO ${isVendor ? 'RESTAURANTS' : 'CURRIES'} YET",
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Favorite items will appear here for quick access",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final f = items[index];
        if (isVendor) {
          final vendor = f['vendors'] ?? {};
          if (vendor.isEmpty) return const SizedBox.shrink();
          return _buildVendorCard(vendor, f['id'].toString());
        } else {
          final product = f['products'] ?? {};
          final vendor = f['vendors'] ?? {};
          if (product.isEmpty) return const SizedBox.shrink();
          return _buildProductCard(product, vendor, f['id'].toString());
        }
      },
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor, String favId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => MenuScreen(vendor: vendor))),
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl:
                SupabaseConfig.imageUrl(vendor['image_url'] ?? vendor['image']),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder: (c, u) => Container(color: Colors.grey[50]),
            errorWidget: (c, e, s) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.store)),
          ),
        ),
        title: Text(vendor['name'] ?? 'Restaurant',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text(vendor['cuisine_type'] ?? 'Cuisine',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () =>
              _removeFavorite(favId, vendorId: vendor['id'].toString()),
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildProductCard(
      Map<String, dynamic> product, Map<String, dynamic> vendor, String favId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        onTap: () {
          if (vendor.isNotEmpty) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => MenuScreen(vendor: vendor)));
          }
        },
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: SupabaseConfig.imageUrl(
                product['image_url'] ?? product['image']),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder: (c, u) => Container(color: Colors.grey[50]),
            errorWidget: (c, e, s) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.ramen_dining)),
          ),
        ),
        title: Text(product['name'] ?? 'Dish',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text(vendor['name'] ?? 'Restaurant',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () =>
              _removeFavorite(favId, productId: product['id'].toString()),
        ),
      ),
    ).animate().fadeIn().slideX();
  }
}
