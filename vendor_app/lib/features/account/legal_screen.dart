import 'package:flutter/material.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:flutter_html/flutter_html.dart';

class LegalScreen extends StatefulWidget {
  final String targetAudience; // 'Customers', 'Vendors', 'Delivery'

  const LegalScreen({super.key, this.targetAudience = 'VENDOR'});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final res = await SupabaseConfig.client
          .from('legal_documents')
          .select()
          .eq('is_active', true)
          .or('role.eq.${widget.targetAudience},role.eq.ALL')
          .order('published_at', ascending: false);

      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching legal docs: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: const Text("Legal & Policies",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Text("No published policies available.",
                      style: TextStyle(color: Colors.grey[600])))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return _buildDocCard(doc);
                  },
                ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ProTheme.softShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ProTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(Icons.article_outlined, color: ProTheme.primary, size: 20),
        ),
        title: Text(doc['title'] ?? 'Policy',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Version ${doc['version'] ?? '1.0'}",
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LegalDetailScreen(doc: doc),
            ),
          );
        },
      ),
    );
  }
}

class LegalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> doc;

  const LegalDetailScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(doc['title'] ?? 'Policy',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc['type'] ?? '',
                style: TextStyle(
                    color: ProTheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
                "Last Updated: ${doc['published_at']?.split('T')[0] ?? doc['created_at']?.split('T')[0] ?? 'N/A'}",
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const Divider(height: 30),
            Html(
              data: doc['content'] ?? 'No content.',
              style: {
                "body": Style(
                  fontSize: FontSize(15.0),
                  lineHeight: LineHeight(1.6),
                  color: Colors.black87,
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
