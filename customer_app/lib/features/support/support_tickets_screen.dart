import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import 'support_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = "Order Delayed";
  bool _isCreating = false;

  final List<String> _types = [
    "Order Delayed",
    "Wrong Item",
    "Refund Issue",
    "Delivery Issue",
    "Other"
  ];

  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Support Tickets",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("Please login to see tickets"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from('support_tickets')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', user.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                final tickets = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCreateTicketCard(),
                    const SizedBox(height: 24),
                    if (tickets.isNotEmpty) ...[
                      Text("Your Recent Tickets",
                          style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...tickets.map((t) => _buildTicketItem(t)).toList(),
                    ] else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                            "No tickets found. Need help? Create one above."),
                      )),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCreateTicketCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Raise a New Ticket",
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration:
                ProTheme.inputDecor("Issue Type", Icons.category_outlined),
            items: _types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            decoration: ProTheme.inputDecor("Subject", Icons.subject),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration:
                ProTheme.inputDecor("Description", Icons.description_outlined),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createTicket,
              style: ProTheme.ctaButton,
              child: _isCreating
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("SUBMIT TICKET",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  void _createTicket() async {
    final sub = _subjectController.text.trim();
    final desc = _descController.text.trim();
    if (sub.isEmpty || desc.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      await SupabaseConfig.client.from('support_tickets').insert({
        'user_id': user?.id,
        'subject': sub,
        'description': desc,
        'context_tag': 'CHAT',
        'role': 'CUSTOMER',
        'status': 'OPEN',
        'priority': 'NORMAL',
      });
      _subjectController.clear();
      _descController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ticket created successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _buildTicketItem(Map<String, dynamic> t) {
    final status = t['status'] ?? 'OPEN';
    final isResolved = status == 'RESOLVED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SupportChatScreen(
                    id: t['id'], subject: t['subject'], isTicket: true))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isResolved ? Colors.green[50] : Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isResolved
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                color: isResolved ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['subject'] ?? 'Untitled',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(t['ticket_type'] ?? 'General',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
