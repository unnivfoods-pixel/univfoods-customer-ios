import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../supabase_config.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _pulseTimer;
  Position? _lastPos;

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever)
      return Future.error('Location permissions are permanently denied');

    return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best));
  }

  void startTracking(String riderId, {String? orderId}) {
    _positionSubscription?.cancel();
    _pulseTimer?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((Position position) {
      _lastPos = position;
    });

    // Pulse GPS every 5 seconds (Truth Protocol)
    _pulseTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_lastPos == null) return;

      try {
        await SupabaseConfig.client.rpc('rider_update_gps_v1', params: {
          'p_rider_auth_id': riderId,
          'p_lat': _lastPos!.latitude,
          'p_lng': _lastPos!.longitude,
          'p_bearing': _lastPos!.heading,
          'p_speed': _lastPos!.speed,
        });
      } catch (e) {
        debugPrint("Dev Pulse Error: $e");
      }
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _pulseTimer?.cancel();
    _positionSubscription = null;
    _pulseTimer = null;
  }
}
