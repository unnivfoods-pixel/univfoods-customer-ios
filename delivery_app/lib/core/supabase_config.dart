import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notification_service.dart';

class SupabaseConfig extends ChangeNotifier {
  static final SupabaseConfig _instance = SupabaseConfig._internal();
  factory SupabaseConfig() => _instance;
  SupabaseConfig._internal();

  static SupabaseConfig get notifier => _instance;

  void notify() => notifyListeners();

  static const String url = 'https://dxqcruvarqgnscenixzf.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
    await loadSession();
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Legacy compatibility getter
  static String? get forcedRiderId => client.auth.currentUser?.id;
  static Map<String, dynamic>? bootstrapData;

  // 1. Session Persistence (Now handled by Auth)
  static Future<void> saveSession(String userId) async {
    debugPrint(">>> [SESSION] Rider Auth UID: $userId");
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

  // 2. Production Bootstrap (Role: Delivery)
  static Future<void> bootstrap() async {
    final userId = forcedRiderId ?? client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint(">>> RIDER BOOTSTRAP START: $userId");
      final response = await client
          .rpc('get_rider_dashboard_v1', params: {'p_rider_auth_id': userId});
      bootstrapData = response;

      // Activate Real-time
      AppRealtimeHub.activate(userId);

      _instance.notify();
    } catch (e) {
      debugPrint(">>> RIDER BOOTSTRAP FAILED: $e");
    }
  }
}

// 3. Real-time Hub for Riders
class AppRealtimeHub {
  static RealtimeChannel? _channel;

  static void activate(String userId) {
    deactivate();
    debugPrint(">>> [RIDER HUB] ACTIVATING GLOBAL SYNC: $userId");

    _channel = SupabaseConfig.client
        .channel('delivery_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint(">>> [SYNC] Order State Shift: ${payload.eventType}");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_riders',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: userId),
          callback: (payload) {
            debugPrint(">>> [SYNC] Identity State Shift");
            SupabaseConfig.bootstrap();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['user_id'] == userId ||
                newRecord['user_id'] == 'BROADCAST') {
              debugPrint(
                  ">>> [SYNC] Notification Received: ${newRecord['title']}");
              NotificationService.showLocalNotification(
                title: newRecord['title'] ?? 'Order Assignment',
                body: newRecord['message'] ??
                    newRecord['body'] ??
                    'Check your queue.',
              );
            }
          },
        )
        .subscribe((status, [error]) {
      if (status == 'SUBSCRIBED') {
        debugPrint(">>> [RIDER HUB] Real-time Link Established.");
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
