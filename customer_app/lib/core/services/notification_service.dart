import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/supabase_config.dart';

// 1. Background Handler (Must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // If you need to access Supabase here, you must re-initialize it as this runs in a separate isolate
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false; // Track if plugin is initialized

  static String? get currentUserId =>
      SupabaseConfig.forcedUserId ?? SupabaseConfig.client.auth.currentUser?.id;

  // Public boot-time init call from main.dart
  static void ensureNotificationsReady() {
    _ensureInitialized(); // fire-and-forget, intentional
  }

  // Lightweight init for local notifications only (no permission prompt)
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      await _localNotifications.initialize(
        const InitializationSettings(
          android: initAndroid,
          iOS: DarwinInitializationSettings(),
        ),
      );
      // Create channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'logistics_high_importance',
            'Orders & Delivery',
            description: 'Critical updates for your food orders.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ));
      _initialized = true;
      debugPrint('>>> [NOTIF] Local plugin initialized ✅');
    } catch (e) {
      debugPrint('>>> [NOTIF] Init error: $e');
    }
  }

  static Future<void> initialize(BuildContext context) async {
    // 1. Create Android Notification Channel (Point 4)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'logistics_high_importance', // id
      'Orders & Delivery', // title
      description: 'Critical updates for your food orders.', // description
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('>>> NOTIFICATIONS: AUTHORIZED');

      // 3. Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: const DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleDeepLink(details.payload);
        },
      );

      // 4. Background Handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 5. Token Management (Point 1 & 2)
      String? token = await _messaging.getToken();
      if (token != null) {
        _saveTokenToDatabase(token);
      }
      _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // 6. Foreground Handler (Point 3)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            '>>> FCM FOREGROUND MESSAGE: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 7. Background Click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleDeepLink(message.data['order_id']);
      });

      // 8. Wait for Auth Sync to start Realtime Hub (already handled by SupabaseConfig)
      // Notification Hub is now integrated into Central Realtime Pulse

      // 9. Auth Sync
      SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
        // Realtime activation is now handled by SupabaseConfig directly
        _messaging.getToken().then((token) {
          if (token != null) _saveTokenToDatabase(token);
        });
      });
    }
  }

  // (Redundant listener removed, using AppRealtimeHub instead)

  static void forceStart() {
    debugPrint(">>> MANUAL NOTIFICATION SYSTEM KICKSTART");
    // Realtime listener is now managed by AppRealtimeHub in SupabaseConfig
  }

  static void _handleDeepLink(String? orderId) {
    if (orderId != null) {
      debugPrint("Deep Linking to Order: $orderId");
      // Use your navigator key to push the correct screen
      // Example: Navigator.pushNamed(context, '/tracking', arguments: orderId);
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'logistics_high_importance',
      'Orders & Delivery',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: const Color(0xFF1B5E20), // Univ Green
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? message.data['title'],
      message.notification?.body ?? message.data['body'],
      platformChannelSpecifics,
      payload: message.data['order_id'],
    );
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await SupabaseConfig.client.from('device_tokens').upsert({
        'user_id': userId,
        'user_role': 'customer',
        'device_token': token,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');
      debugPrint(">>> FCM TOKEN SYNCED TO GRID: $userId");
    } catch (e) {
      debugPrint(">>> TOKEN SYNC FAULT: $e");
    }
  }

  static Future<void> testNotification() async {
    debugPrint("Testing local notification...");
    await _showLocalNotification(const RemoteMessage(
        notification: RemoteNotification(
            title: "Test Notification",
            body: "This is a test alert from UNIV Foods!")));
  }

  // Public method to show notifications from realtime listener
  // This is the main entry point for Supabase realtime notifications
  static Future<void> showLocalNotificationDirect({
    required String title,
    required String body,
  }) async {
    try {
      await _ensureInitialized(); // Auto-init if needed

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'logistics_high_importance',
        'Orders & Delivery',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        color: const Color(0xFF1B5E20),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: BigTextStyleInformation(body),
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
      debugPrint('>>> [NOTIF] Showed: $title');
    } catch (e) {
      debugPrint('>>> [NOTIF] showLocalNotificationDirect FAILED: $e');
    }
  }
}
