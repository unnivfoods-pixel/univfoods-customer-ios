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
  try {
    // 🛡️ LOAD SESSION FIRST
    await SupabaseConfig.loadSessionFromDisk();

    try {
      // 🛡️ RESILIENT INITIALIZATION
      // We use a timeout to prevent missing Google-Services config from hanging the app
      await Firebase.initializeApp().timeout(const Duration(seconds: 5),
          onTimeout: () {
        debugPrint(
            ">>> [FIREBASE] Initialization timed out. Skipping native sync.");
        return Firebase.app();
      });

      // 🛡️ Bypassing Robot Check (reCAPTCHA)
      if (kDebugMode) {
        try {
          await fb.FirebaseAuth.instance
              .setSettings(appVerificationDisabledForTesting: false);
        } catch (e) {
          debugPrint(">>> [AUTH] Warning: $e");
        }
      }

      // 🛡️ APP CHECK
      try {
        await FirebaseAppCheck.instance
            .activate(
              androidProvider: kDebugMode
                  ? AndroidProvider.debug
                  : AndroidProvider.playIntegrity,
              appleProvider: AppleProvider.deviceCheck,
            )
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint(">>> [APP CHECK] Skipping: $e");
      }

      await SupabaseConfig.initialize();
    } catch (e) {
      debugPrint("FIREBASE/SUPABASE INIT ERROR (Handled): $e");
    }
  } catch (e) {
    debugPrint("CRITICAL BOOT ERROR: $e");
  }

  // 2. Load persistence
  await GlobalCart().load();
  await LocationService.loadLocationFromDisk();
  await LocationStore().loadFromDisk();
  await OrderStore().loadFromDisk();
  await MenuStore().loadFromDisk();
  await FavoriteStore.loadLocal();

  // 3. 🔔 Pre-initialize notification plugin
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
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    debugPrint(">>> [RAPID BOOT] START");

    final String? userId = SupabaseConfig.forcedUserId;
    debugPrint(">>> [RAPID BOOT] FINAL SESSION CHECK: $userId");

    if (mounted) {
      if (userId != null && userId.isNotEmpty) {
        try {
          await NotificationService.initialize(context)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint(">>> [NOTIF] Initialization skipped: $e");
        }

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
