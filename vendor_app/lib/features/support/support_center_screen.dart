import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'support_chat_screen.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.client.auth.currentUser?.id ??
        SupabaseConfig.forcedVendorId ??
        'GUEST_VENDOR';
  }

  Future<void> _initiateChat(String subject) async {
    final finalId = _userId ?? 'GUEST_VENDOR';

    try {
      final existing = await SupabaseConfig.client
          .from('support_chats')
          .select()
          .eq('user_id', finalId)
          .eq('user_type', 'VENDOR')
          .neq('status', 'RESOLVED')
          .maybeSingle();

      String chatId;
      if (existing != null) {
        chatId = existing['id'];
      } else {
        final res = await SupabaseConfig.client
            .from('support_chats')
            .insert({
              'user_id': finalId,
              'user_type': 'VENDOR',
              'status': 'BOT',
              'priority': 'NORMAL',
              'subject': subject, // Direct column access
              'metadata': {'initiated_via': 'VENDOR_PORTAL'}
            })
            .select()
            .single();
        chatId = res['id'];
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(
              id: chatId,
              subject: subject,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Chat Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Text("VENDOR SUPPORT",
            style: ProTheme.header.copyWith(fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildEmergencyCard(context),
            const SizedBox(height: 32),
            _buildActiveSessions(),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("VENDOR HELP CHANNELS", style: ProTheme.label),
            ),
            const SizedBox(height: 16),
            _supportChannel(
              icon: LucideIcons.messageSquare,
              title: "LIVE COMMAND CHAT",
              subtitle: "Operational & menu assistance",
              color: ProTheme.secondary,
              onTap: () => _initiateChat("Operations Support"),
            ),
            _supportChannel(
              icon: LucideIcons.creditCard,
              title: "PAYMENT ISSUES",
              subtitle: "Settlements & revenue queries",
              color: ProTheme.primary,
              onTap: () => _initiateChat("Settlement Inquiries"),
            ),
            _supportChannel(
              icon: LucideIcons.phone,
              title: "HOTLINE SUPPORT",
              subtitle: "Direct voice link to HQ",
              color: ProTheme.dark,
              onTap: () => _makeCall("+919940407600"),
            ),
            _supportChannel(
              icon: LucideIcons.mail,
              title: "DISPATCH EMAIL",
              subtitle: "support@univfoods.in",
              color: ProTheme.gray,
              onTap: () => _sendEmail("support@univfoods.in"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessions() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client
          .from('support_chats')
          .stream(primaryKey: ['id'])
          .eq('user_id', _userId!)
          .order('updated_at', ascending: false),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? [];
        final activeChats =
            chats.where((t) => t['status'] != 'RESOLVED').toList();
        if (activeChats.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ACTIVE COMMAND SESSIONS", style: ProTheme.label),
            const SizedBox(height: 16),
            ...activeChats.map((t) => _buildSessionTile(t)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> chat) {
    final String subject =
        chat['subject'] ?? chat['metadata']?['subject'] ?? "Support Session";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ProTheme.cardDecor.copyWith(
        border: Border.all(color: ProTheme.primary.withOpacity(0.2)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(
              id: chat['id'],
              subject: subject,
            ),
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: ProTheme.bg, shape: BoxShape.circle),
          child: Icon(LucideIcons.messageCircle,
              color: ProTheme.secondary, size: 20),
        ),
        title: Text(subject, style: ProTheme.title.copyWith(fontSize: 14)),
        subtitle: Text("Status: ${chat['status']}",
            style: ProTheme.body.copyWith(fontSize: 11)),
        trailing:
            Icon(LucideIcons.chevronRight, size: 16, color: ProTheme.gray),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ProTheme.dark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: ProTheme.intenseShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                    color: ProTheme.primary, shape: BoxShape.circle),
                child:
                    const Icon(LucideIcons.zap, color: ProTheme.dark, size: 24),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("URGENT ASSISTANCE",
                        style: ProTheme.title.copyWith(color: Colors.white)),
                    Text("Immediate vendor support",
                        style: ProTheme.label
                            .copyWith(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _makeCall("+919940407600"),
              style: ProTheme.secondaryButton,
              child: const Text("SOS: CONTACT HQ"),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _supportChannel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ProTheme.cardDecor,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: ProTheme.title.copyWith(fontSize: 14)),
        subtitle: Text(subtitle, style: ProTheme.body.copyWith(fontSize: 12)),
        trailing: const Icon(LucideIcons.chevronRight,
            size: 18, color: ProTheme.gray),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  void _sendEmail(String email) async {
    final Uri url = Uri.parse("mailto:$email?subject=Vendor Support Request");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _makeCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
