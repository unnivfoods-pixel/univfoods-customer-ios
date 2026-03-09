import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';
import '../../core/services/notification_service.dart';
import '../orders/order_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    // 🛡️ MORE ROBUST AUTH CHECK (Recognize forced/manual ID)
    final userId = SupabaseConfig.client.auth.currentUser?.id ??
        SupabaseConfig.forcedUserId;

    if (userId == null) {
      return const Scaffold(
          body: Center(child: Text("Please login to see notifications")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Inbox",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showDebug = !_showDebug),
            icon: const Icon(LucideIcons.settings),
          ),
          TextButton(
            onPressed: () async {
              await SupabaseConfig.client
                  .from('notifications')
                  .update({'is_read': true}).eq('user_id', userId);
            },
            child: const Text("MARK ALL READ",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: ProTheme.primary)),
          )
        ],
      ),
      body: Column(
        children: [
          if (_showDebug)
            Container(
              color: Colors.amber[50],
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text("CURRENT UID: $userId",
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => NotificationService.forceStart(),
                        child: const Text("FORCE RE-SYNC",
                            style: TextStyle(fontSize: 10)),
                      ),
                      ElevatedButton(
                        onPressed: () => NotificationService.testNotification(),
                        child: const Text("TEST ALERT",
                            style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from('notifications')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.bellOff,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("NOTHING HERE",
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[400])),
                        Text("We will notify you when something happens!",
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildItem(items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final isRead = item['is_read'] ?? item['read_status'] ?? false;
    final event = item['type'] ?? item['event_type'] ?? 'INFO';

    IconData icon = LucideIcons.bell;
    Color color = ProTheme.primary;

    if (event.contains('ORDER')) {
      icon = LucideIcons.package;
      color = Colors.blue;
    } else if (event.contains('DELIVERED')) {
      icon = LucideIcons.checkCircle;
      color = Colors.green;
    } else if (event.contains('CANCEL')) {
      icon = LucideIcons.xCircle;
      color = Colors.red;
    } else if (event.contains('REFUND')) {
      icon = LucideIcons.refreshCw;
      color = Colors.orange;
    }

    return Opacity(
      opacity: isRead ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: () => _handleTap(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isRead
                ? null
                : Border.all(color: color.withOpacity(0.1), width: 1),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                        color: color.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] ?? "Notification",
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(
                        item['message'] ??
                            item['body'] ??
                            "Tap to view details",
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Text(_formatTime(item['created_at']),
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: ProTheme.primary, shape: BoxShape.circle),
                )
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(Map<String, dynamic> item) async {
    // 1. Mark as read
    if (item['read_status'] != true) {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true}).eq('id', item['id']);
    }

    // 2. Deep Link to Order if applicable (Point 4)
    if (item['order_id'] != null && mounted) {
      // Fetch full order data for the detail screen
      final res = await SupabaseConfig.client
          .from('orders')
          .select('*, vendors(*)')
          .eq('id', item['order_id'])
          .single();
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: res)));
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${date.day}/${date.month}/${date.year}";
  }
}
