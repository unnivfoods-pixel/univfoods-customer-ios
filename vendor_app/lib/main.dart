import 'package:flutter/material.dart';
import 'core/supabase_config.dart';
import 'core/pro_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/navigation.dart';

import 'features/account/legal_consent_screen.dart';

import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SupabaseConfig.initialize();

  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIV Vendor',
      navigatorKey: vendorNavigatorKey,
      theme: ProTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const RootWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/consent': (context) => LegalConsentScreen(onAccepted: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }),
      },
    );
  }
}

class RootWrapper extends StatefulWidget {
  const RootWrapper({super.key});

  @override
  State<RootWrapper> createState() => _RootWrapperState();
}

class _RootWrapperState extends State<RootWrapper> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    // Give the engine a moment to settle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final session = SupabaseConfig.client.auth.currentSession;
        final user = SupabaseConfig.client.auth.currentUser;

        if (user == null || session == null) {
          vendorNavigatorKey.currentState?.pushReplacementNamed('/login');
          return;
        }

        // Check Approval Status
        final vendorRes = await SupabaseConfig.client
            .from('vendors')
            .select('approval_status, is_approved')
            .eq('owner_id', user.id)
            .maybeSingle();

        if (vendorRes == null ||
            vendorRes['approval_status'] == 'PENDING' ||
            vendorRes['is_approved'] == false) {
          // Show pending status logic or keep them on a status screen
          debugPrint("Vendor not approved yet");
        }

        // Go to consent check
        vendorNavigatorKey.currentState?.pushReplacementNamed('/consent');
      } catch (e) {
        debugPrint("Auth Check Error: $e");
        vendorNavigatorKey.currentState?.pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
