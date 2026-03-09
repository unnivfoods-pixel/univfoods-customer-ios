import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_product_screen.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _loading = false;
  String _searchQuery = "";
  String _activeFilter = "ALL";
  String _priceFilter = "ALL";
  String _spiceFilter = "ALL";

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.bootstrapData == null) {
      _loading = true;
      SupabaseConfig.bootstrap().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  void _applyFilters(List<Map<String, dynamic>> products) {
    _filteredProducts = products.where((p) {
      final matchesSearch = p['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_activeFilter == "OUT_OF_STOCK") {
        matchesStatus = (p['is_available'] ?? true) == false;
      } else if (_activeFilter == "AVAILABLE") {
        matchesStatus = (p['is_available'] ?? true) == true;
      }

      bool matchesPrice = true;
      final price = p['price'] is num
          ? p['price']
          : double.tryParse(p['price'].toString()) ?? 0.0;
      if (_priceFilter == "BUDGET") {
        matchesPrice = price < 100;
      } else if (_priceFilter == "MID") {
        matchesPrice = price >= 100 && price <= 250;
      } else if (_priceFilter == "PREMIUM") {
        matchesPrice = price > 250;
      }

      bool matchesSpice = true;
      if (_spiceFilter != "ALL") {
        matchesSpice = p['spice_level']?.toString() == _spiceFilter;
      }

      return matchesSearch && matchesStatus && matchesPrice && matchesSpice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseConfig.notifier,
      builder: (context, _) {
        final menuData = SupabaseConfig.bootstrapData?['menu'];
        final List<Map<String, dynamic>> products = (menuData != null)
            ? List<Map<String, dynamic>>.from(menuData)
            : <Map<String, dynamic>>[];

        _applyFilters(products);

        return Column(
          children: [
            _buildHeader(products.length),
            Expanded(
              child: products.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ASSET VAULT",
                      style: ProTheme.label
                          .copyWith(fontSize: 10, letterSpacing: 2)),
                  Text("${_filteredProducts.length} Assets Found",
                      style: ProTheme.title.copyWith(fontSize: 18)),
                ],
              ),
              IconButton(
                onPressed: _showFilterSheet,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ProTheme.dark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white, size: 18),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration:
                ProTheme.inputDecor("Search Vendor Assets...", Icons.search)
                    .copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("FILTER MATRIX",
                    style: ProTheme.header.copyWith(fontSize: 18)),
                const SizedBox(height: 24),
                _buildFilterLabel("AVAILABILITY"),
                _buildFilterPack(["ALL", "AVAILABLE", "OUT_OF_STOCK"],
                    _activeFilter, (v) => setState(() => _activeFilter = v)),
                const SizedBox(height: 20),
                _buildFilterLabel("PRICE BRACKET"),
                _buildFilterPack(["ALL", "BUDGET", "MID", "PREMIUM"],
                    _priceFilter, (v) => setState(() => _priceFilter = v)),
                const SizedBox(height: 20),
                _buildFilterLabel("SPICE LEVEL"),
                _buildFilterPack(["ALL", "Mild", "Medium", "Hot"], _spiceFilter,
                    (v) => setState(() => _spiceFilter = v)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ProTheme.ctaButton,
                    child: const Text("CLOSE GATE"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: ProTheme.label.copyWith(fontSize: 9, color: ProTheme.gray)),
    );
  }

  Widget _buildFilterPack(
      List<String> options, String current, Function(String) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        bool isSelected = current == opt;
        return GestureDetector(
          onTap: () {
            onSelect(opt);
            (context as Element).markNeedsBuild();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? ProTheme.primary : ProTheme.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(opt.replaceAll("_", " "),
                style: ProTheme.label.copyWith(
                    fontSize: 10,
                    color: isSelected ? ProTheme.dark : ProTheme.gray)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    bool isAvailable = item['is_available'] ?? true;
    return GestureDetector(
      onTap: () {
        final profile = SupabaseConfig.bootstrapData?['profile'];
        if (profile == null) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddEditProductScreen(
                    vendorId: profile['id'], product: item)));
      },
      child: Container(
        decoration: ProTheme.cardDecor,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                      item['image_url'] ?? 'https://via.placeholder.com/200',
                      fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.black45,
                      child: Center(
                          child: Text("₹${item['price']}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProTheme.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isAvailable ? "ONLINE" : "OFFLINE",
                          style: ProTheme.label.copyWith(
                              fontSize: 8,
                              color: isAvailable
                                  ? ProTheme.secondary
                                  : ProTheme.error)),
                      Transform.scale(
                        scale: 0.6,
                        child: Switch(
                          value: isAvailable,
                          onChanged: (v) async {
                            await SupabaseConfig.client.from('products').update(
                                {'is_available': v}).eq('id', item['id']);
                            SupabaseConfig.bootstrap();
                          },
                          activeColor: ProTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ).animate().fadeIn().scale(delay: 50.ms);
  }
}
