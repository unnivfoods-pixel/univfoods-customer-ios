import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../supabase_config.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await _messaging.getToken();
        if (token != null) {
          _saveTokenToDatabase(token);
        }

        _messaging.onTokenRefresh.listen(_saveTokenToDatabase);
      }
    } catch (e) {
      debugPrint("Notification Initialization Failed: $e");
    }
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      debugPrint("Saving Vendor FCM Token for User: ${user.id}");
      try {
        await SupabaseConfig.client.from('device_tokens').upsert({
          'user_id': user.id,
          'user_role': 'vendor',
          'device_token': token,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,device_token');
      } catch (e) {
        debugPrint("Error saving vendor FCM token: $e");
      }
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    debugPrint(">>> [VENDOR ALERT] $title: $body");
  }
}
