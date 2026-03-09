import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

class PaymentStore extends ChangeNotifier {
  static final PaymentStore _instance = PaymentStore._internal();
  factory PaymentStore() => _instance;
  PaymentStore._internal();

  List<Map<String, dynamic>> _methods = [];
  List<Map<String, dynamic>> get methods => _methods;

  void sync(List<Map<String, dynamic>> newMethods) {
    _methods = newMethods;
    notifyListeners();
  }

  Future<void> addMethod(Map<String, dynamic> method) async {
    final userId = SupabaseConfig.forcedUserId;
    if (userId == null) return;

    try {
      await SupabaseConfig.client.from('user_payment_methods').insert({
        ...method,
        'user_id': userId,
      });
      // Realtime subscription will handle the UI update
    } catch (e) {
      debugPrint("Error adding payment method: $e");
    }
  }

  Future<void> removeMethod(String id) async {
    try {
      await SupabaseConfig.client
          .from('user_payment_methods')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint("Error removing payment method: $e");
    }
  }

  void clear() {
    _methods = [];
    notifyListeners();
  }
}
