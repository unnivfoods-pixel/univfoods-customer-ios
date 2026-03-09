import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class LocationService {
  // Memory cache for geocoding to speed up repeated lookups
  static final Map<String, String> _addressCache = {};
  static final Map<String, LatLng> _coordCache = {};
  static String? _lastKnownAddress;
  static LatLng? _lastKnownLatLng;

  static String? get cachedAddress => _lastKnownAddress;
  static LatLng? get cachedLatLng => _lastKnownLatLng;

  static Future<void> loadLocationFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastKnownAddress = prefs.getString('last_address');
      final lat = prefs.getDouble('last_lat');
      final lng = prefs.getDouble('last_lng');
      if (lat != null && lng != null) {
        _lastKnownLatLng = LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint("Error loading location from disk: $e");
    }
  }

  static Future<void> saveLocationToDisk(
      String address, double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_address', address);
      await prefs.setDouble('last_lat', lat);
      await prefs.setDouble('last_lng', lng);
    } catch (e) {
      debugPrint("Error saving location to disk: $e");
    }
  }

  static Future<Position?> getCurrentPosition({bool forceFresh = true}) async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint("LocationService: Bypassing real GPS for Windows platform");
        return await Geolocator.getLastKnownPosition();
      }

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled.");
        return await Geolocator.getLastKnownPosition();
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permission denied.");
          return await Geolocator.getLastKnownPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await Geolocator.getLastKnownPosition();
      }

      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && !forceFresh) {
        _lastKnownLatLng = LatLng(lastPos.latitude, lastPos.longitude);
        return lastPos;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 5), onTimeout: () async {
        debugPrint("Location capture timed out, using last known.");
        if (lastPos != null) return lastPos;
        throw TimeoutException("Timeout fetching location");
      });
    } catch (e) {
      debugPrint("Location discovery error: $e");
      return await Geolocator.getLastKnownPosition();
    }
  }

  static Future<Map<String, dynamic>> getDetailedAddressFromLatLng(
      double lat, double lng) async {
    if (AppConfig.googleMapsApiKey != "YOUR_GOOGLE_MAPS_API_KEY_HERE" &&
        AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${AppConfig.googleMapsApiKey}');
        final response =
            await http.get(url).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' &&
              data['results'] != null &&
              (data['results'] as List).isNotEmpty) {
            final first = data['results'][0];
            final addrComp = first['address_components'] as List;

            String getComp(String type) {
              final found = addrComp.firstWhere(
                  (c) => (c['types'] as List).contains(type),
                  orElse: () => null);
              return found != null ? (found['long_name'] ?? '') : '';
            }

            return {
              'full_address': first['formatted_address'],
              'road': getComp('route').isNotEmpty
                  ? getComp('route')
                  : (getComp('sublocality').isNotEmpty
                      ? getComp('sublocality')
                      : getComp('neighborhood')),
              'city': getComp('locality').isNotEmpty
                  ? getComp('locality')
                  : (getComp('administrative_area_level_2').isNotEmpty
                      ? getComp('administrative_area_level_2')
                      : ''),
              'postcode': getComp('postal_code'),
              'state': getComp('administrative_area_level_1'),
            };
          }
        }
      } catch (e) {
        debugPrint("Google Geocoding error: $e");
      }
    }

    for (int i = 0; i < 2; i++) {
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1');
        final response = await http.get(url, headers: {
          'User-Agent': 'CurryApp_User_${DateTime.now().millisecondsSinceEpoch}'
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'] ?? {};

          return {
            'full_address': data['display_name'],
            'road': address['road'] ??
                address['suburb'] ??
                address['neighbourhood'] ??
                address['pedestrian'] ??
                '',
            'city':
                address['city'] ?? address['town'] ?? address['village'] ?? '',
            'postcode': address['postcode'] ?? '',
            'state': address['state'] ?? '',
          };
        }
      } catch (e) {
        debugPrint("Detailed Geocoding attempt ${i + 1} error: $e");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return {};
  }

  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    if (lat == 0 && lng == 0) return "Detecting Location...";

    final cacheKey = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";
    if (_addressCache.containsKey(cacheKey)) {
      _lastKnownAddress = _addressCache[cacheKey];
      _lastKnownLatLng = LatLng(lat, lng);
      return _addressCache[cacheKey]!;
    }

    try {
      final res = await getDetailedAddressFromLatLng(lat, lng);
      if (res.isNotEmpty) {
        // 🚀 USE FULL ADDRESS: User requested the complete address string
        String result = res['full_address'] ?? "";

        if (result.isEmpty || result.length < 5) {
          final road = res['road'];
          final city = res['city'];
          result = (road != null && road.isNotEmpty)
              ? "$road, $city"
              : "Area near $city";
        }

        _addressCache[cacheKey] = result;
        _lastKnownAddress = result;
        _lastKnownLatLng = LatLng(lat, lng);
        saveLocationToDisk(result, lat, lng);
        return result;
      }
    } catch (e) {
      debugPrint("Geocoding logic error: $e");
    }

    return "Nearby Indra Nagar"; // Default fallback for your region if API is slow
  }

  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.length < 3) return [];
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=8&countrycodes=in');

      final response = await http.get(url, headers: {
        'User-Agent': 'CurryApp_Search_${DateTime.now().millisecondsSinceEpoch}'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;
          return {
            'display_name': item['display_name'] ?? 'Unknown Location',
            'lat': lat,
            'lon': lon,
            'address': item['address'] ?? {},
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Search places error: $e");
    }
    return [];
  }

  static Future<Map<String, double>?> getLatLngFromAddress(
      String address) async {
    if (address.isEmpty) return null;
    if (_coordCache.containsKey(address)) {
      return {
        'lat': _coordCache[address]!.latitude,
        'lng': _coordCache[address]!.longitude
      };
    }

    try {
      // 1. TRY GOOGLE FIRST
      if (AppConfig.googleMapsApiKey != "YOUR_GOOGLE_MAPS_API_KEY_HERE" &&
          AppConfig.googleMapsApiKey.isNotEmpty) {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=${AppConfig.googleMapsApiKey}');
        final response =
            await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final loc = data['results'][0]['geometry']['location'];
            final lat = double.parse(loc['lat'].toString());
            final lng = double.parse(loc['lng'].toString());
            _coordCache[address] = LatLng(lat, lng);
            return {'lat': lat, 'lng': lng};
          }
        }
      }

      // 2. FALLBACK TO NOMINATIM
      List<String> queries = [];
      if (address.contains(',')) {
        queries.add(address);
        queries.add(address.split(',')[0].trim());
      } else {
        queries.add(address);
        queries.add("$address, Tamil Nadu");
      }

      for (var q in queries) {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=1&countrycodes=in');

        final response = await http.get(url, headers: {
          'User-Agent': 'CurryApp_Geo_${DateTime.now().millisecondsSinceEpoch}'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          if (data.isNotEmpty) {
            final lat = double.parse(data[0]['lat']);
            final lng = double.parse(data[0]['lon']);
            _coordCache[address] = LatLng(lat, lng);
            return {'lat': lat, 'lng': lng};
          }
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
  }

  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0 || lat2 == 0) return 0.0;
    const double p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}
