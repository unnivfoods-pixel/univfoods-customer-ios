import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import 'order_tracking_screen.dart';
import 'order_chat_screen.dart';
import '../support/support_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/order_store.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Map<String, dynamic> _currentOrder;
  Map<String, dynamic>? _rider;
  RealtimeChannel? _subscription;
  RealtimeChannel? _riderSub;
  final OrderStore _orderStore = OrderStore();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _setupRealtime();
    _fetchRider();
    _orderStore.addListener(_onOrderStoreUpdate);
    // ⚡ SILENT SYNC: Fetch rich metadata immediately so user doesn't have to pull-to-refresh
    _refreshDetails();
  }

  void _onOrderStoreUpdate() {
    final targetId = (widget.order['order_id'] ?? widget.order['id'])
        .toString()
        .toLowerCase();

    final updatedOrder = _orderStore.orders.firstWhere(
      (o) => (o['order_id'] ?? o['id']).toString().toLowerCase() == targetId,
      orElse: () => {},
    );

    if (updatedOrder.isNotEmpty && mounted) {
      final merged = {..._currentOrder, ...updatedOrder};
      // Always normalize status for the stepper
      merged['status'] = (updatedOrder['order_status'] ??
              updatedOrder['status'] ??
              _currentOrder['status'] ??
              'PLACED')
          .toString();
      debugPrint(
          ">>> [INSTANT SYNC] Status: ${merged['status']} for: $targetId");
      setState(() {
        _currentOrder = merged;
      });
    }
  }

  Future<void> _refreshDetails() async {
    // Use order_tracking_stabilized_v1 — it has correct status + all display fields
    try {
      final orderId =
          (widget.order['order_id'] ?? widget.order['id']).toString();
      final res = await SupabaseConfig.client
          .from('order_tracking_stabilized_v1')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (mounted && res != null) {
        // Normalize: ensure 'status' key always exists from order_status
        final merged = {..._currentOrder, ...res};
        merged['status'] =
            res['order_status'] ?? res['status'] ?? _currentOrder['status'];
        setState(() => _currentOrder = merged);
        debugPrint('>>> [REFRESH] Status: ${merged['status']}');
      }
    } catch (e) {
      debugPrint("Silent Sync Error: $e");
    }
  }

  Future<void> _fetchRider() async {
    final riderId = _currentOrder['rider_id'];
    if (riderId == null) return;

    try {
      final res = await SupabaseConfig.client
          .from('delivery_riders')
          .select()
          .eq('id', riderId.toString())
          .maybeSingle();

      if (mounted && res != null) {
        setState(() => _rider = res);
        _setupRiderRealtime(riderId.toString());
      }
    } catch (e) {
      debugPrint("Rider Fetch Error: $e");
    }
  }

  void _setupRiderRealtime(String id) {
    _riderSub?.unsubscribe();
    _riderSub = SupabaseConfig.client
        .channel('rider_telemetry_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_riders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() => _rider = payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  void _setupRealtime() {
    _subscription = SupabaseConfig.client
        .channel('order_details_${widget.order['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.order['id'],
          ),
          callback: (payload) {
            debugPrint(
                ">>> [REALTIME] Order Update Detected: ${payload.newRecord['status']}");
            _refreshDetails(); // Force full refresh from truth-view
            if (payload.newRecord['rider_id'] != null && _rider == null) {
              _fetchRider();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _riderSub?.unsubscribe();
    _orderStore.removeListener(_onOrderStoreUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read status from multiple possible fields for maximum compatibility
    final rawStatus =
        _currentOrder['order_status'] ?? _currentOrder['status'] ?? 'PLACED';
    final status = rawStatus.toString().toLowerCase();

    final List items;
    final rawItems = _currentOrder['items'];
    if (rawItems is List) {
      items = rawItems;
    } else if (rawItems is Map && rawItems.containsKey('name')) {
      items = [rawItems];
    } else if (rawItems is Map) {
      items = rawItems.values.toList();
    } else {
      items = [];
    }

    final String displayVendorName = _currentOrder['vendor_name'] ??
        _currentOrder['vendors']?['name'] ??
        _currentOrder['vendor_display_name'] ??
        "Boutique Kitchen";
    String displayAddress = _currentOrder['effective_address'] ??
        _currentOrder['delivery_address'] ??
        _currentOrder['address'] ??
        "My Address";

    // 🛡️ ANTI-FLICKER: If the address is literal {} or empty, show a loading hint instead
    if (displayAddress == "{}" || displayAddress.trim().isEmpty) {
      displayAddress = "Verifying address...";
    }

    bool isTrackingAvailable =
        ['rider_assigned', 'picked_up', 'on_the_way'].contains(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text("ORDER DETAILS",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusStepper(status),
              if (_rider != null) _buildRiderCard(),
              _buildSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            "Order #${_currentOrder['id'].toString().substring(0, 8)}",
                            style: GoogleFonts.outfit(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        "${_currentOrder['created_at']?.toString().substring(0, 10)}  •  ${_currentOrder['payment_method'] ?? 'COD'}",
                        style: GoogleFonts.inter(
                            color: Colors.grey, fontSize: 13)),
                    // REMOVED DELIVERY OTP AS REQUESTED

                    const Divider(height: 32),
                    Row(
                      children: [
                        const Icon(Icons.storefront,
                            size: 18, color: Color(0xFFFF4500)),
                        const SizedBox(width: 8),
                        Text(displayVendorName,
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayAddress,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_currentOrder['delivery_house_number'] !=
                                      null)
                                    _buildSmallBadge(
                                        "HOUSE: ${_currentOrder['delivery_house_number']}",
                                        Colors.orange),
                                  if (_currentOrder['delivery_pincode'] != null)
                                    _buildSmallBadge(
                                        "PIN: ${_currentOrder['delivery_pincode']}",
                                        Colors.blue),
                                  if (_currentOrder['delivery_phone'] != null ||
                                      _currentOrder['customer_phone'] != null)
                                    _buildSmallBadge(
                                        "📞 ${_currentOrder['delivery_phone'] ?? _currentOrder['customer_phone']}",
                                        Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_currentOrder['delivery_instructions'] != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  "INSTRUCTIONS: ${_currentOrder['delivery_instructions']}",
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569))),
                            ),
                            IconButton(
                              onPressed: () => _editInstructions(),
                              icon: const Icon(Icons.edit, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _editInstructions(),
                        icon: const Icon(Icons.add_comment_rounded, size: 16),
                        label: const Text("ADD DELIVERY INSTRUCTIONS"),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          textStyle: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. TIPPING CONSOLE
              if (status != 'delivered') _buildTippingSection(),
              _buildSection(
                title: "ITEM SUMMARY",
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is! Map) return const SizedBox();
                    final qty = item['qty'] ?? 1;
                    final name = item['name'] ?? "Item";
                    final price = (item['price'] ?? 0);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$qty x $name",
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        Text("₹${price * qty}",
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),
              _buildSection(
                title: "BILL DETAILS",
                child: Column(
                  children: [
                    Builder(builder: (context) {
                      final double itemTotal = items.fold(0.0, (sum, item) {
                        final price =
                            double.tryParse(item['price'].toString()) ?? 0.0;
                        final qty = (item['qty'] ?? 1).toDouble();
                        return sum + (price * qty);
                      });
                      return _buildBillRow("Item Total", "₹$itemTotal");
                    }),
                    if ((_currentOrder['tip_amount'] ?? 0) > 0)
                      _buildBillRow(
                          "Rider Tip", "₹${_currentOrder['tip_amount']}"),
                    _buildBillRow("Delivery Fee", "₹0"),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TOTAL",
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(
                            "₹${(_currentOrder['total'] ?? _currentOrder['total_amount'] ?? 0) + (_currentOrder['tip_amount'] ?? 0)}",
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: const Color(0xFFFF4500))),
                      ],
                    ),
                  ],
                ),
              ),

              if (status == 'delivered' ||
                  _currentOrder['delivered_at'] != null)
                _buildLogisticsTimeline(),

              if (isTrackingAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                OrderTrackingScreen(order: _currentOrder))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("LIVE TRACKING",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: Colors.white)),
                  ),
                ),

              // 🟢 CRISIS MANAGEMENT ACTIONS
              if (status == 'delivered')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => _showRatingDialog(context),
                    icon: const Icon(Icons.star_rounded, color: Colors.white),
                    label: Text("RATE THIS ORDER",
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

              _buildCrisisActions(status),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrisisActions(String status) {
    // 🛡️ SECURITY: Expanded cancellation window to include PREPARING and RIDER_ASSIGNED.
    // Customers can cancel as long as the food is not yet with the rider (PICKED_UP).
    final cancelableStatuses = [
      'placed',
      'pending',
      'accepted',
      'preparing',
      'confirmed',
      'ready',
      'ready_for_pickup',
      'rider_assigned',
      'assigning_rider'
    ];
    bool canCancel = cancelableStatuses.contains(status.trim().toLowerCase());

    return Column(
      children: [
        if (canCancel) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _confirmCancellation(),
            icon: const Icon(Icons.cancel_rounded, color: Colors.white),
            label: Text("CANCEL THIS ORDER",
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (status == 'delivered') ...[
          TextButton.icon(
            onPressed: () => _showRefundDialog(context),
            icon: const Icon(Icons.money_off_rounded, color: Colors.orange),
            label: Text("REQUEST REFUND",
                style: GoogleFonts.outfit(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.orange.withOpacity(0.2))),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: () => _launchSupport(),
          icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
          label: Text("GET HELP & SUPPORT",
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Future<void> _launchSupport() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      final userId = SupabaseConfig.forcedUserId ?? user?.id;
      if (userId == null) return;

      final existing = await SupabaseConfig.client
          .from('support_chats')
          .select()
          .eq('user_id', userId)
          .eq('order_id', _currentOrder['id'].toString())
          .eq('status', 'BOT')
          .maybeSingle();

      String chatId;
      if (existing != null) {
        chatId = existing['id'];
      } else {
        final res = await SupabaseConfig.client
            .from('support_chats')
            .insert({
              'user_id': userId,
              'user_type': 'CUSTOMER',
              'order_id': _currentOrder['id'].toString(),
              'status': 'BOT',
              'priority': 'NORMAL',
            })
            .select()
            .single();
        chatId = res['id'];
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(
              id: chatId,
              subject:
                  "Order Support: ${_currentOrder['id'].toString().substring(0, 8)}",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("SUPPORT FAULT: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _editInstructions() async {
    final controller = TextEditingController(
        text: _currentOrder['delivery_instructions'] ?? "");
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("SPECIAL INSTRUCTIONS",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Drop at gate, call on arrival, etc.",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCEL")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("SAVE")),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseConfig.client
            .rpc('update_order_instructions_v3', params: {
          'p_order_id': _currentOrder['id'].toString(),
          'p_instructions': controller.text.trim()
        });
        setState(() {
          _currentOrder['delivery_instructions'] = controller.text.trim();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("FAILED TO SAVE: $e"),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("ABORT MISSION?",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: const Text(
            "Are you sure you want to cancel this order? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("NO")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("YES, CANCEL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseConfig.client.rpc('update_order_status_v3', params: {
          'p_order_id': _currentOrder['id'].toString(),
          'p_new_status': 'cancelled'
        });
        if (mounted) {
          setState(() {
            _currentOrder['status'] = 'cancelled';
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("ORDER CANCELLED SUCCESSFULLY")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("CANCELLATION FAILED: $e"),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _showRefundDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    final List<String> reasons = [
      "Wrong items delivered",
      "Food quality issue",
      "Late delivery",
      "Spilled / Damaged items",
      "Other"
    ];
    String selectedReason = reasons[0];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Request Refund",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedReason = v!),
                  decoration: const InputDecoration(labelText: "Main Reason"),
                ),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Add details about the issue...",
                    labelText: "Extra Details",
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Order Amount: ₹${_currentOrder['total']}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CLOSE")),
            ElevatedButton(
              onPressed: () async {
                final userId = SupabaseConfig.forcedUserId ??
                    SupabaseConfig.client.auth.currentUser?.id;
                if (userId == null) return;

                try {
                  await SupabaseConfig.client.from('refund_requests').insert({
                    'order_id': _currentOrder['id'].toString(),
                    'user_id': userId,
                    'reason': "$selectedReason: ${reasonController.text}",
                    'amount': (_currentOrder['total'] ?? 0).toDouble(),
                    'status': 'PENDING',
                    'payment_method': _currentOrder['payment_method'],
                  });

                  if (context.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("REFUND REQUEST SUBMITTED SUCCESSFULLY"),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("SUBMISSION FAILED: $e"),
                        backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("SUBMIT REQUEST"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'delivered' ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: status == 'delivered'
                  ? Colors.green[800]
                  : Colors.orange[800])),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
          Text(value,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusStepper(String currentStatus) {
    final stages = [
      {'id': 'PLACED', 'label': 'Order Placed'},
      {'id': 'ACCEPTED', 'label': 'Accepted'},
      {'id': 'PREPARING', 'label': 'Chef Cooking'},
      {'id': 'READY_FOR_PICKUP', 'label': 'Ready for Pickup'},
      {'id': 'PICKED_UP', 'label': 'Rider Picked Food'},
      {'id': 'ON_THE_WAY', 'label': 'On the Way'},
      {'id': 'DELIVERED', 'label': 'Delivered'},
    ];

    String normalizedStatus = currentStatus.toUpperCase();
    // Legacy mapping
    if (normalizedStatus == 'READY') normalizedStatus = 'READY_FOR_PICKUP';
    if (normalizedStatus == 'PICKED') normalizedStatus = 'PICKED_UP';

    int currentIndex = stages.indexWhere((s) => s['id'] == normalizedStatus);
    if (currentIndex == -1) {
      // Fallback: use database provided step if available
      final dbStep = _currentOrder['current_step'];
      if (dbStep != null && dbStep is int) {
        currentIndex = dbStep - 1;
      } else {
        currentIndex = 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stages.length, (index) {
              bool isDone = index <= currentIndex;
              bool isCurrent = index == currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color:
                            isDone ? const Color(0xFFFFD600) : Colors.white24,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                    if (index < stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentIndex
                              ? const Color(0xFFFFD600)
                              : Colors.white12,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stages[currentIndex]['label']!.toUpperCase(),
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFFD600),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1),
              ),
              if (currentStatus == 'on_the_way')
                Text(
                  _currentOrder['eta_minutes'] != null
                      ? "${_currentOrder['eta_minutes']} MINS AWAY"
                      : "CALCULATING...",
                  style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard() {
    final battery = _rider?['battery_percent'] ?? 100;
    final internet = _rider?['internet_status'] ?? 'online';
    final rating = _rider?['rating'] ?? 4.8;
    final missions = _rider?['missions_completed'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.two_wheeler, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_rider?['name'] ?? "Dispatch Unit",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFD600)),
                        const SizedBox(width: 4),
                        Text(rating.toString(),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Text("•  $missions DELIVERIES",
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        internet == 'online' ? Icons.wifi : Icons.wifi_off,
                        size: 10,
                        color: internet == 'online' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text("$battery%",
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderChatScreen(
                        orderId: _currentOrder['id'].toString(),
                        riderName: _rider?['name'] ?? "Rider",
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text("CHAT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final phone = _rider?['phone'];
                    if (phone != null) {
                      final url = Uri.parse("tel:$phone");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    }
                  },
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text("CALL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTippingSection() {
    final currentTip = (_currentOrder['tip_amount'] ?? 0);
    return _buildSection(
      title: "SUPPORT YOUR RIDER",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Add a tip to say thanks for their hard work!",
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [10, 20, 50].map((amount) {
              final isSelected = currentTip == amount;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => _setTip(amount),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1),
                      backgroundColor: isSelected
                          ? const Color(0xFFFFD700).withOpacity(0.05)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("₹$amount",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? const Color(0xFFB45309)
                                : const Color(0xFF0F172A))),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _setTip(int amount) async {
    final double currentTip =
        double.tryParse((_currentOrder['tip_amount'] ?? 0).toString()) ?? 0.0;
    double targetAmount = amount.toDouble();

    // Toggle logic: if clicking the same amount, remove it (set to 0)
    if (currentTip == targetAmount) {
      targetAmount = 0;
    }

    // Since add_order_tip_v3 is additive (tip = tip + p_amount),
    // we must send the delta to effectively "set" it.
    final double delta = targetAmount - currentTip;

    if (delta == 0) return;

    // 🚀 Optimistic UI Update
    setState(() {
      _currentOrder['tip_amount'] = targetAmount;
    });

    try {
      await SupabaseConfig.client.rpc('add_order_tip_v3', params: {
        'p_order_id': _currentOrder['id'].toString(),
        'p_amount': delta
      });

      // Tip applied silently
    } catch (e) {
      // Rollback on failure
      setState(() {
        _currentOrder['tip_amount'] = currentTip;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("TIP FAILED: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRatingDialog(BuildContext context) async {
    double vendorRating = 5;
    double riderRating = 5;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Rate Your Experience",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Restaurant",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                          icon: Icon(
                              index < vendorRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber),
                          onPressed: () =>
                              setState(() => vendorRating = index + 1.0),
                        )),
              ),
              const SizedBox(height: 16),
              Text("Delivery Partner",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                          icon: Icon(
                              index < riderRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber),
                          onPressed: () =>
                              setState(() => riderRating = index + 1.0),
                        )),
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                    hintText: "Add an optional comment..."),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("SKIP")),
            ElevatedButton(
              onPressed: () async {
                final userId = SupabaseConfig.forcedUserId ??
                    SupabaseConfig.client.auth.currentUser?.id;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please login to rate")));
                  return;
                }

                try {
                  // Save Vendor Review
                  await SupabaseConfig.client.from('reviews').insert({
                    'order_id': _currentOrder['id'],
                    'customer_id': userId,
                    'vendor_id': _currentOrder['vendor_id'],
                    'rating': vendorRating.toInt(),
                    'comment': commentController.text,
                    'target_type': 'vendor'
                  });

                  // Save Rider Review
                  if (_currentOrder['rider_id'] != null) {
                    await SupabaseConfig.client.from('reviews').insert({
                      'order_id': _currentOrder['id'],
                      'customer_id': userId,
                      'rider_id': _currentOrder['rider_id'].toString(),
                      'rating': riderRating.toInt(),
                      'comment': commentController.text,
                      'target_type': 'rider'
                    });
                  }

                  if (context.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Thanks for your feedback!")));
                  }
                } catch (e) {
                  debugPrint("Rating error: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to submit rating: $e")));
                  }
                }
              },
              child: const Text("SUBMIT"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogisticsTimeline() {
    final placed =
        DateTime.tryParse(_currentOrder['created_at']?.toString() ?? '');
    final accepted =
        DateTime.tryParse(_currentOrder['assigned_at']?.toString() ?? '');
    final picked =
        DateTime.tryParse(_currentOrder['pickup_time']?.toString() ?? '');
    final delivered =
        DateTime.tryParse(_currentOrder['delivered_at']?.toString() ?? '');

    String formatDuration(DateTime? start, DateTime? end) {
      if (start == null || end == null) return "N/A";
      final diff = end.difference(start);
      if (diff.isNegative) return "0m";
      if (diff.inHours > 0) return "${diff.inHours}h ${diff.inMinutes % 60}m";
      return "${diff.inMinutes}m";
    }

    return _buildSection(
      title: "LOGISTICS ANALYSIS",
      child: Column(
        children: [
          _logisticsRow("Preparation Time", formatDuration(accepted, picked),
              Icons.restaurant),
          const SizedBox(height: 12),
          _logisticsRow("Delivery Velocity", formatDuration(picked, delivered),
              Icons.delivery_dining),
          const SizedBox(height: 12),
          _logisticsRow("Total Mission Time", formatDuration(placed, delivered),
              Icons.timer),
        ],
      ),
    );
  }

  Widget _logisticsRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800])),
      ],
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}
