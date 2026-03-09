import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';

// 1. BECOME A PARTNER SCREEN
class BecomePartnerScreen extends StatefulWidget {
  const BecomePartnerScreen({super.key});

  @override
  State<BecomePartnerScreen> createState() => _BecomePartnerScreenState();
}

class _BecomePartnerScreenState extends State<BecomePartnerScreen> {
  String _selectedType = 'vendor'; // 'vendor' or 'delivery'
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("BECOME A PARTNER",
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("JOIN THE MISSION",
                style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                "Help us deliver happiness across the city and grow your business.",
                style:
                    GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 32),

            // Type Selector
            Row(
              children: [
                _buildTypeCard('vendor', 'MEAL PARTNER', LucideIcons.utensils),
                const SizedBox(width: 16),
                _buildTypeCard('delivery', 'FLEET AGENT', LucideIcons.bike),
              ],
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _nameController,
              decoration: ProTheme.inputDecor(
                  _selectedType == 'vendor'
                      ? "Restaurant/Shop Name"
                      : "Full Name",
                  LucideIcons.user),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  ProTheme.inputDecor("Contact Phone", LucideIcons.phone),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  ProTheme.inputDecor("Email Address", LucideIcons.mail),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: ProTheme.inputDecor(
                  "Operational Area / City", LucideIcons.mapPin),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ProTheme.ctaButton,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("SUBMIT APPLICATION",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                  "Our team will review your details and contact you within 24-48 hours.",
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(String type, String label, IconData icon) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? ProTheme.primary.withOpacity(0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? ProTheme.primary : Colors.grey[200]!,
                width: 2),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? ProTheme.primary : Colors.grey[400],
                  size: 32),
              const SizedBox(height: 12),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: isSelected ? Colors.black : Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  void _submitApplication() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill required fields")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseConfig.client.from('registration_requests').insert({
        'type': _selectedType,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _locationController.text.trim(), // Map location to address
        'status': 'pending',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("APPLICATION RECEIVED",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            content: const Text(
                "Mission Control has received your coordinates. We will reach out shortly."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK")),
            ],
          ),
        ).then((_) => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Submission Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// 2. SAFETY EMERGENCY SCREEN
class SafetyEmergencyScreen extends StatefulWidget {
  const SafetyEmergencyScreen({super.key});

  @override
  State<SafetyEmergencyScreen> createState() => _SafetyEmergencyScreenState();
}

class _SafetyEmergencyScreenState extends State<SafetyEmergencyScreen> {
  String _issueType = "Medical Emergency";
  final _descController = TextEditingController();
  bool _isReporting = false;

  final List<String> _issues = [
    "Medical Emergency",
    "Accident",
    "Harassment",
    "Theft",
    "Rider Misbehavior",
    "Other Safety Concern"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("SAFETY EMERGENCY",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 16, color: Colors.red)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[100]!)),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldAlert,
                      color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                        "PRIORITY ALERT: This report goes directly to our Emergency Command Center for immediate action.",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.red[900])),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text("WHAT'S THE EMERGENCY?",
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _issueType,
              decoration:
                  ProTheme.inputDecor("Issue Type", LucideIcons.alertTriangle),
              items: _issues
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => setState(() => _issueType = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: ProTheme.inputDecor(
                  "Description of Issue", LucideIcons.clipboard),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isReporting ? null : _sendReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: Colors.red.withOpacity(0.4),
                ),
                child: _isReporting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("TRIGGER EMERGENCY ALERT",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                  "If this is a life-threatening situation, please call local emergency services immediately in addition to this report.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  void _sendReport() async {
    final userId = SupabaseConfig.forcedUserId ?? 'GUEST_USER';
    setState(() => _isReporting = true);
    try {
      await SupabaseConfig.client.from('support_tickets').insert({
        'user_id': userId == 'GUEST_USER' ? null : userId,
        'subject': "SAFETY ALERT: $_issueType",
        'description': _descController.text.trim(),
        'priority': 'EMERGENCY',
        'status': 'OPEN',
        'role': 'CUSTOMER'
      });

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            padding: const EdgeInsets.all(40),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle,
                    color: Colors.green, size: 64),
                const SizedBox(height: 24),
                Text("SIGNAL RECEIVED",
                    style: GoogleFonts.outfit(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text(
                    "Emergency protocols activated. An officer will ping your neural link shortly.",
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ProTheme.ctaButton,
                    child: const Text("CLOSE",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ).then((_) => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isReporting = false);
    }
  }
}

// 3. LEGAL POLICY SCREEN (Dynamic)
class LegalPolicyScreen extends StatelessWidget {
  final String type; // 'PRIVACY_POLICY', 'TERMS_CONDITIONS', etc.
  final String title;
  const LegalPolicyScreen({super.key, required this.type, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title.toUpperCase(),
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: SupabaseConfig.client
            .from('legal_documents')
            .select()
            .eq('type', type)
            .eq('is_active', true)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data;
          if (doc == null) {
            return const Center(
                child: Text("Policy not found. Contact Support."));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text("OFFICIAL DOCUMENT | V${doc['version']}",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.grey[500])),
                    const Spacer(),
                    Text(
                        "Last Updated: ${doc['published_at'] != null ? DateTime.parse(doc['published_at']).toString().split(' ')[0] : 'N/A'}",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.grey[400])),
                  ],
                ),
                const Divider(height: 48),
                Text(doc['content'] ?? 'No content available.',
                    style: GoogleFonts.inter(
                        fontSize: 14, height: 1.6, color: Colors.black87)),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}
