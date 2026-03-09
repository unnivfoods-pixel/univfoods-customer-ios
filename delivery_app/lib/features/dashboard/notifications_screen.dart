import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/supabase_config.dart';
import '../../core/pro_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text("ACCESS DENIED: PLEASE LOGIN")));
    }

    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Text("Tactical Inbox",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: ProTheme.dark,
                fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: ProTheme.dark),
        actions: [
          IconButton(
            onPressed: () async {
              await SupabaseConfig.client
                  .from('notifications')
                  .update({'is_read': true}).eq('user_id', user.id);
            },
            icon: const Icon(LucideIcons.checkCheck,
                size: 20, color: ProTheme.primary),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseConfig.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: ProTheme.primary));
          }
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bellOff,
                      size: 64, color: ProTheme.gray.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("NO ACTIVE SIGNALS",
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900, color: ProTheme.gray)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildItem(items[index]),
          );
        },
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final isRead = item['is_read'] ?? false;
    final event = item['event_type'] ?? 'INFO';

    IconData icon = LucideIcons.bell;
    Color color = ProTheme.primary;

    if (event.contains('ORDER')) {
      icon = LucideIcons.package;
      color = ProTheme.secondary;
    } else if (event.contains('SYSTEM')) {
      icon = LucideIcons.cpu;
      color = ProTheme.dark;
    } else if (event.contains('ALERT')) {
      icon = LucideIcons.alertTriangle;
      color = ProTheme.error;
    }

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await SupabaseConfig.client
              .from('notifications')
              .update({'is_read': true}).eq('id', item['id']);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? Colors.white.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isRead
              ? null
              : Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: isRead
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] ?? "Signal",
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: ProTheme.dark)),
                  const SizedBox(height: 4),
                  Text(item['message'] ?? item['body'] ?? "",
                      style: GoogleFonts.inter(
                          fontSize: 13, color: ProTheme.gray, height: 1.4)),
                  const SizedBox(height: 12),
                  Text(_formatTime(item['created_at']),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: ProTheme.gray.withOpacity(0.6),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: ProTheme.primary, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "NOW";
    if (diff.inMinutes < 60) return "${diff.inMinutes}M AGO";
    if (diff.inHours < 24) return "${diff.inHours}H AGO";
    return "${date.day}/${date.month}";
  }
}
