import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        // Status check will happen in RootWrapper (/)
        riderNavigatorKey.currentState?.pushReplacementNamed('/');
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
            right: -50,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ]),
                        child: const Icon(Icons.two_wheeler,
                            size: 60, color: ProTheme.primary),
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 32),
                    Text('Fleet Partner Login',
                            textAlign: TextAlign.center, style: ProTheme.header)
                        .animate()
                        .fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    Text('Deliver happiness, earn more.',
                            textAlign: TextAlign.center, style: ProTheme.body)
                        .animate()
                        .fadeIn(delay: 300.ms),

                    const SizedBox(height: 48),

                    // Inputs
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: ProTheme.title.copyWith(fontSize: 16),
                      decoration: ProTheme.inputDecor(
                          'Email Address', Icons.alternate_email),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: ProTheme.title.copyWith(fontSize: 16),
                      decoration: ProTheme.inputDecor(
                              'Account Password', Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),

                    // Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ProTheme.ctaButton,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Login to Fleet'),
                      ),
                    ).animate().fadeIn(delay: 600.ms).moveY(begin: 20, end: 0),

                    const SizedBox(height: 24),

                    // Registration Link
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: RichText(
                        text: TextSpan(
                          text: "New here? ",
                          style: ProTheme.body,
                          children: [
                            TextSpan(
                              text: "Apply to Join the Fleet",
                              style: TextStyle(
                                  color: ProTheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Demo Mode
                    TextButton(
                      onPressed: () async {
                        debugPrint(">>> ACTION: Rider Demo Mode Triggered");
                        await SupabaseConfig.saveSession("guest_rider_test");
                        riderNavigatorKey.currentState
                            ?.pushReplacementNamed('/dashboard');
                      },
                      child: Text('Skip for now (Demo)',
                          style: ProTheme.body.copyWith(
                              color: ProTheme.primary.withOpacity(0.5),
                              fontSize: 12)),
                    ),

                    const SizedBox(height: 40),
                    const Text('UNIV © 2026 • Rider v4.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 10)),
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
