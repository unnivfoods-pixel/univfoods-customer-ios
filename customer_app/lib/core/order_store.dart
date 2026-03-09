import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'supabase_config.dart';

class OrderStore extends ChangeNotifier {
  static final OrderStore _instance = OrderStore._internal();
  factory OrderStore() => _instance;
  OrderStore._internal();

  final List<Map<String, dynamic>> orders = [];
  bool hasLoaded = false;

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('cached_orders');
      if (data != null) {
        final List decoded = jsonDecode(data);
        orders.clear();
        orders.addAll(List<Map<String, dynamic>>.from(decoded));
        hasLoaded = true;
        notifyListeners();
        debugPrint(
            ">>> [ORDER STORE] Loaded ${orders.length} orders from cache");
      }
    } catch (e) {
      debugPrint("Error loading orders from disk: $e");
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_orders', jsonEncode(orders));
    } catch (e) {
      debugPrint("Error saving orders to disk: $e");
    }
  }

  Future<void> updateFromRealtime(Map<String, dynamic>? record) async {
    if (record == null) return;
    final String recordId =
        (record['order_id'] ?? record['id'] ?? '').toString().toLowerCase();
    if (recordId.isEmpty || recordId == 'null') return;

    debugPrint(">>> [ORDER STORE] Processing Realtime Update for: $recordId");

    final index = orders.indexWhere(
        (o) => (o['order_id'] ?? o['id']).toString().toLowerCase() == recordId);

    // 🔥 IMMEDIATE UPDATE: Apply the raw record first so status changes feel instant
    if (index != -1) {
      // 🛡️ REPAIR: Normalize all field variations before merging
      if (record.containsKey('order_status'))
        record['status'] = record['order_status'];
      if (record.containsKey('status'))
        record['order_status'] = record['status'];
      if (record.containsKey('total_amount'))
        record['total'] = record['total_amount'];
      if (record.containsKey('total')) record['total_amount'] = record['total'];

      orders[index] = {...orders[index], ...record};
      _saveToDisk();
      notifyListeners();
    } else {
      // Also normalize new record
      if (record.containsKey('order_status'))
        record['status'] = record['order_status'];
      if (record.containsKey('status'))
        record['order_status'] = record['status'];
      if (record.containsKey('total_amount'))
        record['total'] = record['total_amount'];
      if (record.containsKey('total')) record['total_amount'] = record['total'];

      orders.insert(0, record);
      _saveToDisk();
      notifyListeners();
    }

    // ⚡ SILENT HYDRATION: Fetch full details from stabilized view
    try {
      final fullRecord = await SupabaseConfig.client
          .from('order_tracking_stabilized_v1')
          .select()
          .eq('order_id', recordId)
          .maybeSingle();

      if (fullRecord != null && fullRecord.isNotEmpty) {
        final reIndex = orders.indexWhere((o) =>
            (o['order_id'] ?? o['id']).toString().toLowerCase() == recordId);
        if (reIndex != -1) {
          orders[reIndex] = {...orders[reIndex], ...fullRecord};
          _saveToDisk();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Order Detail Realtime Hydration Error: $e");
    }
  }

  void updateLiveLocation(Map<String, dynamic>? record) {
    if (record == null || record['order_id'] == null) return;
    final orderId = record['order_id'].toString().toLowerCase();
    final index = orders.indexWhere(
        (o) => (o['order_id'] ?? o['id']).toString().toLowerCase() == orderId);

    if (index != -1) {
      orders[index]['rider_live_lat'] = record['rider_lat'];
      orders[index]['rider_live_lng'] = record['rider_lng'];
      notifyListeners();
    }
  }

  Future<void> fetchOrders() async {
    String? uid = SupabaseConfig.forcedUserId ??
        SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final List<String> searchIds = [uid];

      if (uid.startsWith('sms_auth_')) {
        // ⬆️ LAZY UPGRADE: Now Supabase is initialized, find the master ID
        final phone =
            uid.replaceFirst('sms_auth_', '').replaceFirst(RegExp(r'^91'), '');
        searchIds.add('sms_auth_91$phone');

        try {
          final masterRes = await SupabaseConfig.client
              .from('customer_profiles')
              .select('id')
              .eq('phone', phone)
              .order('created_at', ascending: true)
              .limit(1)
              .maybeSingle();

          if (masterRes != null && masterRes['id'] != null) {
            final masterId = masterRes['id'].toString();
            debugPrint('>>> [ORDERS] Upgrading session: $uid → $masterId');
            searchIds.add(masterId);

            // saveSession: sets forcedUid + saves to disk + reactivates hub with master ID
            await SupabaseConfig.saveSession(masterId);
            uid = masterId;
          }
        } catch (e) {
          debugPrint('>>> [ORDERS] Upgrade lookup failed: $e');
        }
      } else {
        // Firebase UID — also cover any legacy sms_auth variants
        try {
          final profile = await SupabaseConfig.client
              .from('customer_profiles')
              .select('phone')
              .eq('id', uid)
              .maybeSingle();
          if (profile != null && profile['phone'] != null) {
            final phone = profile['phone'].toString();
            searchIds.add('sms_auth_$phone');
            searchIds.add('sms_auth_91$phone');
          }
        } catch (e) {
          debugPrint('>>> [ORDERS] Phone lookup failed: $e');
        }
      }

      debugPrint('>>> [ORDER FETCH] Searching with IDs: $searchIds');

      final res = await SupabaseConfig.client
          .from('order_tracking_stabilized_v1')
          .select()
          .inFilter('customer_id', searchIds)
          .order('created_at', ascending: false);

      // ⚡ REPAIR: Don't clear! We want instant display from cache while loading.
      final newOrders = List<Map<String, dynamic>>.from(res);
      orders.clear();
      orders.addAll(newOrders);
      hasLoaded = true;
      _saveToDisk();
      notifyListeners();
    } catch (e) {
      debugPrint("FETCH ORDERS ERROR: $e");
    } finally {
      hasLoaded = true;
      notifyListeners();
    }
  }

  void clear() {
    orders.clear();
    hasLoaded = false;
    notifyListeners();
  }
}
