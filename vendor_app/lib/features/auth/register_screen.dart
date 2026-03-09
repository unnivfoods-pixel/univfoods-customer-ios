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
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, Email and Password are required')));
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
        // 2. Create Boutique Application
        await SupabaseConfig.client.from('vendor_applications').insert({
          'owner_id': res.user!.id,
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
          'status': 'PENDING'
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Application Submitted"),
              content: const Text(
                  "Your vendor account has been created and is pending Admin approval. You will be notified once active."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text("BACK TO LOGIN"),
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
            SnackBar(content: Text('Registration Failed: ${e.toString()}')));
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
            Text('Join the Fleet',
                    style: ProTheme.header.copyWith(fontSize: 32))
                .animate()
                .fadeIn()
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 8),
            Text('Launch your digital vendor kitchen in minutes',
                    style: ProTheme.body)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration:
                  ProTheme.inputDecor('Kitchen Name', Icons.storefront_rounded),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  ProTheme.inputDecor('Owner Email', Icons.alternate_email),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: ProTheme.inputDecor(
                  'Phone Number', Icons.phone_android_rounded),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: ProTheme.inputDecor(
                  'Business Address', Icons.location_on_outlined),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
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
            ).animate().fadeIn(delay: 700.ms),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SUBMIT APPLICATION',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
                .animate()
                .fadeIn(delay: 800.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}
