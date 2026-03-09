import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import '../auth/login_screen.dart';
import 'legal_screen.dart';
import 'support_center_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  Map<String, dynamic> _riderStats = {
    'rating': 5.0,
    'total_deliveries': 0,
    'success_rate': 100
  };

  @override
  void initState() {
    super.initState();
    _fetchRiderStats();
  }

  Future<void> _fetchRiderStats() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    try {
      final riderData = await SupabaseConfig.client
          .from('delivery_riders')
          .select('rating, total_deliveries')
          .eq('id', user.id)
          .maybeSingle();

      if (riderData != null && mounted) {
        setState(() {
          _riderStats['rating'] = (riderData['rating'] ?? 5.0).toDouble();
          _riderStats['total_deliveries'] = riderData['total_deliveries'] ?? 0;
        });
      }
    } catch (e) {
      // Error handled silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.client.auth.currentUser;

    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: CustomScrollView(
        slivers: [
          // 1. Operational Profile Hero
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: BoxDecoration(
                color: ProTheme.slate,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: ProTheme.primary, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: ProTheme.dark,
                          child: const Icon(LucideIcons.user,
                              size: 40, color: ProTheme.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: ProTheme.secondary, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.shieldCheck,
                            color: ProTheme.dark, size: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                      user?.email?.split('@').first.toUpperCase() ??
                          "ELITE RIDER",
                      style: ProTheme.header
                          .copyWith(color: ProTheme.pureWhite, fontSize: 24)),
                  Text("OFFICIAL FLEET PARTNER",
                      style: ProTheme.label
                          .copyWith(color: ProTheme.primary, fontSize: 10)),
                  const SizedBox(height: 32),

                  // Performance Stats Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _performanceUnit(LucideIcons.star,
                          _riderStats['rating'].toStringAsFixed(1), "RATING"),
                      Container(width: 1, height: 30, color: Colors.white10),
                      _performanceUnit(
                          LucideIcons.package,
                          _riderStats['total_deliveries'].toString(),
                          "MISSIONS"),
                      Container(width: 1, height: 30, color: Colors.white10),
                      _performanceUnit(LucideIcons.gauge,
                          "${_riderStats['success_rate']}%", "SUCCESS"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Control Center Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("COMMAND CENTER", style: ProTheme.label),
                  const SizedBox(height: 16),
                  _actionTile(LucideIcons.fileText, "Operational Protocol",
                      "Legal and safety guidelines",
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LegalScreen()))),
                  _actionTile(LucideIcons.helpCircle, "Dispatch Support",
                      "24/7 technical assistance",
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SupportCenterScreen()))),
                  _actionTile(LucideIcons.logOut, "Terminate Session",
                      "Securely sign out of fleet hub",
                      isRed: true, onTap: _logout),
                  const SizedBox(height: 32),
                  Text("MISSION ARCHIVE", style: ProTheme.label),
                ],
              ),
            ),
          ),

          // 3. Mission Archive Stream (REAL-TIME)
          _buildMissionStream(),

          // Spacing for FAB/Nav
          const SliverPadding(padding: EdgeInsets.only(bottom: 250)),
        ],
      ),
    );
  }

  Widget _performanceUnit(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(height: 8),
        Text(val,
            style: ProTheme.header
                .copyWith(color: ProTheme.pureWhite, fontSize: 18)),
        Text(label,
            style: ProTheme.label.copyWith(fontSize: 8, color: Colors.white38)),
      ],
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle,
      {bool isRed = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ProTheme.cardDecor,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isRed ? ProTheme.error : ProTheme.dark).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon,
              color: isRed ? ProTheme.error : ProTheme.dark, size: 20),
        ),
        title: Text(title,
            style: ProTheme.title.copyWith(
                fontSize: 16, color: isRed ? ProTheme.error : ProTheme.dark)),
        subtitle: Text(subtitle, style: ProTheme.body.copyWith(fontSize: 12)),
        trailing: const Icon(LucideIcons.chevronRight,
            size: 18, color: ProTheme.gray),
      ),
    );
  }

  Widget _buildMissionStream() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return const SliverToBoxAdapter(child: SizedBox());

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseConfig.client
          .from('orders')
          .select('*, vendors(name, address)')
          .eq('rider_id', user.id)
          .eq('status', 'delivered')
          .order('created_at', ascending: false)
          .limit(20)
          .then((v) => List<Map<String, dynamic>>.from(v)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          CircularProgressIndicator(color: ProTheme.primary))));
        }

        final rides = snapshot.data ?? [];
        if (rides.isEmpty) {
          return _buildEmptyState();
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final ride = rides[index];
              final date = DateTime.parse(ride['created_at']).toLocal();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: ProTheme.cardDecor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: ProTheme.secondary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(LucideIcons.check,
                          color: ProTheme.secondary, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride['vendors']?['name'] ?? "Boutique Dispatch",
                              style: ProTheme.title.copyWith(fontSize: 14)),
                          Text(
                              "${date.day}/${date.month} • ${ride['delivery_address'] ?? ride['address'] ?? 'Archive'}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ProTheme.body.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Text("₹${((ride['total'] ?? 0) * 0.15).toInt()}",
                        style: ProTheme.header.copyWith(fontSize: 18)),
                  ],
                ),
              ).animate().fadeIn().slideX(begin: 0.1, end: 0);
            },
            childCount: rides.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const SliverToBoxAdapter(
        child: Center(
            child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text("NO COMPLETED MISSIONS"))));
  }

  void _logout() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
}
