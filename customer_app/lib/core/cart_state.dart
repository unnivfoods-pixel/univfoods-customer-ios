import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GlobalCart extends ChangeNotifier {
  // Singleton instance
  static final GlobalCart _instance = GlobalCart._internal();
  factory GlobalCart() => _instance;
  GlobalCart._internal();

  Map<String, dynamic>? currentVendor;
  final Map<String, int> items = {}; // ProductID -> Qty
  final Map<String, dynamic> productDetails = {}; // ProductID -> Full Object

  // Detected Location Cache
  String? detectedAddress;
  double? detectedLat;
  double? detectedLng;

  bool _isLoaded = false;
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartData = prefs.getString('global_cart_items');
      final String? vendorData = prefs.getString('global_cart_vendor');
      final String? detailsData = prefs.getString('global_cart_details');

      if (cartData != null) {
        final Map<String, dynamic> decoded = jsonDecode(cartData);
        items.clear();
        decoded.forEach((key, value) {
          if (value is int) items[key.toString()] = value;
        });
      }

      if (vendorData != null) {
        currentVendor = jsonDecode(vendorData);
      }

      if (detailsData != null) {
        final Map<String, dynamic> decoded = jsonDecode(detailsData);
        productDetails.clear();
        decoded.forEach((key, value) {
          productDetails[key.toString()] = value;
        });
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('global_cart_items', jsonEncode(items));
      if (currentVendor != null) {
        await prefs.setString('global_cart_vendor', jsonEncode(currentVendor));
      } else {
        await prefs.remove('global_cart_vendor');
      }
      await prefs.setString('global_cart_details', jsonEncode(productDetails));
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  void addItem(Map<String, dynamic> product, Map<String, dynamic> vendor) {
    // If diverse vendor, clear cart (simple logic for now)
    if (currentVendor != null && currentVendor!['id'] != vendor['id']) {
      clear(notify: false); // Don't notify yet, wait for add
    }

    currentVendor = vendor;
    final String id = product['id'].toString();
    items[id] = (items[id] ?? 0) + 1;
    productDetails[id] = product;
    _save();
    notifyListeners();
  }

  void removeItem(dynamic rawId) {
    final String productId = rawId.toString();
    if (!items.containsKey(productId)) return;

    if (items[productId]! > 1) {
      items[productId] = items[productId]! - 1;
    } else {
      items.remove(productId);
      productDetails.remove(productId);
    }

    if (items.isEmpty) {
      currentVendor = null;
    }
    _save();
    notifyListeners();
  }

  void clear({bool notify = true}) {
    items.clear();
    productDetails.clear();
    currentVendor = null;
    _save();
    if (notify) notifyListeners();
  }

  double getTotal() {
    double total = 0;
    items.forEach((key, qty) {
      final details = productDetails[key];
      final price = details?['discount_price'] ?? details?['price'] ?? 0;
      total += (double.parse(price.toString()) * qty);
    });
    return total;
  }

  double get totalPrice => getTotal();

  int getItemCount(String productId) {
    return items[productId] ?? 0;
  }
}
