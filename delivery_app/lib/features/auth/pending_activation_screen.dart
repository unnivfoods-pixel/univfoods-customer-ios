import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class PendingActivationScreen extends StatefulWidget {
  const PendingActivationScreen({super.key});

  @override
  State<PendingActivationScreen> createState() =>
      _PendingActivationScreenState();
}

class _PendingActivationScreenState extends State<PendingActivationScreen> {
  @override
  void initState() {
    super.initState();
    _listenForApproval();
  }

  void _listenForApproval() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    SupabaseConfig.client
        .channel('rider_approval')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_riders',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: user.id),
            callback: (payload) {
              final isApproved = payload.newRecord['is_approved'] ?? false;
              if (isApproved && mounted) {
                Navigator.pushReplacementNamed(context, '/consent');
              }
            })
        .subscribe();

    // Also poll occasionally as fallback
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    if (!mounted) return;

    final res = await SupabaseConfig.client
        .from('delivery_riders')
        .select('is_approved')
        .eq('id', user.id)
        .maybeSingle();

    if (res?['is_approved'] == true && mounted) {
      Navigator.pushReplacementNamed(context, '/consent');
    } else if (mounted) {
      await Future.delayed(const Duration(seconds: 5));
      _checkStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.shieldAlert,
                    size: 64, color: Colors.orange),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 32),
              Text("ACCESS PENDING",
                      textAlign: TextAlign.center,
                      style: ProTheme.header
                          .copyWith(fontSize: 28, letterSpacing: 2))
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Text("Your credentials have been authenticated, but your node is not yet authorized in this sector. Admin review is in progress.",
                      textAlign: TextAlign.center, style: ProTheme.body)
                  .animate()
                  .fadeIn(delay: 500.ms),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: ProTheme.primary)
                  .animate()
                  .fadeIn(delay: 800.ms),
              const SizedBox(height: 24),
              Text("WAITING FOR HQ SIGNAL...",
                      style: ProTheme.label
                          .copyWith(fontSize: 10, color: ProTheme.gray))
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 2.seconds),
              const SizedBox(height: 80),
              TextButton(
                onPressed: () => SupabaseConfig.client.auth.signOut().then((_) {
                  Navigator.pushReplacementNamed(context, '/login');
                }),
                child: Text("CANCEL APPLICATION / LOGOUT",
                    style: TextStyle(
                        color: ProTheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ).animate().fadeIn(delay: 1.seconds),
            ],
          ),
        ),
      ),
    );
  }
}
