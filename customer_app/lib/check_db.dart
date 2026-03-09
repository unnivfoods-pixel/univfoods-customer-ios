import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/core/supabase_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  try {
    final res = await SupabaseConfig.client.from('auth_otps').select().limit(1);
    print("✅ auth_otps table exists!");
  } catch (e) {
    print("❌ auth_otps table MISSING or error: $e");
  }
}
