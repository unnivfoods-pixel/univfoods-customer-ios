import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';

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
          .or('role.eq.VENDOR,role.eq.ALL')
          .timeout(const Duration(seconds: 5));

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
      // FAIL OPEN: If legal check fails (timeout or missing table), let the vendor proceed
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
        'ip_address': 'vendor-app',
        'user_agent': 'flush-vendor-app'
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
      return const Scaffold(
          backgroundColor: ProTheme.bg,
          body: Center(child: CircularProgressIndicator()));
    }

    if (_pendingDocs.isEmpty) return const SizedBox();

    final doc = _pendingDocs[_currentIndex];

    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ProTheme.dark,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.security_rounded,
                        size: 40, color: ProTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text("Boutique Portal",
                      style: ProTheme.header.copyWith(fontSize: 26)),
                  const SizedBox(height: 8),
                  Text("IDENTITY & COMPLIANCE VERIFICATION",
                      style: ProTheme.label
                          .copyWith(letterSpacing: 2, fontSize: 10)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: ProTheme.cardDecor,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        color: ProTheme.dark.withOpacity(0.02),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(doc['title'],
                                    style:
                                        ProTheme.title.copyWith(fontSize: 16))),
                            Text("v${doc['version']}", style: ProTheme.label),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Html(
                            data: doc['content'],
                            style: {
                              "body": Style(
                                color: ProTheme.gray,
                                fontSize: FontSize(14),
                                lineHeight: LineHeight.em(1.6),
                              ),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  if (_pendingDocs.length > 1) ...[
                    Text("PROTOCOL ${_currentIndex + 1}/${_pendingDocs.length}",
                        style: ProTheme.label
                            .copyWith(fontSize: 10, color: ProTheme.gray)),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acceptCurrentDoc,
                      style: ProTheme.secondaryButton,
                      child: Text("AUTHENTICATE & PROCEED",
                          style: ProTheme.button),
                    ),
                  ),
                ],
              ),
            )
          ],
        ).animate().fadeIn(),
      ),
    );
  }
}
