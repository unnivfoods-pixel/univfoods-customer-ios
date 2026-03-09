import 'package:flutter/foundation.dart';

class TransactionStore extends ChangeNotifier {
  static final TransactionStore _instance = TransactionStore._internal();
  factory TransactionStore() => _instance;
  TransactionStore._internal();

  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _refunds = [];

  List<Map<String, dynamic>> get payments => _payments;
  List<Map<String, dynamic>> get refunds => _refunds;

  void syncPayments(List<Map<String, dynamic>> data) {
    _payments = data;
    notifyListeners();
  }

  void syncRefunds(List<Map<String, dynamic>> data) {
    _refunds = data;
    notifyListeners();
  }

  void updatePayment(Map<String, dynamic> payment) {
    final index = _payments.indexWhere((p) => p['id'] == payment['id']);
    if (index != -1) {
      _payments[index] = {..._payments[index], ...payment};
    } else {
      _payments.insert(0, payment);
    }
    notifyListeners();
  }

  void clear() {
    _payments = [];
    _refunds = [];
    notifyListeners();
  }
}
