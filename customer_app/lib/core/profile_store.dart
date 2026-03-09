import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

class ProfileStore extends ChangeNotifier {
  static final ProfileStore _instance = ProfileStore._internal();
  factory ProfileStore() => _instance;
  ProfileStore._internal();

  Map<String, dynamic>? _profile;

  Map<String, dynamic>? get profile => _profile;
  bool get codAllowed => _profile?['cod_allowed'] ?? true;
  String get accountStatus => _profile?['account_status'] ?? 'Active';

  void sync(Map<String, dynamic> data) {
    _profile = data;
    notifyListeners();
  }

  void updateField(String key, dynamic value) {
    if (_profile != null) {
      _profile![key] = value;
      notifyListeners();
    }
  }

  Future<void> fetchProfile(String uid) async {
    try {
      final res = await SupabaseConfig.client
          .from('customer_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (res != null) {
        sync(res);
      }
    } catch (e) {
      debugPrint("Fetch Profile Error: $e");
    }
  }

  void clear() {
    _profile = null;
    notifyListeners();
  }
}
