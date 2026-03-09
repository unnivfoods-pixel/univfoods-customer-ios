import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  }

  Future<void> _checkRequiredConsents() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      widget.onAccepted();
      return;
    }

    try {
      final docsResponse = await SupabaseConfig.client
          .from('legal_documents')
          .select()
          .eq('is_active', true)
          .eq('requires_acceptance', true)
          .or('role.eq.DELIVERY_PARTNER,role.eq.ALL');

      final List<Map<String, dynamic>> allDocs =
          List<Map<String, dynamic>>.from(docsResponse);

      final acceptanceResponse = await SupabaseConfig.client
          .from('legal_acceptance')
          .select()
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> accepted =
          List<Map<String, dynamic>>.from(acceptanceResponse);

      final pending = allDocs.where((doc) {
        final hasAccepted = accepted.any((a) =>
            a['document_id'] == doc['id'] &&
            a['accepted_version'] == doc['version']);
        return !hasAccepted;
      }).toList();

      if (pending.isEmpty) {
        widget.onAccepted();
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
      // FAIL OPEN: If legal check fails, let the rider proceed
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
        'ip_address': 'delivery-app',
        'user_agent': 'flush-delivery-app'
      });

      if (_currentIndex < _pendingDocs.length - 1) {
        setState(() => _currentIndex++);
      } else {
        widget.onAccepted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: ProTheme.bg,
          body: const Center(
              child: CircularProgressIndicator(color: ProTheme.primary)));
    }

    if (_pendingDocs.isEmpty) {
      return Scaffold(
        backgroundColor: ProTheme.bg,
        body: const Center(
            child: CircularProgressIndicator(color: ProTheme.primary)),
      );
    }

    final doc = _pendingDocs[_currentIndex];

    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ProTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.shieldCheck,
                        size: 40, color: ProTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text("Operational Protocol",
                      style: ProTheme.header.copyWith(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                      "Review and authorize the fleet deployment terms to proceed to the Dispatch Terminal.",
                      textAlign: TextAlign.center,
                      style: ProTheme.body),
                ],
              ),
            ),
            if (_pendingDocs.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _pendingDocs.length,
                        backgroundColor: ProTheme.slate.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            ProTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        "DOCUMENT ${_currentIndex + 1} OF ${_pendingDocs.length}",
                        style: ProTheme.label.copyWith(fontSize: 8)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: ProTheme.softShadow,
                    border: Border.all(color: ProTheme.dark.withOpacity(0.05))),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title'],
                          style: ProTheme.title.copyWith(fontSize: 18)),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Html(
                        data: doc['content'],
                        style: {
                          "body": Style(
                            fontSize: FontSize(14),
                            color: ProTheme.dark.withOpacity(0.8),
                            lineHeight: const LineHeight(1.6),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _acceptCurrentDoc,
                  style: ProTheme.ctaButton,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "I ACCEPT & AUTHORIZE",
                        style: ProTheme.button
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.arrowRight, size: 18),
                    ],
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
