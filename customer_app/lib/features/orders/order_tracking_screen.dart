import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_chat_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  LatLng _pickup = const LatLng(0, 0);
  LatLng _delivery = const LatLng(0, 0);
  LatLng? _riderLocation;
  double _riderHeading = 0;
  List<LatLng> _routePoints = [];
  String _eta = "Calculating...";
  double _currentSpeed = 0;

  Map<String, dynamic> _currentOrder = {};
  bool _isDisposed = false;

  RealtimeChannel? _orderSubscription;
  RealtimeChannel? _trackingSubscription;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _initializeTracking();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trackingSubscription?.unsubscribe();
    _orderSubscription?.unsubscribe();
    super.dispose();
  }

  void _initializeTracking() {
    _updateLocationsFromData(_currentOrder);
    _refreshOrder();
    _subscribeToOrder(
        (_currentOrder['order_id'] ?? _currentOrder['id']).toString());
  }

  void _updateLocationsFromData(Map<String, dynamic> data) {
    // 📍 Pickup (Vendor)
    final pLat = (data['vendor_lat'] ??
                data['resolved_pickup_lat'] ??
                data['latitude'] as num?)
            ?.toDouble() ??
        0.0;
    final pLng = (data['vendor_lng'] ??
                data['resolved_pickup_lng'] ??
                data['longitude'] as num?)
            ?.toDouble() ??
        0.0;

    // 📍 Delivery (Customer)
    final dLat =
        (data['delivery_lat'] ?? data['lat'] ?? data['customer_lat'] as num?)
                ?.toDouble() ??
            0.0;
    final dLng =
        (data['delivery_lng'] ?? data['lng'] ?? data['customer_lng'] as num?)
                ?.toDouble() ??
            0.0;

    if (pLat != 0 && pLng != 0) _pickup = LatLng(pLat, pLng);
    if (dLat != 0 && dLng != 0) _delivery = LatLng(dLat, dLng);

    debugPrint(
        ">>> [TRACKING] Locations Sync: Pickup($_pickup), Delivery($_delivery)");

    // Auto-fit bounds if we have both points and map is ready
    if (_pickup.latitude != 0 && _delivery.latitude != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([_pickup, _delivery]),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 100),
          ));
        }
      });
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    if (_isDisposed || start.latitude == 0 || end.latitude == 0) return;
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coords =
              data['routes'][0]['geometry']['coordinates'];
          final double durationSeconds =
              (data['routes'][0]['duration'] as num).toDouble();

          if (mounted) {
            setState(() {
              _routePoints = coords
                  .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                  .toList();
              final mins = (durationSeconds / 60).ceil();
              _eta = mins <= 1 ? "Arriving now!" : "Arriving in $mins mins";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  void _subscribeToLiveTracking(String orderId) {
    if (_trackingSubscription != null) return;

    debugPrint(
        ">>> [TRACKING] Engaging High-Frequency Sync for Order: $orderId");

    _trackingSubscription = SupabaseConfig.client
        .channel('live_tracking_$orderId')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'order_live_tracking',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'order_id',
                value: orderId),
            callback: (payload) {
              final nLat = (payload.newRecord['rider_lat'] as num?)?.toDouble();
              final nLng = (payload.newRecord['rider_lng'] as num?)?.toDouble();
              final speed =
                  (payload.newRecord['speed'] as num?)?.toDouble() ?? 0.0;
              final heading =
                  (payload.newRecord['heading'] as num?)?.toDouble() ?? 0.0;

              if (nLat != null && nLng != null && nLat != 0) {
                _updateRiderMarker(LatLng(nLat, nLng), heading, speed);
              }
            })
        .subscribe();
  }

  void _updateRiderMarker(LatLng newPos, double heading, double speed) {
    if (!mounted) return;
    setState(() {
      _riderLocation = newPos;
      _riderHeading = heading;
      _currentSpeed = speed;
    });

    // Recalculate route and ETA on every marker update for "Moving Truth"
    _fetchRoute(newPos, _delivery);
  }

  void _subscribeToOrder(String orderId) {
    _orderSubscription = SupabaseConfig.client
        .channel('order_sync_$orderId')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: orderId),
            callback: (p) => _refreshOrder())
        .subscribe();
  }

  Future<void> _refreshOrder() async {
    try {
      final orderId = _currentOrder['order_id'] ?? _currentOrder['id'];
      final res = await SupabaseConfig.client
          .from('order_tracking_stabilized_v1')
          .select('*')
          .eq('order_id', orderId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _currentOrder = res;
          _updateLocationsFromData(res);

          // Hydrate rider location from the persistent columns
          final rLat = (res['rider_lat'] as num?)?.toDouble();
          final rLng = (res['rider_lng'] as num?)?.toDouble();

          if (rLat != null && rLng != null && rLat != 0) {
            _riderLocation = LatLng(rLat, rLng);
            _fetchRoute(_riderLocation!, _delivery);
          } else {
            // If rider not assigned, show route from vendor to customer
            _fetchRoute(_pickup, _delivery);
          }

          // Engage high-frequency engine if rider is assigned
          if (res['rider_id'] != null && _trackingSubscription == null) {
            _subscribeToLiveTracking(res['order_id'].toString());
          }
        });
      }
    } catch (e) {
      debugPrint("Refresh Order Error: $e");
    }
  }

  void _makeCall(String phone) async {
    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 15,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd']),
              PolylineLayer(polylines: [
                Polyline(
                    points: _routePoints,
                    color: ProTheme.primary.withOpacity(0.7),
                    strokeWidth: 6)
              ]),
              MarkerLayer(markers: [
                Marker(
                    point: _pickup,
                    width: 70,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: _buildLocationMarker(
                        LucideIcons.store, ProTheme.accent, "VENDOR")),
                Marker(
                    point: _delivery,
                    width: 70,
                    height: 90,
                    alignment: Alignment.topCenter,
                    child: _buildLocationMarker(
                        LucideIcons.home, ProTheme.secondary, "YOU")),
                if (_riderLocation != null && _riderLocation!.latitude != 0)
                  Marker(
                    point: _riderLocation!,
                    width: 70,
                    height: 70,
                    child: _buildRiderMarker(),
                  ),
              ]),
            ],
          ),
          _buildTopBar(),
          _buildTrackingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLocationMarker(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: ProTheme.softShadow,
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: ProTheme.softShadow,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ],
    );
  }

  Widget _buildRiderMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: ProTheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.5, 1.5))
            .fadeOut(),
        Transform.rotate(
          angle: _riderHeading * (3.14159 / 180),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: ProTheme.dark,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bike, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: ProTheme.dark),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ProTheme.dark,
              borderRadius: BorderRadius.circular(30),
              boxShadow: ProTheme.softShadow,
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.clock,
                    color: ProTheme.primary, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("ESTIMATED ARRIVAL",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    Text(_eta,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingOverlay() {
    final statusDisplay = _currentOrder['status_display'] ?? "Order Placed";
    final riderName = _currentOrder['rider_name'] ?? "Assigning Rider...";
    final riderVehicle = _currentOrder['rider_vehicle'] ?? "Searching...";
    final riderRating = _currentOrder['rider_rating']?.toString() ?? "4.8";
    final riderAvatar = _currentOrder['rider_avatar'];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(statusDisplay,
                            style: ProTheme.header.copyWith(fontSize: 22)),
                        const SizedBox(width: 8),
                        if (_currentSpeed > 2)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.zap,
                                    color: Colors.green, size: 12),
                                const SizedBox(width: 4),
                                Text("On the move",
                                    style: ProTheme.label.copyWith(
                                        color: Colors.green, fontSize: 10)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                            "ORDER #${_currentOrder['order_id'].toString().substring(0, 8).toUpperCase()}",
                            style: ProTheme.body.copyWith(
                                color: ProTheme.gray,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text("•", style: TextStyle(color: Colors.grey[300])),
                        const SizedBox(width: 8),
                        Text(
                          "₹${_currentOrder['total'] ?? _currentOrder['total_amount'] ?? '0'}",
                          style: ProTheme.header
                              .copyWith(fontSize: 14, color: ProTheme.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressBar(),
            const SizedBox(height: 24),
            // 📍 Delivery Address Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin,
                      color: ProTheme.secondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DELIVERY ADDRESS",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[600],
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          "${_currentOrder['delivery_address'] ?? 'Loading address...'}",
                          style: ProTheme.body.copyWith(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ProTheme.bg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: ProTheme.primary.withOpacity(0.2),
                    backgroundImage:
                        riderAvatar != null ? NetworkImage(riderAvatar) : null,
                    child: riderAvatar == null
                        ? const Icon(LucideIcons.user, color: ProTheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riderName,
                            style: ProTheme.label.copyWith(fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(riderRating,
                                style: ProTheme.body
                                    .copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Text(riderVehicle,
                                style: ProTheme.body
                                    .copyWith(color: ProTheme.gray)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(
                      LucideIcons.messageSquare, ProTheme.primary, () {
                    if (_currentOrder['rider_id'] == null) return;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrderChatScreen(
                                orderId: _currentOrder['order_id'].toString(),
                                riderName: riderName)));
                  }),
                  const SizedBox(width: 12),
                  _buildActionButton(LucideIcons.phone, const Color(0xFF10B981),
                      () {
                    if (_currentOrder['rider_phone'] != null) {
                      _makeCall(_currentOrder['rider_phone']);
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildProgressBar() {
    final int currentStep = _currentOrder['current_step'] ?? 1;

    return Row(
      children: List.generate(5, (index) {
        final step = index + 1;
        final bool isDone = step <= currentStep;
        final bool isCurrent = step == currentStep;

        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            decoration: BoxDecoration(
              color: isDone ? ProTheme.primary : ProTheme.gray.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: isCurrent
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1.seconds),
                  )
                : null,
          ),
        );
      }),
    );
  }
}
