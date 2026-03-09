import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import '../orders/delivery_orders_screen.dart';
import './live_tracking_map.dart';
import './payouts_screen.dart';
import './ride_history_screen.dart';
import './notifications_screen.dart';
import './support_center_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _subscribeToStatus();
  }

  Future<void> _checkInitialStatus() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      final res = await SupabaseConfig.client
          .from('delivery_riders')
          .select('is_online, kyc_status, active_order_id')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        setState(() {
          _isOnline = res['is_online'] ?? false;
          _activeOrderId = res['active_order_id'];
        });
      }
    }
  }

  void _subscribeToStatus() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    SupabaseConfig.client
        .channel('rider_status_${user.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_riders',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: user.id),
            callback: (payload) {
              if (mounted) {
                final data = payload.newRecord;
                setState(() {
                  _isOnline = data['is_online'] ?? false;
                  _activeOrderId = data['active_order_id'];
                });
              }
            })
        .subscribe();
  }

  Future<void> _toggleStatus(bool value) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isOnline = value);
    try {
      await SupabaseConfig.client.from('delivery_riders').update({
        'is_online': value,
        'status': value ? 'Online' : 'Offline',
        'last_online': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint("Status Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60 + MediaQuery.of(context).padding.top),
        child: Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 20,
              right: 20,
              bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 4)),
            ],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedIndex == 0
                          ? "Dispatch Terminal"
                          : _selectedIndex == 1
                              ? "Mission Map"
                              : _selectedIndex == 2
                                  ? "Capital Hub"
                                  : "Fleet Profile",
                      style: ProTheme.header.copyWith(fontSize: 20),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                _isOnline ? ProTheme.secondary : ProTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? "OPERATIONAL" : "STANDBY",
                          style: ProTheme.label
                              .copyWith(fontSize: 9, color: ProTheme.gray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseConfig.client
                      .from('notifications')
                      .stream(primaryKey: ['id']).eq('user_id',
                          SupabaseConfig.client.auth.currentUser?.id ?? ''),
                  builder: (context, snapshot) {
                    final notifications = snapshot.data ?? [];
                    final unreadCount = notifications
                        .where((n) => n['is_read'] == false)
                        .length;

                    return Row(
                      children: [
                        // 🔄 FORCE SYNC ACTION
                        IconButton(
                          onPressed: () async {
                            await SupabaseConfig.bootstrap();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("SYSTEM SYNCED"),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.refreshCw,
                              color: ProTheme.primary, size: 18),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationsScreen())),
                              icon: const Icon(LucideIcons.bell,
                                  color: ProTheme.dark, size: 22),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: ProTheme.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 9
                                        ? '9+'
                                        : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  }),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? ProTheme.secondary.withOpacity(0.08)
                      : ProTheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: (_isOnline ? ProTheme.secondary : ProTheme.error)
                          .withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Text(_isOnline ? "ON" : "OFF",
                        style: ProTheme.label.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color:
                              _isOnline ? ProTheme.secondary : ProTheme.error,
                        )),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 18,
                      width: 28,
                      child: Transform.scale(
                        scale: 0.6,
                        child: Switch(
                          value: _isOnline,
                          onChanged: _toggleStatus,
                          activeColor: ProTheme.secondary,
                          activeTrackColor: ProTheme.secondary.withOpacity(0.3),
                          inactiveThumbColor: ProTheme.gray,
                          inactiveTrackColor: ProTheme.gray.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: SupabaseConfig.notifier,
        builder: (context, _) {
          final orders = List<Map<String, dynamic>>.from(
              SupabaseConfig.bootstrapData?['orders'] ?? []);
          final hasActiveOrder = orders.any((o) =>
              o['id'].toString() == _activeOrderId &&
              !['DELIVERED', 'CANCELLED', 'REJECTED', 'COMPLETED']
                  .contains(o['status']?.toString().toUpperCase()));

          return Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  const DeliveryOrdersScreen(), // 0: Dispatch Feed
                  LiveTrackingMap(isOnline: _isOnline), // 1: Mission Map
                  const PayoutsScreen(), // 2: Capital Hub
                  const RideHistoryScreen(), // 3: Profile System
                ],
              ),
              if (_activeOrderId != null &&
                  _selectedIndex != 0 &&
                  hasActiveOrder)
                Positioned(
                  bottom: 230,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: ProTheme.dark.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: ProTheme.intenseShadow,
                      border:
                          Border.all(color: ProTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: ProTheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: const Icon(LucideIcons.truck,
                              color: ProTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("MISSION IN PROGRESS",
                                  style: ProTheme.label.copyWith(
                                      color: ProTheme.primary,
                                      fontSize: 8,
                                      letterSpacing: 0.5)),
                              Text("Order #$_activeOrderId",
                                  style: ProTheme.title.copyWith(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Material(
                          color: ProTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Text("VIEW MAP",
                                  style: ProTheme.label.copyWith(
                                      color: ProTheme.dark, fontSize: 10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 1.0, end: 0).fadeIn(),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SupportCenterScreen())),
        backgroundColor: ProTheme.primary,
        child: const Icon(LucideIcons.messageCircle, color: ProTheme.dark),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        height: 85,
        decoration: BoxDecoration(
          color: ProTheme.slate,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: ProTheme.slate.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, LucideIcons.box, "Dispatch"),
            _navItem(1, LucideIcons.navigation, "Map"),
            _navItem(2, LucideIcons.wallet, "Earnings"),
            _navItem(3, LucideIcons.user, "Profile"),
          ],
        ),
      ).animate().slideY(
          begin: 1.0,
          end: 0,
          delay: 200.ms,
          duration: 800.ms,
          curve: Curves.easeOutQuart),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint(">>> ACTION: Rider Tab $index");
          setState(() => _selectedIndex = index);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ProTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isSelected ? ProTheme.slate : Colors.white54,
                  size: 24),
              if (isSelected)
                Text(label,
                        style: ProTheme.label
                            .copyWith(color: ProTheme.slate, fontSize: 8))
                    .animate()
                    .fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
