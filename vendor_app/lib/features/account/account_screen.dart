import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'legal_screen.dart';
import 'shop_profile_screen.dart';
import 'settlements_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../support/support_center_screen.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic>? vendor;
  const AccountScreen({super.key, this.vendor});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _vendor;
  bool _loading = false;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _fetchProfile();
    _subscribeToProfile();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      SupabaseConfig.client.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  void _subscribeToProfile() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    _profileChannel = SupabaseConfig.client
        .channel('vendor_profile_${user.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vendors',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'owner_id',
                value: user.id),
            callback: (payload) {
              if (mounted) {
                setState(() => _vendor = payload.newRecord);
              }
            })
        .subscribe();
  }

  Future<void> _fetchProfile() async {
    final cached = SupabaseConfig.bootstrapData?['profile'];
    if (cached != null && cached.isNotEmpty) {
      if (mounted)
        setState(() {
          _vendor = cached;
          _loading = false;
        });
      return;
    }

    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _vendor = {
            'name': 'Imperial Curry House',
            'cuisine_type': 'Royal Mughlai Cuisine',
            'id': 'demo',
            'avg_prep_time': 20,
          };
          _loading = false;
        });
      return;
    }

    if (_vendor == null) setState(() => _loading = true);

    try {
      final res = await SupabaseConfig.client
          .from('vendors')
          .select('*')
          .eq('owner_id', user.id)
          .maybeSingle();
      if (mounted)
        setState(() {
          _vendor = res;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseConfig.notifier,
      builder: (context, _) {
        final profile = SupabaseConfig.bootstrapData?['profile'];
        if (profile != null && profile.isNotEmpty) {
          _vendor = profile;
        }

        if (_loading && _vendor == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            child: Column(
              children: [
                _buildProfileHero(),
                const SizedBox(height: 40),
                _buildSection("COMMAND CENTER", [
                  _buildModernTile(LucideIcons.store, "Vendor Profile",
                      "Manage your brand identity", () {
                    if (_vendor != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ShopProfileScreen(vendor: _vendor!)));
                    }
                  }),
                  _buildModernTile(LucideIcons.banknote, "Settlements",
                      "View and withdraw revenue", () {
                    if (_vendor != null && _vendor!['id'] != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  SettlementsScreen(vendorId: _vendor!['id'])));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Linking Account... Please wait.")));
                    }
                  }),
                ]),
                const SizedBox(height: 32),
                _buildSection("LOGISTICS & OPERATIONS", [
                  _buildModernTile(
                      LucideIcons.clock,
                      "Kitchen Pulse",
                      "Set default preparation time",
                      () => _showPrepTimeControl()),
                  _buildModernTile(LucideIcons.shieldCheck, "Compliance Hub",
                      "Platform policies & verification", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const LegalScreen(targetAudience: 'VENDOR')));
                  }),
                ]),
                _buildSection("DIRECT SUPPORT", [
                  _buildModernTile(LucideIcons.headphones, "Command Support",
                      "Instant assistance from HQ", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SupportCenterScreen()));
                  }),
                ]),
                const SizedBox(height: 40),
                _buildLogoutButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHero() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ProTheme.dark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: ProTheme.intenseShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration:
                BoxDecoration(color: ProTheme.primary, shape: BoxShape.circle),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(LucideIcons.chefHat, color: ProTheme.dark, size: 32),
            ),
          ),
          const SizedBox(height: 20),
          Text(_vendor?['name'] ?? "Vendor Name",
              style:
                  ProTheme.header.copyWith(fontSize: 24, color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ProTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ProTheme.primary.withOpacity(0.3)),
            ),
            child: Text(
                _vendor?['cuisine_type']?.toString().toUpperCase() ?? "CUISINE",
                style: ProTheme.label
                    .copyWith(color: ProTheme.primary, fontSize: 10)),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 20),
          child: Text(title,
              style:
                  ProTheme.label.copyWith(color: ProTheme.gray, fontSize: 10)),
        ),
        ...items,
      ],
    );
  }

  Widget _buildModernTile(
      IconData icon, String title, String sub, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ProTheme.cardDecor,
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: ProTheme.bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: ProTheme.dark, size: 22),
        ),
        title: Text(title, style: ProTheme.title.copyWith(fontSize: 16)),
        subtitle: Text(sub, style: ProTheme.body.copyWith(fontSize: 12)),
        trailing: const Icon(LucideIcons.chevronRight,
            size: 18, color: ProTheme.gray),
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  void _showPrepTimeControl() {
    final prepController = TextEditingController(
        text: (_vendor?['avg_prep_time'] ?? 15).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text("Kitchen Pulse Time"),
        content: TextField(
          controller: prepController,
          keyboardType: TextInputType.number,
          decoration: ProTheme.inputDecor("Minutes", LucideIcons.timer),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final mins = int.tryParse(prepController.text) ?? 15;
              await SupabaseConfig.client
                  .from('vendors')
                  .update({'avg_prep_time': mins}).eq('id', _vendor?['id']);
              _fetchProfile();
              Navigator.pop(ctx);
            },
            child: const Text("SAVE PULSE"),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          await SupabaseConfig.logout();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
        icon: const Icon(LucideIcons.logOut, size: 18),
        label: const Text("TERMINATE SESSION"),
        style: TextButton.styleFrom(
          foregroundColor: ProTheme.error,
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: ProTheme.label.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
