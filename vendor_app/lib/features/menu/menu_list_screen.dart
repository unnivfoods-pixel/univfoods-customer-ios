import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/supabase_config.dart';
import 'add_edit_product_screen.dart';

class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key});

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _vendorId;

  @override
  void initState() {
    super.initState();
    _initVendorAndFetch();
  }

  Future<void> _initVendorAndFetch() async {
    try {
      // DEMO MODE: Fetch the first active vendor found
      // In prod, this would be: .eq('owner_id', SupabaseConfig.client.auth.currentUser!.id)
      final vendorData = await SupabaseConfig.client
          .from('vendors')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (vendorData != null) {
        _vendorId = vendorData['id'];
        _fetchProducts();
      } else {
        setState(() => _loading = false);
        // Handle no vendor case
      }
    } catch (e) {
      debugPrint('Error init vendor: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchProducts() async {
    if (_vendorId == null) return;
    try {
      final data = await SupabaseConfig.client
          .from('products')
          .select()
          .eq('vendor_id', _vendorId!)
          .order('created_at');

      setState(() {
        _products = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Fetch error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await SupabaseConfig.client.from('products').delete().eq('id', id);
      _fetchProducts();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Menu')),
      floatingActionButton: FloatingActionButton(
        onPressed: _vendorId == null
            ? null
            : () async {
                final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddEditProductScreen(vendorId: _vendorId!)));
                if (res == true) _fetchProducts();
              },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No items yet. Add your first curry!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final item = _products[index];
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item['image_url'] ?? '',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            memCacheHeight: 120,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[100],
                              child: const Center(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Icon(Icons.fastfood,
                                  color: Colors.grey, size: 24),
                            ),
                          ),
                        ),
                        title: Text(item['name']),
                        subtitle: Text('\$${item['price']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () async {
                                final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => AddEditProductScreen(
                                            vendorId: _vendorId!,
                                            product: item)));
                                if (res == true) _fetchProducts();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              onPressed: () => _deleteProduct(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
