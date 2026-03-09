import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Ensure data is loaded if not already present
    if (SupabaseConfig.bootstrapData == null) {
      _loading = true;
      SupabaseConfig.bootstrap().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus,
      {String? reason}) async {
    try {
      await SupabaseConfig.client.rpc('vendor_set_order_status_v1', params: {
        'p_order_id': orderId,
        'p_vendor_auth_id': SupabaseConfig.client.auth.currentUser?.id,
        'p_new_status': newStatus.toUpperCase(),
        'p_rejection_reason': reason
      });

      // Trigger a refresh
      await SupabaseConfig.bootstrap();
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  void _confirmRejection(String orderId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Order"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for rejection (mandatory)"),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  hintText: "Out of stock, closing soon, etc."),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reason is mandatory")));
                return;
              }
              _updateStatus(orderId, 'rejected', reason: controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("CONFIRM REJECT"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseConfig.notifier,
      builder: (context, _) {
        final ordersData = SupabaseConfig.bootstrapData?['orders'];
        final statsData = SupabaseConfig.bootstrapData?['stats'];

        final allOrders = (ordersData != null)
            ? List<Map<String, dynamic>>.from(ordersData)
            : <Map<String, dynamic>>[];

        final newOrders = allOrders.where((o) {
          final s = o['status']?.toString().toUpperCase();
          return s == 'PLACED' || s == 'PENDING';
        }).toList();

        final inProgressOrders = allOrders.where((o) {
          final s = o['status']?.toString().toUpperCase();
          return [
            'ACCEPTED',
            'RIDER_ASSIGNED',
            'PREPARING',
            'READY_FOR_PICKUP',
            'PICKING_UP',
            'PICKED_UP',
            'ON_THE_WAY'
          ].contains(s);
        }).toList();

        final historyOrders = allOrders.where((o) {
          final s = o['status']?.toString().toUpperCase();
          return ['DELIVERED', 'COMPLETED', 'CANCELLED', 'REJECTED']
              .contains(s);
        }).toList();

        // Financial Intelligence
        final pendingEarnings = allOrders
            .where((o) => [
                  'PLACED',
                  'ACCEPTED',
                  'PREPARING',
                  'READY_FOR_PICKUP'
                ].contains(o['status']?.toString().toUpperCase()))
            .fold(
                0.0,
                (sum, item) =>
                    sum + (double.tryParse(item['total'].toString()) ?? 0));

        final settledEarnings = (statsData != null &&
                statsData['total_earnings'] != null)
            ? (double.tryParse(statsData['total_earnings'].toString()) ?? 0.0)
            : allOrders
                .where((o) => ['DELIVERED', 'COMPLETED']
                    .contains(o['status']?.toString().toUpperCase()))
                .fold(
                    0.0,
                    (sum, item) =>
                        sum + (double.tryParse(item['total'].toString()) ?? 0));

        if (_loading && allOrders.isEmpty)
          return const Center(child: CircularProgressIndicator());

        return Column(
          children: [
            _buildFinancialPulse(pendingEarnings, settledEarnings),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(newOrders, mode: 'NEW'),
                  _buildOrderList(inProgressOrders, mode: 'ACTIVE'),
                  _buildOrderList(historyOrders, mode: 'HISTORY'),
                ],
              ),
            ),
            // 📡 REAL-TIME STATUS BAR
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: ProTheme.dark.withOpacity(0.03),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 10, color: ProTheme.secondary)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(),
                  const SizedBox(width: 8),
                  Text("ORDER RADAR ACTIVE • REALTIME SYNC ON",
                      style: ProTheme.label.copyWith(
                          fontSize: 8,
                          color: ProTheme.dark.withOpacity(0.5),
                          letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialPulse(double pending, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          _statCard("IN PIPELINE", "₹${pending.toInt()}", Icons.waves,
              ProTheme.warning),
          const SizedBox(width: 12),
          _statCard("TOTAL REVENUE", "₹${total.toInt()}",
              Icons.account_balance_wallet, ProTheme.secondary),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _statCard(String label, String val, IconData icon, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: ProTheme.cardDecor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: ProTheme.label
                        .copyWith(fontSize: 9, color: ProTheme.gray)),
                Icon(icon, size: 14, color: accent.withOpacity(0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: ProTheme.header.copyWith(fontSize: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(24),
      height: 54,
      decoration: BoxDecoration(
        color: ProTheme.dark.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: ProTheme.pureWhite,
          boxShadow: ProTheme.softShadow,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: ProTheme.dark,
        unselectedLabelColor: ProTheme.gray,
        labelStyle:
            ProTheme.button.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: "NEW"),
          Tab(text: "ACTIVE"),
          Tab(text: "HISTORY"),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders,
      {required String mode}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ProTheme.dark.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 54, color: ProTheme.gray.withOpacity(0.2)),
            ),
            const SizedBox(height: 20),
            Text(mode == 'NEW' ? "Scanning for orders..." : "Empty Archive",
                style: ProTheme.title
                    .copyWith(color: ProTheme.gray, fontSize: 16)),
          ],
        ),
      ).animate().fadeIn();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, mode);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String mode) {
    final items = order['items'] as List<dynamic>? ?? [];
    final status = order['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final isHistory = mode == 'HISTORY';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: ProTheme.cardDecor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ProTheme.dark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          "#${order['id'].toString().toUpperCase().substring(0, 8)}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                    Text(status,
                        style: ProTheme.label.copyWith(
                            fontSize: 10,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text("${item['qty']}x",
                              style: ProTheme.label.copyWith(
                                  color: ProTheme.gray,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(item['name'],
                                  style:
                                      ProTheme.title.copyWith(fontSize: 15))),
                          Text("₹${item['price']}",
                              style: ProTheme.body
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("REVENUE",
                            style: ProTheme.label.copyWith(fontSize: 9)),
                        Text("₹${order['total']}",
                            style: ProTheme.header.copyWith(
                                fontSize: 20, color: ProTheme.secondary)),
                      ],
                    ),
                    if (mode == 'NEW')
                      Row(
                        children: [
                          _actionBtn(Icons.close, ProTheme.error,
                              () => _confirmRejection(order['id'])),
                          const SizedBox(width: 12),
                          _actionBtn(Icons.check, ProTheme.success,
                              () => _updateStatus(order['id'], 'ACCEPTED'),
                              isPrimary: true),
                        ],
                      )
                    else if (!isHistory)
                      _buildStatusAction(order),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PLACED':
        return ProTheme.warning;
      case 'ACCEPTED':
        return ProTheme.primary;
      case 'READY_FOR_PICKUP':
        return Colors.green;
      case 'DELIVERED':
        return ProTheme.secondary;
      case 'CANCELLED':
        return ProTheme.error;
      default:
        return ProTheme.gray;
    }
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap,
      {bool isPrimary = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                isPrimary ? null : Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusAction(Map<String, dynamic> order) {
    final status = order['status']?.toString().toUpperCase();
    String label = "NEXT PHASE";
    String nextStatus = "READY_FOR_PICKUP";
    Color color = ProTheme.dark;

    if (status == 'ACCEPTED') {
      label = "START PREPARING";
      nextStatus = "PREPARING";
      color = ProTheme.primary;
    } else if (status == 'PREPARING') {
      label = "MARK READY";
      nextStatus = "READY_FOR_PICKUP";
      color = Colors.green;
    } else if (status == 'READY_FOR_PICKUP') {
      label = "AWAITING RIDER";
      color = ProTheme.gray;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: ProTheme.label.copyWith(fontSize: 10, color: color)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: ProTheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Text("IN TRANSIT",
            style: ProTheme.label
                .copyWith(fontSize: 10, color: ProTheme.secondary)),
      );
    }

    return ElevatedButton(
      onPressed: () => _updateStatus(order['id'], nextStatus),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor:
            color == ProTheme.primary ? ProTheme.dark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: ProTheme.button.copyWith(fontSize: 11)),
    );
  }
}
