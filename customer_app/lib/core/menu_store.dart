import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MenuStore extends ChangeNotifier {
  static final MenuStore _instance = MenuStore._internal();
  factory MenuStore() => _instance;
  MenuStore._internal();

  // VendorID -> List of Products
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _vendors = [];
  bool _isLoaded = false;

  Future<void> loadFromDisk() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('cached_menus');
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        _cache.clear();
        decoded.forEach((key, value) {
          if (value is List) {
            _cache[key] = List<Map<String, dynamic>>.from(value);
          }
        });

        final String? vendorData = prefs.getString('cached_vendors');
        if (vendorData != null) {
          final List decodedVendors = jsonDecode(vendorData);
          _vendors.clear();
          _vendors.addAll(List<Map<String, dynamic>>.from(decodedVendors));
        }

        _isLoaded = true;
        notifyListeners();
        debugPrint(
            ">>> [MENU STORE] Loaded ${_cache.length} menus, ${_categories.length} categories, and ${_vendors.length} vendors from cache");
      }
    } catch (e) {
      debugPrint("Error loading menus from disk: $e");
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_menus', jsonEncode(_cache));
      await prefs.setString('cached_categories', jsonEncode(_categories));
      await prefs.setString('cached_vendors', jsonEncode(_vendors));
    } catch (e) {
      debugPrint("Error saving menus to disk: $e");
    }
  }

  List<Map<String, dynamic>> getMenu(String vendorId) {
    return _cache[vendorId] ?? [];
  }

  void updateMenu(String vendorId, List<Map<String, dynamic>> products) {
    _cache[vendorId] = products;
    _saveToDisk();
    notifyListeners();
  }

  List<Map<String, dynamic>> getCategories() => _categories;

  void updateCategories(List<Map<String, dynamic>> cats) {
    _categories.clear();
    _categories.addAll(cats);
    _saveToDisk();
    notifyListeners();
  }

  List<Map<String, dynamic>> getVendors() => _vendors;

  void updateVendors(List<Map<String, dynamic>> vs) {
    _vendors.clear();
    _vendors.addAll(vs);
    _saveToDisk();
    notifyListeners();
  }
}
