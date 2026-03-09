import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class LocationStore extends ChangeNotifier {
  static final LocationStore _instance = LocationStore._internal();
  factory LocationStore() => _instance;
  LocationStore._internal();

  LatLng? _selectedLocation;
  String _selectedAddress = "Finding location...";
  String _selectedLabel = "Current Location";
  String _houseNumber = "";
  String _pincode = "";
  String _phone = "";
  bool _initialized = false;

  LatLng? get selectedLocation => _selectedLocation;
  String get selectedAddress => _selectedAddress;
  String get selectedLabel => _selectedLabel;
  String get houseNumber => _houseNumber;
  String get pincode => _pincode;
  String get phone => _phone;
  bool get isInitialized => _initialized;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('selected_lat');
    final lng = prefs.getDouble('selected_lng');
    final addr = prefs.getString('selected_address');
    final label = prefs.getString('selected_label');
    _houseNumber = prefs.getString('selected_house_number') ?? "";
    _pincode = prefs.getString('selected_pincode') ?? "";
    _phone = prefs.getString('selected_phone') ?? "";

    if (lat != null && lng != null) {
      _selectedLocation = LatLng(lat, lng);
      _selectedAddress = addr ?? "Saved Location";
      _selectedLabel = label ?? "Address";
      _initialized = true;
      notifyListeners();

      // 🚀 AUTO-REPAIR: If saved address is just coordinates, try to get a real one
      if (_selectedAddress.contains('Tracked Location') ||
          _selectedAddress.length < 5) {
        debugPrint(">>> [LOCATION] Repairing generic address string...");
        LocationService.getAddressFromLatLng(lat, lng).then((fresh) {
          if (fresh.isNotEmpty && !fresh.contains('Tracked Location')) {
            updateLocation(_selectedLocation!, fresh, _selectedLabel);
          }
        });
      }
    } else {
      // Background GPS fallback if nothing on disk
      try {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          final freshAddr = await LocationService.getAddressFromLatLng(
              pos.latitude, pos.longitude);
          _selectedLocation = LatLng(pos.latitude, pos.longitude);
          _selectedAddress = freshAddr;
          _selectedLabel = "Current Location";

          await prefs.setDouble('selected_lat', pos.latitude);
          await prefs.setDouble('selected_lng', pos.longitude);
          await prefs.setString('selected_address', freshAddr);
          await prefs.setString('selected_label', "Current Location");
        }
      } catch (e) {
        debugPrint("LocationStore load Error: $e");
      } finally {
        _initialized = true;
        notifyListeners();
      }
    }
  }

  Future<void> updateLocation(LatLng loc, String address, String label,
      {String house = "", String pincode = "", String phone = ""}) async {
    _selectedLocation = loc;
    _selectedAddress = address;
    _selectedLabel = label;
    _houseNumber = house;
    _pincode = pincode;
    _phone = phone;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('selected_lat', loc.latitude);
    await prefs.setDouble('selected_lng', loc.longitude);
    await prefs.setString('selected_address', address);
    await prefs.setString('selected_label', label);
    await prefs.setString('selected_house_number', _houseNumber);
    await prefs.setString('selected_pincode', _pincode);
    await prefs.setString('selected_phone', _phone);
  }
}
