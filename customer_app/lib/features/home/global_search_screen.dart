import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import '../menu/menu_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Search Vendors
      final vendorRes = await SupabaseConfig.client
          .from('vendors')
          .select()
          .ilike('name', '%$query%')
          .limit(5);

      // 2. Search Products
      final productRes = await SupabaseConfig.client
          .from('products')
          .select('*, vendors(name, banner_url)')
          .ilike('name', '%$query%')
          .eq('is_available', true)
          .limit(10);

      final List<Map<String, dynamic>> combined = [];

      for (var v in vendorRes) {
        combined.add({...v, 'type': 'vendor'});
      }
      for (var p in productRes) {
        combined.add({...p, 'type': 'product'});
      }

      if (mounted) {
        setState(() {
          _results = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _performSearch,
          decoration: InputDecoration(
            hintText: "Search curries, pizza, or cafes",
            hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                _performSearch("");
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ProTheme.primary))
          : _results.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    if (item['type'] == 'vendor') {
                      return _buildVendorResult(item);
                    } else {
                      return _buildProductResult(item);
                    }
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.search, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? "Looking for something delicious?"
                : "No results for \"${_searchController.text}\"",
            textAlign: TextAlign.center,
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? "Search for your favorite restaurants or dishes"
                : "Try a different keyword or check for typos",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorResult(Map<String, dynamic> v) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: SupabaseConfig.imageUrl(
              v['banner_url'] ?? v['image_url'] ?? v['image']),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: Colors.grey[50]),
          errorWidget: (c, e, s) => Container(color: Colors.grey[100]),
        ),
      ),
      title: Text(v['name'],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      subtitle: Text("Restaurant • ${v['cuisine_type'] ?? 'Multi-cuisine'}",
          style: GoogleFonts.inter(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => MenuScreen(vendor: v))),
    );
  }

  Widget _buildProductResult(Map<String, dynamic> p) {
    final vendor = p['vendors'] ?? {};
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: SupabaseConfig.imageUrl(p['image_url'] ?? p['image']),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: Colors.grey[50]),
          errorWidget: (c, e, s) => Container(color: Colors.grey[100]),
        ),
      ),
      title: Text(p['name'],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      subtitle: Text("Dish • From ${vendor['name'] ?? 'Restaurant'}",
          style: GoogleFonts.inter(fontSize: 12)),
      trailing: Text("₹${p['price']}",
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: Colors.green)),
      onTap: () {
        if (vendor.isNotEmpty) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => MenuScreen(vendor: vendor)));
        }
      },
    );
  }
}
