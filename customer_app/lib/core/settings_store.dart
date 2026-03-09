import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

class SettingsStore extends ChangeNotifier {
  static final SettingsStore _instance = SettingsStore._internal();
  factory SettingsStore() => _instance;
  SettingsStore._internal();

  Map<String, dynamic> _settings = {
    'order_updates': true,
    'promotions': true,
    'system_alerts': true,
    'push_notifications': true,
    'email_digest': false,
    'sms_updates': false,
  };

  Map<String, dynamic> get settings => _settings;

  void sync(Map<String, dynamic> newSettings) {
    _settings = {..._settings, ...newSettings};
    notifyListeners();
  }

  Future<void> updateSetting(String key, bool value) async {
    final userId = SupabaseConfig.forcedUserId;
    if (userId == null) return;

    // Optimistic Update
    _settings[key] = value;
    notifyListeners();

    try {
      await SupabaseConfig.client.from('user_settings').upsert({
        'user_id': userId,
        key: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error updating setting $key: $e");
      // Rollback on error? Maybe just log for now.
    }
  }

  void clear() {
    _settings = {
      'order_updates': true,
      'promotions': true,
      'system_alerts': true,
      'push_notifications': true,
      'email_digest': false,
      'sms_updates': false,
    };
    notifyListeners();
  }
}
