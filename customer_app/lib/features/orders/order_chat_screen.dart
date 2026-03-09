import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String riderName;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.riderName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _chatSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToChat();
  }

  @override
  void dispose() {
    _chatSub?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    try {
      final response = await SupabaseConfig.client
          .from('messages')
          .select()
          .eq('order_id', widget.orderId)
          .order('timestamp', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Load Messages Error: $e");
    }
  }

  void _subscribeToChat() {
    _chatSub = SupabaseConfig.client
        .channel('order_chat_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _messages.add(payload.newRecord);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    _messageController.clear();
    final user = SupabaseConfig.client.auth.currentUser;
    final userId = SupabaseConfig.forcedUserId ?? user?.id ?? 'GUEST_USER';

    try {
      // Get the current order to find the rider_id (receiver)
      final orderRes = await SupabaseConfig.client
          .from('orders')
          .select('delivery_id')
          .eq('order_id', widget.orderId)
          .single();

      final riderId = orderRes['delivery_id'];

      await SupabaseConfig.client.from('messages').insert({
        'order_id': widget.orderId,
        'sender_id': userId,
        'receiver_id': riderId,
        'message': msg,
      });
    } catch (e) {
      debugPrint("Send Message Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed to send: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.riderName.toUpperCase(),
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
            Text("Active Delivery Partner",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final user = SupabaseConfig.client.auth.currentUser;
                      final userId = SupabaseConfig.forcedUserId ?? user?.id;
                      final isMe = m['sender_id'] == userId;
                      return _buildMessageBubble(m['message'], isMe);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Message ${widget.riderName}...",
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
