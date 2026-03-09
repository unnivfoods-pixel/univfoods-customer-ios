import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields are required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create Auth User
      final res = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // 2. Create Registration Request
        // IMPORTANT: Use the unified 'registration_requests' table
        await SupabaseConfig.client.from('registration_requests').insert({
          'owner_id': res.user!.id,
          'name': name,
          'email': email,
          'phone': phone,
          'type': 'rider',
          'address': 'Mobile App Submission',
          'status': 'pending'
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: ProTheme.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text("Enlistment Logged",
                  style: ProTheme.header.copyWith(fontSize: 22)),
              content: Text(
                  "Your profile has been transmitted to Headquarters. \n\nPending Admin Commissioning. You will be cleared for dispatch once authorized.",
                  style: ProTheme.body),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ProTheme.ctaButton,
                  child: const Text("RETURN TO BASE (LOGIN)"),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Registration error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deployment Failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ProTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.two_wheeler_rounded,
                    size: 56, color: ProTheme.primary),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            ),

            const SizedBox(height: 32),
            Text('Join the Fleet',
                    textAlign: TextAlign.center,
                    style: ProTheme.header.copyWith(fontSize: 32))
                .animate()
                .fadeIn()
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 8),
            Text('Enlist as a delivery partner and earn on every mission.',
                    textAlign: TextAlign.center, style: ProTheme.body)
                .animate()
                .fadeIn(delay: 200.ms),

            const SizedBox(height: 48),

            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration:
                  ProTheme.inputDecor('Full Name', Icons.person_outline),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration:
                  ProTheme.inputDecor('Email Address', Icons.alternate_email),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: ProTheme.inputDecor(
                  'Phone Number', Icons.phone_android_rounded),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration:
                  ProTheme.inputDecor('Create Password', Icons.lock_outline)
                      .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: 48),

            SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ProTheme.ctaButton,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT APPLICATION',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
                .animate()
                .fadeIn(delay: 700.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

            const SizedBox(height: 24),
            const Text('UNIV HQ • Recruitment Terminal',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
