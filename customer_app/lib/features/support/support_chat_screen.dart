import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SupportChatScreen extends StatefulWidget {
  final String id;
  final String subject;
  final bool isTicket;

  const SupportChatScreen(
      {super.key,
      required this.id,
      required this.subject,
      this.isTicket = false});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickActions = [
    "Track my order",
    "Refund issue",
    "Payment problem",
    "Talk to agent"
  ];

  String get _messagesTable =>
      widget.isTicket ? 'ticket_messages' : 'support_messages';
  String get _fk => widget.isTicket ? 'ticket_id' : 'chat_id';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Column(
          children: [
            Text(widget.isTicket ? "TICKET SUPPORT" : "UNIV SUPPORT HQ",
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black)),
            Text(widget.subject,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from(_messagesTable)
                  .stream(primaryKey: ['id'])
                  .eq(_fk, widget.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_type'] == 'USER' ||
                        (widget.isTicket && !msg['is_admin']);
                    final time = DateTime.tryParse(msg['created_at'] ?? '') ??
                        DateTime.now();

                    return _buildMessageBubble(
                        msg['message'],
                        !isMe,
                        msg['sender_type'] ??
                            (msg['is_admin'] ? 'AGENT' : 'USER'),
                        DateFormat('HH:mm').format(time));
                  },
                );
              },
            ),
          ),
          if (!widget.isTicket) _buildQuickActionChips(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: Color(0xFF0F172A), size: 48),
          ),
          const SizedBox(height: 24),
          Text("MISSION HQ CONNECTED",
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Text("Welcome to Univ Support!",
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
          Text("Our team is ready to assist you.",
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded,
                    color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text("ENCRYPTED REAL-TIME RELAY",
                    style: GoogleFonts.inter(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _quickActions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(_quickActions[index],
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A))),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0))),
              onPressed: () {
                _messageController.text = _quickActions[index];
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  void _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    _messageController.clear();
    final user = SupabaseConfig.client.auth.currentUser;

    try {
      final finalSenderId =
          user?.id ?? SupabaseConfig.forcedUserId ?? 'GUEST_USER';

      if (widget.isTicket) {
        await SupabaseConfig.client.from('ticket_messages').insert({
          'ticket_id': widget.id,
          'sender_id': finalSenderId,
          'message': msg,
          'is_admin': false,
        });
      } else {
        await SupabaseConfig.client.from('support_messages').insert({
          'chat_id': widget.id,
          'sender_id': finalSenderId,
          'sender_type': 'USER',
          'message': msg,
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint("Chat error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Transmission Error: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(
      String text, bool isThem, String senderType, String time) {
    return Align(
      alignment: isThem ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment:
            isThem ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isThem ? Colors.white : const Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isThem ? 4 : 20),
                bottomRight: Radius.circular(isThem ? 20 : 4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: isThem ? const Color(0xFF0F172A) : Colors.white,
                fontSize: 14,
                fontWeight: isThem ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text("$senderType · $time",
                style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle:
                      GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
