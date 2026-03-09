import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/settings_store.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Preferences",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: SettingsStore(),
              builder: (context, _) {
                final s = SettingsStore().settings;
                return Column(
                  children: [
                    _buildToggleItem(
                      LucideIcons.package,
                      "Order Updates",
                      "Get real-time updates on your order progress.",
                      s['order_updates'] ?? true,
                      (v) => SettingsStore().updateSetting('order_updates', v),
                    ),
                    _buildToggleItem(
                      LucideIcons.ticket,
                      "Offers & Promotions",
                      "Get notified about latest deals and curries.",
                      s['promotions'] ?? true,
                      (v) => SettingsStore().updateSetting('promotions', v),
                    ),
                    _buildToggleItem(
                      LucideIcons.shieldAlert,
                      "System Alerts",
                      "Important account and security notifications.",
                      s['system_alerts'] ?? true,
                      (v) => SettingsStore().updateSetting('system_alerts', v),
                    ),
                    const SizedBox(height: 48),
                    Text("CHANNELS",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 2)),
                    const SizedBox(height: 24),
                    _buildToggleItem(
                      LucideIcons.smartphone,
                      "Push Notifications",
                      "Recommended for the best experience.",
                      s['push_notifications'] ?? true,
                      (v) => SettingsStore()
                          .updateSetting('push_notifications', v),
                    ),
                    _buildToggleItem(
                      LucideIcons.mail,
                      "Email Digest",
                      "Weekly summary of your orders.",
                      s['email_digest'] ?? false,
                      (v) => SettingsStore().updateSetting('email_digest', v),
                    ),
                    _buildToggleItem(
                      LucideIcons.messageSquare,
                      "SMS Updates",
                      "Standard carrier rates may apply.",
                      s['sms_updates'] ?? false,
                      (v) => SettingsStore().updateSetting('sms_updates', v),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String title, String subtitle,
      bool value, Function(bool)? onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ProTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: ProTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ProTheme.primary,
          ),
        ],
      ),
    );
  }
}
