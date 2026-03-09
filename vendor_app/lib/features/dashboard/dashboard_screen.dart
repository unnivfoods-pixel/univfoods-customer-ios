import 'package:flutter/material.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../orders/vendor_orders_screen.dart';
import '../menu/vendor_menu_screen.dart';
import '../menu/add_edit_product_screen.dart';
import '../analysis/analysis_screen.dart';
import '../account/account_screen.dart';
import './notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isAcceptingOrders = true;
  String? _vendorId;
  String? _vendorName;

  @override
  void initState() {
    super.initState();
    _fetchVendorStatus();
    _subscribeToStatus();
  }

  void _subscribeToStatus() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    // Listen for ANY change to THIS vendor's record
    SupabaseConfig.client
        .channel('identity_mon_${user.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vendors',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'owner_id',
                value: user.id),
            callback: (payload) {
              debugPrint(">>> REALTIME IDENTITY UPDATE: ${payload.newRecord}");
              if (mounted) {
                final data = payload.newRecord;
                setState(() {
                  _vendorId = data['id'];
                  _vendorName = data['name'];
                  _isAcceptingOrders = (data['status'] == 'ONLINE' ||
                      data['status'] == 'Active');
                });
              }
            })
        .subscribe();
  }

  Future<void> _fetchVendorStatus() async {
    final data = SupabaseConfig.bootstrapData?['profile'];
    if (mounted && data != null && data.isNotEmpty) {
      setState(() {
        _vendorId = data['id'];
        _vendorName = data['name'];
        _isAcceptingOrders =
            (data['status'] == 'ONLINE' || data['status'] == 'Active');
      });
    }
  }

  Future<void> _toggleStatus(bool value) async {
    setState(() => _isAcceptingOrders = value);
    if (_vendorId == null) return;

    try {
      await SupabaseConfig.client.from('vendors').update(
          {'status': value ? 'ONLINE' : 'OFFLINE'}).eq('id', _vendorId!);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  List<Widget> get _pages => [
        const VendorOrdersScreen(),
        const AnalysisScreen(),
        const VendorMenuScreen(),
        AccountScreen(vendor: SupabaseConfig.bootstrapData?['profile']),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: SupabaseConfig.notifier,
        builder: (context, _) => Scaffold(
              extendBody: true,
              backgroundColor: ProTheme.bg,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Container(
                  decoration: BoxDecoration(
                    color: ProTheme.bg.withOpacity(0.8),
                    border: Border(
                        bottom:
                            BorderSide(color: ProTheme.dark.withOpacity(0.05))),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _vendorName ?? "Vendor Terminal",
                                  style: ProTheme.header.copyWith(fontSize: 22),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _selectedIndex == 0
                                      ? "LIVE OPERATIONS"
                                      : _selectedIndex == 1
                                          ? "GROWTH HUB"
                                          : _selectedIndex == 2
                                              ? "VAULT MENU"
                                              : "TERMINAL SETTINGS",
                                  style: ProTheme.label.copyWith(
                                      fontSize: 10, color: ProTheme.gray),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<List<Map<String, dynamic>>>(
                              stream: SupabaseConfig.client
                                  .from('notifications')
                                  .stream(primaryKey: ['id']).eq(
                                      'user_id',
                                      SupabaseConfig
                                              .client.auth.currentUser?.id ??
                                          ''),
                              builder: (context, snapshot) {
                                final notifications = snapshot.data ?? [];
                                final unreadCount = notifications
                                    .where((n) => n['is_read'] == false)
                                    .length;

                                return Row(
                                  children: [
                                    IconButton(
                                      onPressed: () async {
                                        await SupabaseConfig.bootstrap();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text("Dashboard Synced"),
                                              duration: Duration(seconds: 1),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.refresh_rounded,
                                          color: ProTheme.primary, size: 24),
                                    ),
                                    Stack(
                                      children: [
                                        IconButton(
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const NotificationsScreen())),
                                          icon: Icon(
                                              Icons.notifications_none_rounded,
                                              color: ProTheme.dark,
                                              size: 28),
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: ProTheme.primary,
                                                shape: BoxShape.circle,
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
                                                  color: ProTheme.dark,
                                                  fontSize: 8,
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
                          const SizedBox(width: 12),
                          if (_selectedIndex == 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isAcceptingOrders
                                    ? ProTheme.secondary.withOpacity(0.1)
                                    : ProTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: (_isAcceptingOrders
                                            ? ProTheme.secondary
                                            : ProTheme.error)
                                        .withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                      _isAcceptingOrders ? "ACTIVE" : "OFFLINE",
                                      style: ProTheme.label.copyWith(
                                        color: _isAcceptingOrders
                                            ? ProTheme.secondary
                                            : ProTheme.error,
                                        fontSize: 10,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              body: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
              bottomNavigationBar: _buildBottomNav(),
              floatingActionButton: _selectedIndex == 2
                  ? FloatingActionButton(
                      onPressed: () {
                        if (_vendorId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditProductScreen(vendorId: _vendorId!),
                            ),
                          ).then((value) {
                            if (value == true) {
                              // Status will refresh via realtime subscription in VendorMenuScreen
                            }
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Initializing Vault...")));
                        }
                      },
                      backgroundColor: ProTheme.primary,
                      foregroundColor: ProTheme.dark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.add_task_rounded),
                    )
                  : null,
            ));
  }

  Widget _buildBottomNav() {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ProTheme.bg.withOpacity(0), ProTheme.bg],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ProTheme.dark,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: ProTheme.dark.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.speed_rounded, "Ops"),
              _navItem(1, Icons.auto_graph_rounded, "Fuel"),
              _navItem(2, Icons.layers_rounded, "Assets"),
              _navItem(3, Icons.grid_view_rounded, "Core"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint(">>> ACTION: Vendor Tab $index");
          setState(() => _selectedIndex = index);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ProTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: isSelected
                      ? ProTheme.dark
                      : Colors.white.withOpacity(0.5),
                  size: 24),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(label,
                    style: ProTheme.button
                        .copyWith(color: ProTheme.dark, fontSize: 13)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
