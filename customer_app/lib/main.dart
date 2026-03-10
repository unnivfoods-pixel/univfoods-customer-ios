import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'core/supabase_config.dart';
import 'core/pro_theme.dart';
import 'core/location_service.dart';
import 'core/navigation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'features/auth/splash_login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/profile/notifications_screen.dart';
import 'features/menu/menu_screen.dart';
import 'core/widgets/pro_loader.dart';
import 'core/services/notification_service.dart';
import 'core/cart_state.dart';
import 'core/favorite_store.dart';
import 'core/location_store.dart';
import 'core/order_store.dart';
import 'core/menu_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint(">>> [MAIN] BOOTING...");

  // 1. CRITICAL: Initialize core services before the app starts
  try {
    // 🛡️ LOAD SESSION FIRST (Fast timeout)
    await SupabaseConfig.loadSessionFromDisk().timeout(
        const Duration(seconds: 3),
        onTimeout: () => debugPrint(">>> [DISK] Timeout"));

    // 🛡️ RESILIENT FIREBASE (Never blocks more than 4s)
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 4));

      if (kDebugMode) {
        await fb.FirebaseAuth.instance
            .setSettings(appVerificationDisabledForTesting: false);
      }

      await FirebaseAppCheck.instance
          .activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.deviceCheck,
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint(">>> [FIREBASE] Skipping: $e");
    }

    // 🛡️ SUPABASE (Fast timeout)
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 3),
        onTimeout: () => debugPrint(">>> [SUPABASE] Timeout"));
  } catch (e) {
    debugPrint("CRITICAL BOOT ERROR: $e");
  }

  // 2. Load persistence (parallel)
  await Future.wait([
    GlobalCart().load(),
    LocationService.loadLocationFromDisk(),
    LocationStore().loadFromDisk(),
    OrderStore().loadFromDisk(),
    MenuStore().loadFromDisk(),
    FavoriteStore.loadLocal(),
  ]).timeout(const Duration(seconds: 3), onTimeout: () => []);

  // 3. 🔔 Notifications (Safety first)
  try {
    NotificationService.ensureNotificationsReady();
  } catch (e) {
    debugPrint(">>> [NOTIF] Pre-init error: $e");
  }

  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIV Foods',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: ProTheme.primary,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const RootDecision(),
        '/login': (context) => const SplashLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/cart': (context) => const CartScreen(),
        '/menu': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return MenuScreen(vendor: args);
        },
      },
    );
  }
}

class RootDecision extends StatefulWidget {
  const RootDecision({super.key});

  @override
  State<RootDecision> createState() => _RootDecisionState();
}

class _RootDecisionState extends State<RootDecision> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    debugPrint(">>> [ROOT] STARTING BOOTSTRAP...");

    // 🛡️ EMERGENCY KILL-SWITCH: Force navigation to login if stuck for 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_navigated) {
        debugPrint(
            ">>> [ROOT] EMERGENCY KILL-SWITCH TRIGGERED. GOING TO LOGIN.");
        _forceGoToLogin();
      }
    });

    try {
      final String? userId = SupabaseConfig.forcedUserId;
      debugPrint(">>> [ROOT] SESSION CHECK: $userId");

      if (mounted) {
        if (userId != null && userId.isNotEmpty) {
          try {
            await NotificationService.initialize(context)
                .timeout(const Duration(seconds: 4));
          } catch (e) {
            debugPrint(">>> [NOTIF] Skipped: $e");
          }
          SupabaseConfig.bootstrap();
          _safeNavigate('/home');
        } else {
          _safeNavigate('/login');
        }
      }
    } catch (e) {
      debugPrint(">>> [ROOT] BOOTSTRAP ERROR: $e");
      _forceGoToLogin();
    }
  }

  void _forceGoToLogin() {
    if (_navigated) return;
    _navigated = true;
    _safeNavigate('/login');
  }

  void _safeNavigate(String route, {Object? args}) {
    if (_navigated && route != '/home') return; // Prevent double nav
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(route, arguments: args);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ProLoader(
          message: "Getting things ready... 🍛",
        ),
      ),
    );
  }
}
