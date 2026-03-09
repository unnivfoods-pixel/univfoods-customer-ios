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
// import 'features/profile/legal_consent_screen.dart'; // No longer used in root nav
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

  // 1. CRITICAL: Initialize core services before the app starts
  // This ensures sessions are loaded before RootDecision makes a choice
  try {
    // 🛡️ LOAD SESSION FIRST (Before anything else)
    await SupabaseConfig.loadSessionFromDisk();

    await Firebase.initializeApp();

    // 🛡️ Bypassing Robot Check (reCAPTCHA)
    // 🛡️ PRODUCTION READINESS
    // We set this to FALSE so Firebase can perform real verification.
    if (kDebugMode) {
      try {
        // Set to false for real SMS; true ONLY for "Testing Numbers" in Firebase
        await fb.FirebaseAuth.instance
            .setSettings(appVerificationDisabledForTesting: false);
        debugPrint(
            ">>> [AUTH] Real Verification: ENABLED (Ready for Play Store)");
      } catch (e) {
        debugPrint(">>> [AUTH] Warning: $e");
      }
    }

    // 🛡️ APP CHECK: MANDATORY for Silent OTP in Debug Mode
    // This provides the "Client Identifier" that is currently missing.
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      debugPrint(
          ">>> [APP CHECK] OK: ${kDebugMode ? 'DEBUG' : 'PLAY_INTEGRITY'}");
    } catch (e) {
      debugPrint(">>> [APP CHECK] FAILED: $e");
    }

    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint("CRITICAL INIT ERROR: $e");
  }

  // 2. Load persistence
  await GlobalCart().load();
  await LocationService.loadLocationFromDisk();
  await LocationStore().loadFromDisk();
  await OrderStore().loadFromDisk();
  await MenuStore().loadFromDisk();
  await FavoriteStore.loadLocal();

  // 3. 🔔 Pre-initialize notification plugin so realtime notifs work immediately
  //    This ensures the plugin is ready before ANY realtime event arrives
  NotificationService.ensureNotificationsReady();

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
  // bool _initialized = false; // No longer used as build returns SizedBox.shrink()

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    debugPrint(">>> [RAPID BOOT] START");

    // Session is already initialized in main(), so we check it immediately
    final String? userId = SupabaseConfig.forcedUserId;
    debugPrint(">>> [RAPID BOOT] FINAL SESSION CHECK: $userId");

    if (mounted) {
      if (userId != null && userId.isNotEmpty) {
        // Initialize notifications (Permission request + Channels)
        await NotificationService.initialize(context);

        // Run deep sync in background
        SupabaseConfig.bootstrap();
        _safeNavigate('/home');
      } else {
        _safeNavigate('/login');
      }
    }
  }

  void _safeNavigate(String route, {Object? args}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(route, arguments: args);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show the premium loader while bootstrapping
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
