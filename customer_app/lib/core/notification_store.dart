import 'package:flutter/foundation.dart';

class NotificationStore extends ChangeNotifier {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    notifyListeners();
  }

  void setCount(int newCount) {
    _count = newCount;
    notifyListeners();
  }
}
