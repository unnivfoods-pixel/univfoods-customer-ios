import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RazorpayService {
  late Razorpay _razorpay;
  final Function(PaymentSuccessResponse) onSuccess;
  final Function(PaymentFailureResponse) onFailure;
  final Function(ExternalWalletResponse) onExternalWallet;

  // CREDENTIALS
  static const String keyId = 'rzp_live_S8qNl28ri7qDTp';
  // Secret is usually not used on client side for standard checkout,
  // but kept on server. However, some implementations might use it.
  // For standard Flutter checkout, only Key ID is needed.

  RazorpayService({
    required this.onSuccess,
    required this.onFailure,
    required this.onExternalWallet,
  }) {
    // Razorpay native plugin ONLY works on Android/iOS.
    // Calling it on Windows/Web causes a hard crash or hang.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        _razorpay = Razorpay();
        _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
        _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
        _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
      } catch (e) {
        debugPrint('Razorpay Native Load Error: $e');
      }
    } else {
      debugPrint("Razorpay bypassed: Non-mobile platform detected.");
    }
  }

  void openCheckout({
    required double amount, // in Rupees
    required String description,
    required String email,
    required String phone,
    String? method, // Optional: 'upi', 'card', etc.
    String? orderId, // Optional: if you generate order_id from backend
  }) {
    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // in paise
      'name': 'UNIV Foods',
      'description': description,
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': phone,
        'email': email,
      },
      'external': {
        'wallets': ['paytm', 'phonepe']
      }
    };

    if (method != null && method.isNotEmpty) {
      (options['prefill'] as Map)['method'] = method.toLowerCase();
    }

    if (orderId != null) {
      options['order_id'] = orderId;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Razorpay Open Error: $e');
      onFailure(PaymentFailureResponse(
          2, "Payment gateway unavailable on this platform.", {}));
    }
  }

  void dispose() {
    try {
      _razorpay.clear();
    } catch (_) {}
  }
}
