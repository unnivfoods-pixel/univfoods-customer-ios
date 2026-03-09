import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _vehicleType = 'Bike';
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Sign up user in Auth
      final authRes = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );

      if (authRes.user == null) throw Exception("Signup failed");

      // 2. Insert into registrations table for Admin Approval
      await SupabaseConfig.client.from('registrations').insert({
        'name': name,
        'email': email,
        'phone': phone,
        'type': 'rider',
        'status': 'pending',
        'details': {
          'vehicle_type': _vehicleType,
          'user_id': authRes.user!.id,
        }
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Registration Submitted"),
            content: const Text(
                "Your application is pending admin approval. You will be able to log in once approved."),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ProTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.two_wheeler, size: 60, color: ProTheme.primary)
                .animate()
                .scale(),
            const SizedBox(height: 24),
            Text('Join the Fleet', style: ProTheme.header),
            const SizedBox(height: 8),
            Text('Apply to become a rider', style: ProTheme.body),
            const SizedBox(height: 32),
            _buildInput(Icons.person_outline, "Full Name", _nameController),
            const SizedBox(height: 16),
            _buildInput(
                Icons.email_outlined, "Email Address", _emailController),
            const SizedBox(height: 16),
            _buildInput(Icons.phone_outlined, "Phone Number", _phoneController),
            const SizedBox(height: 16),
            _buildInput(Icons.lock_outline, "Password", _passwordController,
                obscure: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ProTheme.softShadow,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vehicleType,
                  isExpanded: true,
                  items: ['Bike', 'Scooter', 'Electric Bike', 'Cycle']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setState(() => _vehicleType = val!),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ProTheme.ctaButton,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Application"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
      IconData icon, String hint, TextEditingController controller,
      {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ProTheme.softShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.grey),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
