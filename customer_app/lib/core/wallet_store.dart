import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

class WalletStore extends ChangeNotifier {
  static final WalletStore _instance = WalletStore._internal();
  factory WalletStore() => _instance;
  WalletStore._internal();

  double _balance = 0.0;

  double get balance => _balance;

  Future<void> fetchBalance() async {
    final uid = SupabaseConfig.forcedUserId ??
        SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await SupabaseConfig.client
          .from('wallets')
          .select('balance')
          .eq('user_id', uid)
          .maybeSingle();
      if (res != null) {
        updateBalance(double.tryParse(res['balance'].toString()) ?? 0.0);
      }
    } catch (e) {
      debugPrint("Fetch Wallet Error: $e");
    }
  }

  void updateBalance(double newBalance) {
    if (_balance != newBalance) {
      _balance = newBalance;
      notifyListeners();
    }
  }

  void clear() {
    _balance = 0.0;
    notifyListeners();
  }
}
