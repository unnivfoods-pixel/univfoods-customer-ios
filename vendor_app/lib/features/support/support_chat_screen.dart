import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class SupportChatScreen extends StatefulWidget {
  final String id;
  final String subject;

  const SupportChatScreen({
    super.key,
    required this.id,
    required this.subject,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _userId;
  final List<String> _faqs = [
    "Menu Update?",
    "Settlement Info?",
    "Order Dispute?",
    "Talk to Agent"
  ];

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.client.auth.currentUser?.id;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final senderId = _userId ?? SupabaseConfig.forcedVendorId ?? 'GUEST_VENDOR';

    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await SupabaseConfig.client.from('support_messages').insert({
        'chat_id': widget.id,
        'sender_id': senderId,
        'sender_type': 'VENDOR',
        'message': text,
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Chat Send Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Boutique Signal Error: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: 300.ms,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text("VENDOR SUPPORT",
                style: ProTheme.header.copyWith(fontSize: 16)),
            Text(widget.subject,
                style:
                    ProTheme.label.copyWith(fontSize: 8, color: ProTheme.gray)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from('support_messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', widget.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_type'] == 'VENDOR';
                    return _buildMessageBubble(
                        msg['message'], !isMe, msg['sender_type']);
                  },
                );
              },
            ),
          ),
          _buildFaqChips(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildFaqChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(_faqs[index],
                  style: ProTheme.label
                      .copyWith(fontSize: 10, color: ProTheme.dark)),
              backgroundColor: Colors.white,
              onPressed: () {
                _messageController.text = _faqs[index];
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ProTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.shield, color: ProTheme.primary, size: 32),
          ),
          const SizedBox(height: 24),
          Text("CHANNEL INITIALIZED",
              style: ProTheme.header.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text("Transmitting on secure frequency...",
              style: ProTheme.body.copyWith(fontSize: 12)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ProTheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.activity,
                    color: ProTheme.secondary, size: 14),
                const SizedBox(width: 8),
                Text("REAL-TIME LINK ACTIVE",
                    style: ProTheme.label
                        .copyWith(color: ProTheme.secondary, fontSize: 10)),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildMessageBubble(String text, bool isThem, String senderType) {
    return Align(
      alignment: isThem ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isThem ? Colors.white : ProTheme.dark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isThem ? 4 : 20),
            bottomRight: Radius.circular(isThem ? 20 : 4),
          ),
          boxShadow: ProTheme.softShadow,
          border: isThem
              ? Border.all(color: ProTheme.primary.withOpacity(0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isThem)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(senderType,
                    style: ProTheme.label
                        .copyWith(fontSize: 8, color: ProTheme.primary)),
              ),
            Text(
              text,
              style: ProTheme.body.copyWith(
                color: isThem ? ProTheme.dark : Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: isThem ? -0.1 : 0.1, end: 0),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: ProTheme.body.copyWith(color: ProTheme.dark),
              decoration: InputDecoration(
                hintText: "Transmitting message...",
                hintStyle: ProTheme.body
                    .copyWith(color: ProTheme.gray.withOpacity(0.5)),
                filled: true,
                fillColor: ProTheme.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: ProTheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: ProTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon:
                  const Icon(LucideIcons.send, color: ProTheme.dark, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
