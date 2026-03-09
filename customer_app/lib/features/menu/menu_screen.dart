import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/supabase_config.dart';
import '../../core/cart_state.dart';
import '../../core/favorite_store.dart';
import '../../core/menu_store.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;
  const MenuScreen({super.key, required this.vendor});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _searchQuery = "";
  bool _showVegOnly = false;
  late Map<String, dynamic> _liveVendor;

  @override
  void initState() {
    super.initState();
    _liveVendor = widget.vendor;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client
          .from('vendors')
          .stream(primaryKey: ['id']).eq('id', widget.vendor['id']),
      builder: (context, vendorSnapshot) {
        if (vendorSnapshot.hasData && vendorSnapshot.data!.isNotEmpty) {
          _liveVendor = vendorSnapshot.data!.first;
        }

        final vendor = _liveVendor;

        final vendorImg = SupabaseConfig.imageUrl(
            vendor['banner_url'] ?? vendor['image_url'] ?? vendor['image']);
        final vendorCuisine = vendor['cuisine_type'] ?? 'Curry, Indian';
        final vendorName = vendor['name'] ?? "Vendor";
        final vendorRating = vendor['rating'] ?? "4.5";

        bool isCurrentlyOpen() {
          final String status =
              (vendor['status'] ?? "").toString().toUpperCase();
          if (status == 'OFFLINE' ||
              status == 'INACTIVE' ||
              status == 'PAUSED') {
            return false;
          }
          if (vendor['is_open'] == false) return false;
          if (status == 'ONLINE' && vendor['is_open'] == true) return true;

          final openTime = vendor['open_time']?.toString();
          final closeTime = vendor['close_time']?.toString();
          if (openTime == null || closeTime == null) return true;

          try {
            final now = DateTime.now();
            final nowTime = now.hour * 100 + now.minute;
            final openParts = openTime.split(':');
            final closeParts = closeTime.split(':');
            final openVal =
                int.parse(openParts[0]) * 100 + int.parse(openParts[1]);
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

        final isOffline = !isCurrentlyOpen();

        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: isOffline
              ? Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.red[50],
                  child: Text(
                    "RESTAURANT IS CURRENTLY OFFLINE",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.red[800],
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                )
              : null,
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: (vendor['id'] != null)
                ? SupabaseConfig.client
                    .from('products')
                    .stream(primaryKey: ['id'])
                    .eq('vendor_id', vendor['id'])
                    .timeout(const Duration(seconds: 15))
                : Stream.value(<Map<String, dynamic>>[]),
            builder: (context, snapshot) {
              final String vendorId = vendor['id']?.toString() ?? "";
              final cachedProducts = MenuStore().getMenu(vendorId);

              if (snapshot.hasError && cachedProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("Connection issue. Please retry.",
                          style: GoogleFonts.inter(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text("RETRY",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }

              // Background Sync Logic: Save to disc when data arrives
              if (snapshot.hasData && snapshot.data != null) {
                MenuStore().updateMenu(vendorId, snapshot.data!);
              }

              // Determine what to show
              final products = (snapshot.hasData && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : cachedProducts;

              if (products.isEmpty &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return _buildMenuSkeleton(
                    vendorImg, vendorName, vendorRating, vendorCuisine);
              }

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No items found.",
                          style: GoogleFonts.inter(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              final filtered = products.where((p) {
                if ((p['is_available'] ?? true) == false) return false;
                if (_showVegOnly && p['is_veg'] == false) return false;
                if (_searchQuery.isNotEmpty &&
                    !p['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())) return false;
                return true;
              }).toList();

              Map<String, List<Map<String, dynamic>>> grouped = {};
              for (var p in filtered) {
                String cat = p['category'] ?? "Other";
                grouped.putIfAbsent(cat, () => []).add(p);
              }

              return Stack(
                children: [
                  CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                  imageUrl: vendorImg,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  memCacheHeight: 400,
                                  placeholder: (context, url) => Container(
                                        height: 220,
                                        color: const Color(0xFFF1F5F9),
                                      )
                                          .animate(onPlay: (c) => c.repeat())
                                          .shimmer(
                                              duration: 1200.ms,
                                              color: Colors.white70),
                                  errorWidget: (c, e, s) => Container(
                                      height: 220,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.grey, size: 40))),
                              Positioned(
                                top: 40,
                                left: 16,
                                child: _buildCircleIcon(Icons.arrow_back,
                                    onTap: () => Navigator.pop(context)),
                              ),
                              Positioned(
                                top: 40,
                                right: 16,
                                child: ValueListenableBuilder<Set<String>>(
                                    valueListenable: FavoriteStore.favorites,
                                    builder: (context, favs, _) {
                                      final bool isFav =
                                          FavoriteStore.isFavorite(
                                              vendor['id']?.toString() ?? "");
                                      return _buildCircleIcon(
                                          isFav
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFav
                                              ? Colors.red
                                              : Colors.black, onTap: () {
                                        setState(() {
                                          FavoriteStore.toggle(vendor);
                                        });
                                      });
                                    }),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5))
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(vendorName,
                                                style: GoogleFonts.outfit(
                                                    fontSize: 22,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Row(
                                              children: [
                                                Text(vendorRating.toString(),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const Icon(Icons.star,
                                                    color: Colors.white,
                                                    size: 14),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(vendorCuisine,
                                          style: GoogleFonts.inter(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500)),
                                      const Divider(height: 20),
                                      Text("25-30 min  •  Free Delivery",
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverMenuHeaderDelegate(
                          onSearch: (v) => setState(() => _searchQuery = v),
                          onVegToggle: (v) => setState(() => _showVegOnly = v),
                          isVegOnly: _showVegOnly,
                        ),
                      ),
                      if (grouped.isEmpty)
                        const SliverFillRemaining(
                            child: Center(
                                child: Text(
                                    "No items match your search or filter.")))
                      else
                        for (var entry in grouped.entries) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              child: Text(entry.key,
                                  style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProductCard(
                                    entry.value[index], isOffline),
                                childCount: entry.value.length,
                              ),
                            ),
                          ),
                        ],
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: ListenableBuilder(
                      listenable: GlobalCart(),
                      builder: (context, _) {
                        final cartItems = GlobalCart().items;
                        if (cartItems.isEmpty || isOffline) {
                          return const SizedBox.shrink();
                        }
                        return Material(
                          color: const Color(0xFF2E8B57),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, '/cart'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 60,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("${cartItems.length} ITEMS",
                                          style: GoogleFonts.inter(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                      Text("₹${GlobalCart().totalPrice}",
                                          style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text("VIEW CART",
                                      style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.shopping_bag,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ).animate().slideY(begin: 1.0, end: 0.0).fadeIn();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCircleIcon(IconData icon,
      {Color color = Colors.black, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p, bool isOffline) {
    final bool isVeg = p['is_veg'] ?? true;
    final img = SupabaseConfig.imageUrl(p['image_url'] ?? p['image']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle,
                    color: isVeg ? Colors.green : Colors.red, size: 14),
                const SizedBox(height: 8),
                Text(p['name'] ?? "Dish",
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("₹${p['price']}",
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (p['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(p['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                        imageUrl: img.trim(),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        maxWidthDiskCache: 400,
                        placeholder: (context, url) => Container(
                                width: 100,
                                height: 100,
                                color: const Color(0xFFF1F5F9))
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1200.ms, color: Colors.white70),
                        errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.fastfood,
                                color: Colors.grey, size: 30))),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: ValueListenableBuilder<Set<String>>(
                        valueListenable: FavoriteStore.productFavorites,
                        builder: (context, favs, _) {
                          final isFav = FavoriteStore.isProductFavorite(
                              p['id']?.toString() ?? "");
                          return GestureDetector(
                            onTap: () => FavoriteStore.toggleProduct(p),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isFav ? Colors.red : Colors.grey,
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: GlobalCart(),
                builder: (context, _) {
                  final int count =
                      GlobalCart().getItemCount(p['id']?.toString() ?? "");

                  if (count > 0) {
                    return Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[800],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove,
                                color: Colors.white, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () => GlobalCart().removeItem(p['id']),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add,
                                color: Colors.white, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: isOffline
                                ? null
                                : () => GlobalCart().addItem(p, _liveVendor),
                          ),
                        ],
                      ),
                    );
                  }

                  return Material(
                    color: isOffline ? Colors.grey[200] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: isOffline ? 0 : 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                    child: InkWell(
                      onTap: isOffline
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Restaurant is offline")));
                            }
                          : () {
                              GlobalCart().addItem(p, _liveVendor);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 36,
                        alignment: Alignment.center,
                        child: Text("ADD",
                            style: GoogleFonts.outfit(
                                color:
                                    isOffline ? Colors.grey : Colors.green[800],
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSkeleton(
      String img, String name, dynamic rating, String cuisine) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            children: [
              CachedNetworkImage(
                  imageUrl: img,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheHeight: 400,
                  placeholder: (context, url) => Container(
                        height: 220,
                        color: const Color(0xFFF1F5F9),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 1200.ms, color: Colors.white70),
                  errorWidget: (c, e, s) => Container(
                      height: 220,
                      color: const Color(0xFFF1F5F9),
                      child:
                          const Icon(Icons.broken_image, color: Colors.grey))),
              Positioned(
                  top: 40,
                  left: 16,
                  child: _buildCircleIcon(Icons.arrow_back,
                      onTap: () => Navigator.pop(context))),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(name,
                                    style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900))),
                          ]),
                      const SizedBox(height: 8),
                      Text(cuisine,
                          style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 4,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemBuilder: (ctx, i) => Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20)),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 1.seconds, color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }
}

class _SliverMenuHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onSearch;
  final Function(bool) onVegToggle;
  final bool isVegOnly;

  _SliverMenuHeaderDelegate(
      {required this.onSearch,
      required this.onVegToggle,
      required this.isVegOnly});

  @override
  double get minExtent => 120;
  @override
  double get maxExtent => 120;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onSearch,
                    decoration: const InputDecoration(
                        hintText: "Search in menu...",
                        border: InputBorder.none,
                        isDense: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text("Veg Only"),
                selected: isVegOnly,
                onSelected: onVegToggle,
                avatar: const Icon(Icons.circle, color: Colors.green, size: 12),
                backgroundColor: Colors.white,
                selectedColor: Colors.green[50],
                checkmarkColor: Colors.green,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("Bestseller"),
                onSelected: (_) {},
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
