import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

class AddressStore extends ChangeNotifier {
  static final AddressStore _instance = AddressStore._internal();
  factory AddressStore() => _instance;
  AddressStore._internal();

  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> get addresses => _addresses;

  void sync(List<Map<String, dynamic>> data) {
    _addresses = data;
    notifyListeners();
  }

  Future<void> saveAddress(Map<String, dynamic> address) async {
    final userId = SupabaseConfig.forcedUserId;
    if (userId == null) return;

    try {
      await SupabaseConfig.client.from('user_addresses').upsert({
        ...address,
        'user_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      // Realtime hub will trigger the sync
    } catch (e) {
      debugPrint("Error saving address: $e");
    }
  }

  void clear() {
    _addresses = [];
    notifyListeners();
  }
}
