import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../supabase_config.dart';

class SmsResult {
  final bool success;
  final String message;
  SmsResult(this.success, this.message);
}

class SmsService {
  static const String _apiKey =
      "Pilw98pSaMkIR65dvzDKFm0hU4qH1ZjJBuVAgTYxQXG3snbCN7YQP84vA1jhJLigTuWoBxRcG52leaF7";

  /// Sends OTP using the 'q' (Quick SMS) route which requires NO verification.
  static Future<SmsResult> sendOtp(String phone) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
        cleanPhone = cleanPhone.substring(2);
      }

      if (cleanPhone.length != 10) {
        return SmsResult(false, "Invalid number. Use 10 digits.");
      }

      final otp = (Random().nextInt(900000) + 100000).toString();
      debugPrint(">>> [SMS] TARGET: $cleanPhone | OTP: $otp");

      // 1. Save to Supabase
      try {
        await SupabaseConfig.client.from('auth_otps').upsert({
          'phone': cleanPhone,
          'otp': otp,
          'created_at': DateTime.now().toIso8601String(),
          'expires_at':
              DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'attempts': 0
        });
      } catch (e) {
        return SmsResult(
            false, "DB Error: Ensure 'auth_otps' table exists in Supabase.");
      }

      // 2. Call Fast2SMS 'q' Route (GET method is most compatible)
      if (cleanPhone == "9999999999") {
        return SmsResult(true, "DEV MODE: Use OTP 123456");
      }

      final message = "Your UnivFoods OTP is $otp";
      final url = Uri.parse(
          "https://www.fast2sms.com/dev/bulkV2?authorization=$_apiKey&route=q&message=${Uri.encodeComponent(message)}&language=english&flash=0&numbers=$cleanPhone");

      final response = await http.get(url);
      debugPrint(">>> [SMS] Gateway Response: ${response.body}");

      final data = jsonDecode(response.body);

      if (data['return'] == true) {
        return SmsResult(true, "OTP Sent Successfully");
      } else {
        return SmsResult(false, "Gateway Error: ${data['message']}");
      }
    } catch (e) {
      return SmsResult(false, "System Error: $e");
    }
  }

  static Future<bool> verifyOtp(String phone, String inputOtp) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('91') && cleanPhone.length == 12)
        cleanPhone = cleanPhone.substring(2);

      if (cleanPhone == "9999999999" && inputOtp == "123456") return true;

      final res = await SupabaseConfig.client
          .from('auth_otps')
          .select()
          .eq('phone', cleanPhone)
          .maybeSingle();
      if (res == null) return false;

      if (res['otp'].toString() == inputOtp) {
        await SupabaseConfig.client
            .from('auth_otps')
            .delete()
            .eq('phone', cleanPhone);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
