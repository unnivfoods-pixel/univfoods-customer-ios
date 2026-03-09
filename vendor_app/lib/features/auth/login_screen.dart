import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import '../../core/navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter email and password')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null && mounted) {
        await SupabaseConfig.saveSession(res.session!.user.id);
        vendorNavigatorKey.currentState?.pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      debugPrint("Login error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: Stack(
        children: [
          // PRO Background: Animated Gradient Orbs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  ProTheme.primary.withOpacity(0.3),
                  ProTheme.primary.withOpacity(0)
                ]),
                shape: BoxShape.circle,
              ),
            ).animate().shimmer(duration: 3.seconds),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PRO Brand Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: ProTheme.shadow),
                        child: const Icon(Icons.restaurant_menu_rounded,
                            size: 72, color: ProTheme.secondary),
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 40),
                    Text('Vendor Portal',
                            textAlign: TextAlign.center, style: ProTheme.header)
                        .animate()
                        .fadeIn(delay: 200.ms),
                    const SizedBox(height: 12),
                    Text('Manage orders, menu & growth',
                            textAlign: TextAlign.center,
                            style: ProTheme.body.copyWith(fontSize: 16))
                        .animate()
                        .fadeIn(delay: 300.ms),

                    const SizedBox(height: 54),

                    // Inputs
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: ProTheme.inputDecor(
                          'Email Address', Icons.alternate_email),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideX(begin: 0.1, end: 0),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: ProTheme.inputDecor(
                              'Account Password', Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: ProTheme.gray,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 500.ms)
                        .slideX(begin: 0.1, end: 0),

                    const SizedBox(height: 32),

                    // Login Button
                    Material(
                      color: ProTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isLoading ? null : _handleLogin,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 64,
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Login to Dashboard',
                                        style: ProTheme.button.copyWith(
                                            fontSize: 18, color: Colors.white)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white),
                                  ],
                                ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms).moveY(begin: 20, end: 0),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: ProTheme.gray),
                          children: [
                            TextSpan(
                              text: "Apply for Access",
                              style: TextStyle(
                                  color: ProTheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          debugPrint(">>> ACTION: Vendor Demo Mode");
                          // Link to Royal Curry House demo identity
                          await SupabaseConfig.saveSession(
                              "00000000-0000-0000-0000-000000000001");
                          vendorNavigatorKey.currentState
                              ?.pushReplacementNamed('/dashboard');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Enter Demo Mode',
                              textAlign: TextAlign.center,
                              style: ProTheme.label.copyWith(
                                  color: ProTheme.secondary,
                                  decoration: TextDecoration.underline)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text('UNIV © 2026 • Vendor v4.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ProTheme.gray, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
