import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notification_service.dart';

class SupabaseConfig extends ChangeNotifier {
  static final SupabaseConfig _instance = SupabaseConfig._internal();
  factory SupabaseConfig() => _instance;
  SupabaseConfig._internal();
  static SupabaseConfig get notifier => _instance;

  static const String url = 'https://dxqcruvarqgnscenixzf.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

  static bool _initialized = false;
  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    await loadSession();
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Legacy compatibility getter
  static String? get forcedVendorId => client.auth.currentUser?.id;
  static Map<String, dynamic>? bootstrapData;

  // 1. Session Persistence (Now handled by Auth)
  static Future<void> saveSession(String userId) async {
    debugPrint(">>> [SESSION] Vendor Auth UID: $userId");
    await bootstrap();
  }

  static Future<void> loadSession() async {
    if (client.auth.currentUser?.id != null) {
      await bootstrap();
    }
  }

  static Future<void> logout() async {
    bootstrapData = null;
    await client.auth.signOut();
    AppRealtimeHub.deactivate();
  }

  static bool _bootstrapping = false;
  static bool _needsAnotherBootstrap = false;

  static Future<void> bootstrap() async {
    if (_bootstrapping) {
      _needsAnotherBootstrap = true;
      debugPrint(">>> [SYNC] Queueing secondary bootstrap...");
      return;
    }

    final userId = forcedVendorId ?? client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      _bootstrapping = true;
      debugPrint(">>> VENDOR BOOTSTRAP START: $userId");

      final response = await client
          .rpc('get_vendor_dashboard_v1', params: {'p_vendor_auth_id': userId});

      bootstrapData = response;
      _instance.notify();

      // Ensure Real-time is active
      AppRealtimeHub.activate(userId);
    } catch (e) {
      debugPrint(">>> VENDOR BOOTSTRAP FAILED: $e");
    } finally {
      _bootstrapping = false;
      if (_needsAnotherBootstrap) {
        _needsAnotherBootstrap = false;
        debugPrint(">>> [SYNC] Executing queued bootstrap...");
        bootstrap();
      }
    }
  }

  void notify() => notifyListeners();
}

// 3. Real-time Hub for Vendors
class AppRealtimeHub {
  static RealtimeChannel? _channel;

  static void activate(String userId) {
    deactivate();
    debugPrint(">>> [VENDOR HUB] ACTIVATING GLOBAL SYNC: $userId");

    _channel = SupabaseConfig.client
        .channel('vendor_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint(
                ">>> [SYNC] Order Change Detected: ${payload.eventType}");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            debugPrint(">>> [SYNC] Product/Menu Change Detected");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallets',
          callback: (payload) {
            debugPrint(">>> [SYNC] Financial Change Detected");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendors',
          callback: (payload) {
            debugPrint(">>> [SYNC] Vendor Identity Change Detected");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRecord = payload.newRecord;
            // Check for targeted or broadcast
            if (newRecord['user_id'] == userId ||
                newRecord['user_id'] == 'BROADCAST') {
              NotificationService.showLocalNotification(
                title: newRecord['title'] ?? 'Store update',
                body: newRecord['message'] ??
                    newRecord['body'] ??
                    'New notification received.',
              );
            }
          },
        )
        .subscribe((status, [error]) {
      if (status == 'SUBSCRIBED') {
        debugPrint(">>> [VENDOR HUB] Global Sync Established.");
      }
      if (error != null) {
        debugPrint(">>> [VENDOR HUB] Channel Error: $error");
      }
    });
  }

  static void deactivate() {
    if (_channel != null) {
      SupabaseConfig.client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
