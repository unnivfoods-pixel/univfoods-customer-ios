import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import '../../core/services/location_service.dart';
import 'order_chat_screen.dart';
import '../../core/services/maps_launcher.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  Map<String, dynamic>? _activeOrder;

  @override
  void initState() {
    super.initState();
    _checkAndStartTracking();
    if (SupabaseConfig.bootstrapData == null) {
      SupabaseConfig.bootstrap().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _checkAndStartTracking() async {
    final allOrders = List<Map<String, dynamic>>.from(
        SupabaseConfig.bootstrapData?['orders'] ?? []);
    final userId = SupabaseConfig.forcedRiderId ??
        SupabaseConfig.client.auth.currentUser?.id;

    final active = allOrders.cast<Map<String, dynamic>?>().firstWhere(
          (o) =>
              o?['rider_id']?.toString() == userId &&
              [
                'ACCEPTED',
                'RIDER_ASSIGNED',
                'PREPARING',
                'READY',
                'PICKED_UP',
                'ON_THE_WAY'
              ].contains(o?['status']?.toString().toUpperCase()),
          orElse: () => null,
        );

    if (active != null) {
      LocationService()
          .startTracking(userId!, orderId: active['order_id'].toString());
    }
  }

  Future<void> _acceptMission(String orderId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      // Professional Acceptance
      await SupabaseConfig.client.rpc('accept_order_v1', params: {
        'p_order_id': orderId,
        'p_rider_id': user.id,
      });

      // Start tracking immediately upon acceptance
      LocationService().startTracking(user.id, orderId: orderId);
      await SupabaseConfig.bootstrap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("MISSION ACCEPTED: PROCEED TO RESTAURANT"),
              backgroundColor: ProTheme.secondary),
        );
      }
    } catch (e) {
      debugPrint("Accept Mission Error: $e");
    }
  }

  Future<void> _pickUpFood() async {
    try {
      final orderId = _activeOrder!['order_id'];
      await SupabaseConfig.client.rpc('rider_pickup_order_v2', params: {
        'p_order_id': orderId,
      });

      await SupabaseConfig.bootstrap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("FOOD PICKED UP: NAVIGATING TO CUSTOMER"),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Pickup Error: $e");
    }
  }

  Future<void> _verifyDelivery() async {
    try {
      final orderId = _activeOrder!['order_id'];
      await SupabaseConfig.client.rpc('rider_deliver_order_v2', params: {
        'p_order_id': orderId,
      });

      LocationService().stopTracking();
      await SupabaseConfig.bootstrap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("DELIVERY COMPLETE: EARNINGS ADDED"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Delivery Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseConfig.notifier,
      builder: (context, _) {
        final allOrders = List<Map<String, dynamic>>.from(
            SupabaseConfig.bootstrapData?['orders'] ?? []);
        final userId = SupabaseConfig.forcedRiderId ??
            SupabaseConfig.client.auth.currentUser?.id;

        // 1. Check for ACTIVE MISSION assigned to THIS rider
        final active = allOrders.cast<Map<String, dynamic>?>().firstWhere(
              (o) =>
                  o?['rider_id']?.toString() == userId &&
                  !['DELIVERED', 'CANCELLED', 'REFUNDED', 'COMPLETED']
                      .contains(o?['status']?.toString().toUpperCase()),
              orElse: () => null,
            );

        if (active != null) {
          _activeOrder = active;
          return _buildActiveOrderView();
        } else {
          _activeOrder = null;
        }

        // 2. Available Missions (Unassigned)
        final availableMissions = allOrders.where((o) {
          final status = o['status']?.toString().toUpperCase();
          return o['rider_id'] == null &&
              ['PLACED', 'ACCEPTED', 'PREPARING', 'READY'].contains(status);
        }).toList();

        if (availableMissions.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => SupabaseConfig.bootstrap(),
            backgroundColor: ProTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.radar,
                            size: 64, color: ProTheme.primary.withOpacity(0.3))
                        .animate(onPlay: (c) => c.repeat())
                        .rotate(duration: 2.seconds)
                        .shimmer(),
                    const SizedBox(height: 24),
                    Text("NO MISSIONS NEARBY",
                        style: ProTheme.header
                            .copyWith(fontSize: 16, color: Colors.white)),
                    Text("Pull down to scan for deployments",
                        style: ProTheme.body
                            .copyWith(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => SupabaseConfig.bootstrap(),
          backgroundColor: ProTheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 250),
            itemCount: availableMissions.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildListHeader(availableMissions.length);
              return _buildMissionCard(availableMissions[index - 1]);
            },
          ),
        );
      },
    );
  }

  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          const Icon(LucideIcons.zap, color: ProTheme.primary, size: 16),
          const SizedBox(width: 8),
          Text("AVAILABLE MISSIONS",
              style: ProTheme.label.copyWith(fontSize: 11)),
          const Spacer(),
          Text("$count NEARBY",
              style:
                  ProTheme.label.copyWith(fontSize: 10, color: ProTheme.gray)),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildScanningVfx() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.radar,
                  size: 64, color: ProTheme.primary.withOpacity(0.3))
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2.seconds)
              .shimmer(),
          const SizedBox(height: 24),
          Text("SCANNING FOR DEPLOYMENTS",
              style: ProTheme.header.copyWith(fontSize: 16)),
          Text("Monitoring high-velocity logistics...",
              style: ProTheme.body.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActiveOrderView() {
    final status = _activeOrder!['status']?.toString().toUpperCase();
    final statusDisplay =
        _activeOrder!['status_display'] ?? "MISSION IN PROGRESS";
    final isAtPickup = status == 'RIDER_ASSIGNED' ||
        status == 'PREPARING' ||
        status == 'READY_FOR_PICKUP';

    final vName = _activeOrder!['vendor_name'] ?? 'Restaurant';
    final vAddr = _activeOrder!['vendor_address'] ?? 'Loading Address...';
    final cName = _activeOrder!['customer_name'] ?? 'Customer';
    final cAddr = _activeOrder!['effective_address'] ?? 'Loading Address...';

    final vLat =
        (_activeOrder!['resolved_pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final vLng =
        (_activeOrder!['resolved_pickup_lng'] as num?)?.toDouble() ?? 0.0;
    final cLat = (_activeOrder!['delivery_lat'] as num?)?.toDouble() ?? 0.0;
    final cLng = (_activeOrder!['delivery_lng'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 250),
      child: Column(
        children: [
          // 📡 TACTICAL MISSION STATUS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: ProTheme.slate,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ProTheme.primary.withOpacity(0.2))),
            child: Row(
              children: [
                const Icon(LucideIcons.activity,
                    color: ProTheme.primary, size: 16),
                const SizedBox(width: 10),
                Text(statusDisplay.toUpperCase(),
                    style: ProTheme.label.copyWith(
                        color: ProTheme.primary,
                        fontSize: 10,
                        letterSpacing: 1.5)),
              ],
            ),
          ).animate().fadeIn().slideX(begin: -0.2, end: 0),

          const SizedBox(height: 24),

          // 🏛️ TARGET CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: ProTheme.cardDecor.copyWith(color: ProTheme.slate),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: ProTheme.primary, shape: BoxShape.circle),
                      child: Icon(
                          isAtPickup ? LucideIcons.store : LucideIcons.home,
                          color: ProTheme.slate),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isAtPickup
                                  ? "TARGET: RESTAURANT"
                                  : "TARGET: CUSTOMER",
                              style: ProTheme.label.copyWith(
                                  color: ProTheme.primary, fontSize: 9)),
                          Text(isAtPickup ? vName : cName,
                              style: ProTheme.title
                                  .copyWith(color: Colors.white, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 32),

                // 📍 ADDRESS DISPLAY
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.mapPin,
                        color: ProTheme.gray, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(isAtPickup ? vAddr : cAddr,
                            style: ProTheme.body.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13))),
                  ],
                ),

                const SizedBox(height: 32),

                // 🔓 ONE-TAP VERIFICATION (NO MORE OTP INPUT)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAtPickup ? _pickUpFood : _verifyDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ProTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: ProTheme.secondary.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            isAtPickup
                                ? LucideIcons.checkCircle
                                : LucideIcons.packageCheck,
                            color: Colors.white,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(isAtPickup ? "CONFIRM PICKUP" : "CONFIRM DELIVERY",
                            style: ProTheme.button
                                .copyWith(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 🗺️ NAVIGATION BLOCK
          _buildNavigationBlock(vLat, vLng, cLat, cLng, isAtPickup),

          const SizedBox(height: 12),

          if (!isAtPickup) ...[
            _actionBtn(LucideIcons.phone, "CALL CUSTOMER", () async {
              // Direct call logic
            }),
            const SizedBox(height: 12),
            _actionBtn(LucideIcons.messageSquare, "CHAT WITH CUSTOMER", () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderChatScreen(
                          orderId: _activeOrder!['order_id'].toString(),
                          customerName: cName)));
            }, isPrimary: true),
          ]
        ],
      ),
    );
  }

  Widget _buildNavigationBlock(
      double vLat, double vLng, double cLat, double cLng, bool isAtPickup) {
    return Container(
      decoration:
          ProTheme.cardDecor.copyWith(color: Colors.white.withOpacity(0.03)),
      child: ListTile(
        onTap: () {
          final lat = isAtPickup ? vLat : cLat;
          final lng = isAtPickup ? vLng : cLng;
          if (lat != 0) MapsLauncher.launchNavigation(lat, lng);
        },
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: ProTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(LucideIcons.navigation,
                color: ProTheme.primary, size: 18)),
        title: Text("OPEN TACTICAL NAVIGATION",
            style: ProTheme.label.copyWith(fontSize: 10, color: Colors.white)),
        subtitle: Text("Google Maps Road Routing",
            style: ProTheme.body.copyWith(fontSize: 11, color: Colors.grey)),
        trailing:
            const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 16),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {bool isPrimary = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? ProTheme.primary.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          foregroundColor: isPrimary ? ProTheme.primary : Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: isPrimary
              ? const BorderSide(color: ProTheme.primary)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> order) {
    final vName = order['vendor_name'] ?? 'Target Restaurant';
    final vAddr = order['vendor_address'] ?? 'Loading...';
    final earnings = (order['total'] ?? 0) * 0.15;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: ProTheme.cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("EXTRACTION ASSIGNMENT",
                  style: ProTheme.label.copyWith(fontSize: 9)),
              Text("EST. PAYOUT", style: ProTheme.label.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(vName, style: ProTheme.title),
                    Text(vAddr,
                        style: ProTheme.body
                            .copyWith(fontSize: 12, color: ProTheme.gray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
              Text("₹${earnings.toInt()}",
                  style: ProTheme.header
                      .copyWith(fontSize: 22, color: ProTheme.secondary)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _acceptMission(order['order_id']),
              style: ProTheme.ctaButton,
              child: const Text("ACCEPT DEPLOYMENT"),
            ),
          )
        ],
      ),
    );
  }
}
