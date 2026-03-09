import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates =
            data['routes'][0]['geometry']['coordinates'];

        return coordinates
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();
      }
    } catch (e) {
      print("Routing error: $e");
    }
    return [start, end]; // Fallback to straight line
  }

  static Future<List<LatLng>> getMultiPointRoute(List<LatLng> points) async {
    if (points.length < 2) return points;

    try {
      final coordsString =
          points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url =
          'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates =
            data['routes'][0]['geometry']['coordinates'];

        return coordinates
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();
      }
    } catch (e) {
      print("Multi-point routing error: $e");
    }
    return points; // Fallback
  }
}
