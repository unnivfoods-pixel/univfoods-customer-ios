import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import '../../core/services/sms_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({super.key});

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // 🧪 DEVELOPMENT BYPASS: Skip real SMS for faster testing
  bool get _isDevBypass => _phoneController.text.contains("99999");

  Future<void> _sendOTP({StateSetter? updateUi}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    final formattedPhone =
        phone.startsWith('+') ? phone : '+91${phone.replaceAll(' ', '')}';

    void update(VoidCallback fn) {
      if (updateUi != null) {
        updateUi(fn);
      } else if (mounted) {
        setState(fn);
      }
    }

    update(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 🛰️ CALL FAST2SMS SYSTEM (No Chrome, No reCAPTCHA)
      final result = await SmsService.sendOtp(formattedPhone);

      if (result.success) {
        update(() {
          _otpSent = true;
          _isLoading = false;
          _verificationId = "f2s_active"; // Marker for Fast2SMS flow
        });
        debugPrint(">>> [OTP] Fast2SMS Dispatched Successfully");
      } else {
        update(() {
          _isLoading = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      update(() {
        _isLoading = false;
        _errorMessage = "System error: $e";
      });
    }
  }

  Future<void> _verifyOTP({StateSetter? updateUi}) async {
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.trim();
    final formattedPhone =
        phone.startsWith('+') ? phone : '+91${phone.replaceAll(' ', '')}';

    void update(VoidCallback fn) {
      if (updateUi != null) {
        updateUi(fn);
      } else if (mounted) {
        setState(fn);
      }
    }

    update(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 🛰️ VERIFY LOCALLY (Fast2SMS / Supabase Flow)
      final isValid = await SmsService.verifyOtp(formattedPhone, otp);

      if (isValid) {
        debugPrint(">>> [OTP] Direct Verification SUCCESS");

        // 🆔 RECOVER OLD ID: This restores your order history!
        final String recoveredUid =
            await SupabaseConfig.findOrCreateUid(formattedPhone);

        // 🚀 SAVE SESSION IMMEDIATELY (Before Navigation)
        await SupabaseConfig.saveSession(recoveredUid);
        await SupabaseConfig.syncUser(formattedPhone, manualUid: recoveredUid);

        // 🚀 INSTANT NAVIGATION
        if (mounted) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        update(() {
          _isLoading = false;
          _errorMessage = "Invalid OTP. Please try again.";
        });
      }
    } catch (e) {
      update(() {
        _isLoading = false;
        _errorMessage = "Verification error: $e";
      });
    }
  }

  Future<void> _signInWithCredential(fb.PhoneAuthCredential credential,
      {StateSetter? updateUi}) async {
    void update(VoidCallback fn) {
      if (updateUi != null) {
        updateUi(fn);
      } else if (mounted) {
        setState(fn);
      }
    }

    try {
      update(() => _isLoading = true);
      debugPrint(">>> [OTP FLOW] Verifying Credential with Firebase...");

      final userCredential =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCredential.user;

      if (fbUser != null) {
        debugPrint(">>> [OTP FLOW] Firebase Verified! ID: ${fbUser.uid}");
        final String phone = fbUser.phoneNumber ?? _phoneController.text.trim();

        // 🚀 SAVE SESSION IMMEDIATELY (Before Navigation)
        await SupabaseConfig.saveSession(fbUser.uid);
        await SupabaseConfig.syncUser(phone, manualUid: fbUser.uid);
        await SupabaseConfig.bootstrap();

        if (mounted) {
          debugPrint(">>> [OTP FLOW] Sync Complete. Going Home.");
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      debugPrint(">>> [OTP FLOW] CRITICAL ERROR: $e");
      update(() {
        _isLoading = false;
        _errorMessage = "Verification failed. Check your connection.";
      });
    }
  }

  void _showLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 32,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _otpSent ? "Verification" : "Login",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? "Enter the 6-digit code sent to your number"
                        : "Enter your phone number to proceed",
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_otpSent) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              "+91",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          hintText: "Phone Number",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    // OTP Section - High Visibility
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: ProTheme.primary,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "------",
                        hintStyle: TextStyle(color: Colors.grey[300]),
                        filled: true,
                        fillColor: ProTheme.primary.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _otpSent = false;
                              _otpController.clear();
                              _errorMessage = null;
                            });
                          },
                          child: Text("Change Number",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600])),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => _sendOTP(updateUi: setSheetState),
                          child: Text("Resend Code",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ProTheme.primary)),
                        ),
                      ],
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Material(
                    color: ProTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              debugPrint(">>> ACTION: Login/Verify Sheet Tap");
                              if (!_otpSent) {
                                final phone = _phoneController.text.trim();
                                if (phone.length < 10) {
                                  setSheetState(() => _errorMessage =
                                      "Please enter a valid 10-digit phone number");
                                  return;
                                }
                                await _sendOTP(updateUi: setSheetState);
                              } else {
                                if (_otpController.text.length < 6) {
                                  setSheetState(() => _errorMessage =
                                      "Please enter the 6-digit code");
                                  return;
                                }
                                await _verifyOTP(updateUi: setSheetState);
                              }
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : Text(
                                _otpSent ? "Verify & Login" : "Continue",
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          CachedNetworkImage(
            imageUrl:
                "https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800",
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.amber),
            errorWidget: (c, e, s) => Container(color: Colors.amber),
          ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    "Ordering Foods",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Welcome to",
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "UNIV Foods",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Best Curry, Biryani & more delivered to your doorstep in minutes.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Get Started Button
                  Material(
                    color: ProTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {
                        debugPrint(">>> ACTION: Login with Phone Tap");
                        _showLoginSheet();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        alignment: Alignment.center,
                        child: Text(
                          "Login with Phone",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
