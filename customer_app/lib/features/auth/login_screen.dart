import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;

  void _handlePhoneLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid Phone Number")));
      return;
    }

    setState(() => _isLoading = true);

    // 🚀 Dev Bypass for Testing
    if (phone.contains("99999")) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("DEV MODE: Use OTP 123456")));
      return;
    }

    try {
      await SupabaseConfig.client.auth.signInWithOtp(
        phone: '+91$phone',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP Sent Successfully!")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length < 6) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        phone: '+91$phone',
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        final profile = await SupabaseConfig.syncUser(phone);
        if (mounted) {
          if (profile != null && profile['has_address'] == false) {
            Navigator.pushReplacementNamed(context, '/add-address');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Verification Failed: $e")));
      }
    }
  }

  void _googleLogin() async {
    // Note: Google login is secondary but should also trigger syncUser
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Google login coming soon. Use Phone OTP.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative Top Graphic
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                    ProTheme.primary.withOpacity(0.1),
                    Colors.white
                  ])),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  // Hero Section
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: ProTheme.shadow),
                      child: const Icon(Icons.delivery_dining,
                          size: 48, color: ProTheme.primary),
                    ).animate().scale(delay: 200.ms),
                  ),

                  const SizedBox(height: 40),

                  Text("Welcome", style: ProTheme.header.copyWith(fontSize: 32))
                      .animate()
                      .fadeIn()
                      .moveX(begin: -20),
                  const SizedBox(height: 8),
                  Text("Enter your phone number to continue",
                          style: ProTheme.body)
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .moveX(begin: -20),

                  const SizedBox(height: 32),

                  if (!_otpSent) ...[
                    // Phone Input (Simplified UI)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                          color: ProTheme.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: ProTheme.gray.withOpacity(0.2))),
                      child: Row(
                        children: [
                          Text("🇮🇳 +91",
                              style: ProTheme.title.copyWith(fontSize: 16)),
                          const SizedBox(width: 12),
                          Container(
                              width: 1,
                              height: 24,
                              color: ProTheme.gray.withOpacity(0.3)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: ProTheme.title.copyWith(fontSize: 18),
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "98765 43210"),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePhoneLogin,
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                ProTheme.primary, // Explicitly set color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)))
                            : const Text("Continue",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _googleLogin,
                        style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(
                                color: ProTheme.gray.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Simple Google 'G' icon placeholder
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Text("G",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Text("Continue with Google",
                                style: ProTheme.title.copyWith(fontSize: 16))
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // OTP Section
                    TextField(
                        controller: _otpController,
                        textAlign: TextAlign.center,
                        style: ProTheme.header
                            .copyWith(letterSpacing: 8, fontSize: 24),
                        decoration: InputDecoration(
                            hintText: "Enter OTP",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)))),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: ProTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)))
                            : const Text("Verify OTP",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
