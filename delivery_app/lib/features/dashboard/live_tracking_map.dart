import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiveTrackingMap extends StatefulWidget {
  final bool isOnline;
  const LiveTrackingMap({super.key, required this.isOnline});

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  LatLng _currentPos = const LatLng(0, 0);
  double _heading = 0;
  bool _isSimulating = false;
  List<Map<String, dynamic>> _missionPoints = [];
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchMissions();
    _subscribeToMissionUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _subscribeToMissionUpdates() {
    SupabaseConfig.client
        .channel('mission_radar')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) => _fetchMissions())
        .subscribe();
  }

  Future<void> _fetchMissions() async {
    final riderId = SupabaseConfig.client.auth.currentUser?.id;
    if (riderId == null) return;

    try {
      // Get active or available missions
      final res = await SupabaseConfig.client
          .from('order_details_v3')
          .select('*')
          .or('rider_id.eq.$riderId,status.in.(placed,ready)');

      if (mounted) {
        setState(() {
          _missionPoints = List<Map<String, dynamic>>.from(res);
        });
        _calculateRoute();
      }
    } catch (e) {
      debugPrint("Mission Fetch Error: $e");
    }
  }

  Future<void> _calculateRoute() async {
    final active = _missionPoints.cast<Map<String, dynamic>?>().firstWhere(
          (m) =>
              m?['rider_id']?.toString() ==
              SupabaseConfig.client.auth.currentUser?.id,
          orElse: () => null,
        );

    if (active == null) {
      setState(() => _routePoints = []);
      return;
    }

    final status = active['status']?.toString().toLowerCase();
    LatLng target;

    if (['placed', 'accepted', 'preparing', 'ready'].contains(status)) {
      target = LatLng(
        (active['resolved_pickup_lat'] as num).toDouble(),
        (active['resolved_pickup_lng'] as num).toDouble(),
      );
    } else {
      target = LatLng(
        (active['delivery_lat'] as num).toDouble(),
        (active['delivery_lng'] as num).toDouble(),
      );
    }

    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_currentPos.longitude},${_currentPos.latitude};${target.longitude},${target.latitude}?overview=full&geometries=geojson');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coords =
              data['routes'][0]['geometry']['coordinates'];
          if (mounted) {
            setState(() {
              _routePoints = coords
                  .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("OSRM Route Error: $e");
    }
  }

  void _initLocation() async {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
          _heading = pos.heading;
        });
        _broadcastToCloud(pos);
        if (_routePoints.isEmpty) _calculateRoute();
      }
    });

    // Get initial
    Position p = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => _currentPos = LatLng(p.latitude, p.longitude));
  }

  Future<void> _broadcastToCloud(Position pos) async {
    if (!widget.isOnline) return;
    final riderId = SupabaseConfig.client.auth.currentUser?.id;
    if (riderId == null) return;

    final active = _missionPoints.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['rider_id']?.toString() == riderId,
          orElse: () => null,
        );

    try {
      await SupabaseConfig.client.rpc('update_delivery_location_v16', params: {
        'p_order_id': active?['id'],
        'p_rider_id': riderId,
        'p_lat': pos.latitude,
        'p_lng': pos.longitude,
        'p_speed': pos.speed,
        'p_heading': pos.heading,
      });
    } catch (e) {
      debugPrint("GPS Broadcast Error: $e");
    }
  }

  void _simulateMovement() {
    setState(() => _isSimulating = !_isSimulating);
    if (!_isSimulating) return;

    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!_isSimulating || !mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _currentPos = LatLng(
            _currentPos.latitude + 0.0002, _currentPos.longitude + 0.0002);
      });
      _broadcastToCloud(Position(
        latitude: _currentPos.latitude,
        longitude: _currentPos.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 45,
        speed: 10,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentPos, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: ProTheme.primary,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Rider
                  Marker(
                    point: _currentPos,
                    width: 70,
                    height: 70,
                    child: Transform.rotate(
                      angle: _heading * (3.14159 / 180),
                      child: _buildRiderIcon(),
                    ),
                  ),
                  // Missions
                  ..._missionPoints.map((m) {
                    final isMine = m['rider_id']?.toString() ==
                        SupabaseConfig.client.auth.currentUser?.id;
                    final isPickup = [
                      'placed',
                      'accepted',
                      'preparing',
                      'ready'
                    ].contains(m['status']?.toString().toLowerCase());

                    final lat =
                        isPickup ? m['resolved_pickup_lat'] : m['delivery_lat'];
                    final lng =
                        isPickup ? m['resolved_pickup_lng'] : m['delivery_lng'];

                    if (lat == null || lng == null)
                      return const Marker(
                          point: LatLng(0, 0), child: SizedBox());

                    return Marker(
                      point: LatLng(
                          (lat as num).toDouble(), (lng as num).toDouble()),
                      width: 45,
                      height: 45,
                      child: _buildTacticalMarker(
                          isPickup ? LucideIcons.store : LucideIcons.home,
                          isMine ? ProTheme.accent : Colors.orange,
                          isMine),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          _buildOverlayUI(),
        ],
      ),
    );
  }

  Widget _buildRiderIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: ProTheme.primary.withOpacity(0.3), shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(1, 1), end: const Offset(2, 2))
            .fadeOut(),
        const Icon(LucideIcons.bike, color: ProTheme.dark, size: 30),
      ],
    );
  }

  Widget _buildTacticalMarker(IconData icon, Color color, bool isMine) {
    return Container(
      decoration: BoxDecoration(
        color: ProTheme.dark,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)],
      ),
      child: Icon(icon, color: color, size: 20),
    ).animate(target: isMine ? 1.0 : 0.0).shimmer(duration: 2.seconds);
  }

  Widget _buildOverlayUI() {
    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: ProTheme.cardDecor.copyWith(color: ProTheme.slate),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: widget.isOnline
                      ? ProTheme.secondary.withOpacity(0.1)
                      : ProTheme.error.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(
                  widget.isOnline
                      ? LucideIcons.locateFixed
                      : LucideIcons.locateOff,
                  color: widget.isOnline ? ProTheme.secondary : ProTheme.error),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.isOnline ? "RADAR ACTIVE" : "RADAR OFFLINE",
                      style: ProTheme.title
                          .copyWith(color: Colors.white, fontSize: 16)),
                  Text(
                      widget.isOnline
                          ? "Syncing route with mission..."
                          : "Ready to engage",
                      style: ProTheme.body
                          .copyWith(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
                onPressed: _simulateMovement,
                icon: Icon(LucideIcons.navigation,
                    color: _isSimulating ? ProTheme.accent : ProTheme.primary)),
            IconButton(
                onPressed: _fetchMissions,
                icon: const Icon(LucideIcons.refreshCw,
                    color: ProTheme.primary, size: 20)),
          ],
        ),
      ),
    );
  }
}
