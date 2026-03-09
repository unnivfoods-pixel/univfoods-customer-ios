import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';

class FavoriteStore {
  // Observable list of favorite vendor/product IDs
  static final ValueNotifier<Set<String>> favorites =
      ValueNotifier<Set<String>>({});
  static final ValueNotifier<Set<String>> productFavorites =
      ValueNotifier<Set<String>>({});

  // Cache of details for display
  static final Map<String, Map<String, dynamic>> favoriteDetails = {};

  static bool isFavorite(String id) {
    return favorites.value.contains(id.toString());
  }

  static bool isProductFavorite(String id) {
    return productFavorites.value.contains(id.toString());
  }

  static Future<void> sync(List<dynamic> dbFavorites) async {
    final uid = SupabaseConfig.forcedUserId;
    if (uid == null) return;

    final Set<String> newFavs = {};
    final Set<String> newProdFavs = {};

    for (var f in dbFavorites) {
      if (f['vendor_id'] != null) {
        final vId = f['vendor_id'].toString();
        newFavs.add(vId);
        if (f['vendor_details'] != null) {
          favoriteDetails[vId] = Map<String, dynamic>.from(f['vendor_details']);
        }
      }
      if (f['product_id'] != null) {
        final pId = f['product_id'].toString();
        newProdFavs.add(pId);
      }
    }
    favorites.value = newFavs;
    productFavorites.value = newProdFavs;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_fav_vendors_$uid', newFavs.toList());
    await prefs.setStringList('local_fav_products_$uid', newProdFavs.toList());
  }

  static Future<void> toggle(Map<String, dynamic> vendor) async {
    final id = vendor['id']?.toString();
    if (id == null) return;

    final current = Set<String>.from(favorites.value);
    final user = SupabaseConfig.client.auth.currentUser;
    final userId = user?.id ?? SupabaseConfig.forcedUserId;

    if (current.contains(id)) {
      current.remove(id);
      favoriteDetails.remove(id);
      if (userId != null) {
        try {
          await SupabaseConfig.client
              .from('user_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('vendor_id', id)
              .filter('product_id', 'is', 'null');
        } catch (e) {
          debugPrint("Error deleting favorite: $e");
        }
      }
    } else {
      current.add(id);
      favoriteDetails[id] = vendor;
      if (userId != null) {
        try {
          await SupabaseConfig.client.from('user_favorites').upsert({
            'user_id': userId,
            'vendor_id': id,
            'product_id': null,
          });
        } catch (e) {
          debugPrint("Error adding favorite: $e");
        }
      }
    }
    favorites.value = current;
    final uid = SupabaseConfig.forcedUserId;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('local_fav_vendors_$uid', current.toList());
    }
  }

  static Future<void> toggleProduct(Map<String, dynamic> product) async {
    final id = product['id']?.toString();
    if (id == null) return;

    final current = Set<String>.from(productFavorites.value);
    final user = SupabaseConfig.client.auth.currentUser;
    final userId = user?.id ?? SupabaseConfig.forcedUserId;

    if (current.contains(id)) {
      current.remove(id);
      if (userId != null) {
        try {
          await SupabaseConfig.client
              .from('user_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('product_id', id);
        } catch (e) {
          debugPrint("Error deleting product favorite: $e");
        }
      }
    } else {
      current.add(id);
      if (userId != null) {
        try {
          await SupabaseConfig.client.from('user_favorites').upsert({
            'user_id': userId,
            'product_id': id,
            'vendor_id': product['vendor_id'],
          });
        } catch (e) {
          debugPrint("Error adding product favorite: $e");
        }
      }
    }
    productFavorites.value = current;
    final uid = SupabaseConfig.forcedUserId;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('local_fav_products_$uid', current.toList());
    }
  }

  static Future<void> loadLocal() async {
    final uid = SupabaseConfig.forcedUserId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      favorites.value =
          (prefs.getStringList('local_fav_vendors_$uid') ?? []).toSet();
      productFavorites.value =
          (prefs.getStringList('local_fav_products_$uid') ?? []).toSet();
    } catch (e) {
      debugPrint("Error loading local favorites: $e");
    }
  }
}
