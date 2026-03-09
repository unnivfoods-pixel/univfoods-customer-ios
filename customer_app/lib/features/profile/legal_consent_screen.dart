import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalConsentScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const LegalConsentScreen({super.key, required this.onAccepted});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _pendingDocs = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkRequiredConsents();
    // Auto-timeout for legal check to prevent white screen hang
    Future.delayed(const Duration(milliseconds: 2500)).then((_) {
      if (mounted && _loading) {
        widget.onAccepted();
      }
    });
  }

  Future<void> _checkRequiredConsents() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      widget.onAccepted(); // Guest mode skips for now
      return;
    }

    try {
      // 1. Fetch Active Policies for 'CUSTOMER' & 'ALL'
      final docsResponse = await SupabaseConfig.client
          .from('legal_documents')
          .select()
          .eq('is_active', true)
          .eq('requires_acceptance', true)
          .or('role.eq.CUSTOMER,role.eq.ALL');

      final List<Map<String, dynamic>> allDocs =
          List<Map<String, dynamic>>.from(docsResponse);

      // 2. Fetch User's Accepted Versions
      final acceptanceResponse = await SupabaseConfig.client
          .from('legal_acceptance')
          .select()
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> accepted =
          List<Map<String, dynamic>>.from(acceptanceResponse);

      // 3. Filter: Which ACTIVE docs have NOT been accepted (matching ID + Version)?
      final pending = allDocs.where((doc) {
        final hasAccepted = accepted.any((a) =>
            a['document_id'] == doc['id'] &&
            a['accepted_version'] == doc['version']);
        return !hasAccepted;
      }).toList();

      if (pending.isEmpty) {
        widget.onAccepted(); // All good
      } else {
        if (mounted) {
          setState(() {
            _pendingDocs = pending;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Legal Check Error: $e");
      // Fail open to prevent white-screen hang for users
      if (mounted) {
        widget.onAccepted();
      }
    }
  }

  Future<void> _acceptCurrentDoc() async {
    final doc = _pendingDocs[_currentIndex];
    final user = SupabaseConfig.client.auth.currentUser;

    if (user == null) return;

    try {
      await SupabaseConfig.client.from('legal_acceptance').insert({
        'user_id': user.id,
        'document_id': doc['id'],
        'accepted_version': doc['version'],
        'ip_address': 'mobile-app', // In real app, get IP
        'user_agent': 'flush-customer-app'
      });

      if (_currentIndex < _pendingDocs.length - 1) {
        setState(() => _currentIndex++);
      } else {
        widget.onAccepted(); // Done
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: ProTheme.primary),
              const SizedBox(height: 24),
              const Text("Reviewing Legal Policies...",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              // Fallback button if stuck
              TextButton(
                  onPressed: () => widget.onAccepted(),
                  child: const Text("Skip & Continue",
                      style: TextStyle(color: Colors.grey)))
            ],
          ),
        ),
      );
    }

    if (_pendingDocs.isEmpty)
      return const SizedBox(); // Should have navigated away

    final doc = _pendingDocs[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 48, color: ProTheme.primary),
                  const SizedBox(height: 16),
                  Text("Update to Legal Terms",
                      style: ProTheme.header.copyWith(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text("Please review and accept changes to continue.",
                      style: ProTheme.body.copyWith(color: ProTheme.gray)),
                ],
              ),
            ),

            // Progress
            if (_pendingDocs.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _pendingDocs.length,
                  backgroundColor: ProTheme.bg,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(ProTheme.primary),
                ),
              ),

            const SizedBox(height: 20),

            // Scrollable Content
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: ProTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title'], style: ProTheme.title),
                      const Divider(),
                      // Simple Markdown-ish or HTML Render
                      Html(data: doc['content']),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Action
            Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: ProTheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    debugPrint(">>> ACTION: Legal Accept Tap");
                    _acceptCurrentDoc();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      "I Accept (${_currentIndex + 1}/${_pendingDocs.length})",
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
          ],
        ).animate().fadeIn(),
      ),
    );
  }
}
