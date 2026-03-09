import 'package:flutter/material.dart';
import 'core/supabase_config.dart';
import 'core/pro_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/navigation.dart';

import 'features/dashboard/legal_consent_screen.dart';

import 'package:firebase_core/firebase_core.dart';

import 'features/auth/pending_activation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SupabaseConfig.initialize();

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIV Rider',
      navigatorKey: riderNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: ProTheme.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ProTheme.primary,
          primary: ProTheme.primary,
          secondary: ProTheme.secondary,
          surface: ProTheme.bg,
        ),
        scaffoldBackgroundColor: ProTheme.bg,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const RootWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/pending': (context) => const PendingActivationScreen(),
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
  String _statusMessage = "Initializing Fleet Core...";
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    setState(() {
      _statusMessage = "Checking Authorization...";
      _showRetry = false;
    });

    // Wrap in Future.delayed to ensure the navigator is ready
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final client = SupabaseConfig.client;
        final user = client.auth.currentUser;

        if (user == null) {
          riderNavigatorKey.currentState?.pushReplacementNamed('/login');
          return;
        }

        // Add a timeout to the status check
        final res = await client
            .from('delivery_riders')
            .select('is_approved')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));

        if (res == null || res['is_approved'] == false) {
          debugPrint("Rider not approved yet or record missing");
          riderNavigatorKey.currentState?.pushReplacementNamed('/pending');
          return;
        }

        setState(() => _statusMessage = "Synchronizing Protocol...");
        riderNavigatorKey.currentState?.pushReplacementNamed('/consent');
      } catch (e) {
        debugPrint("Status check error/timeout: $e");
        setState(() {
          _statusMessage = "Network Congestion Detected";
          _showRetry = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: ProTheme.primary),
            const SizedBox(height: 24),
            Text(_statusMessage, style: ProTheme.label.copyWith(fontSize: 10)),
            if (_showRetry) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checkStatus,
                style: ProTheme.primaryButton,
                child: const Text("RETRY CONNECTION",
                    style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => riderNavigatorKey.currentState
                    ?.pushReplacementNamed('/consent'),
                child: Text("BYPASS TO DASHBOARD",
                    style: TextStyle(
                        color: ProTheme.primary.withOpacity(0.5), fontSize: 9)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
