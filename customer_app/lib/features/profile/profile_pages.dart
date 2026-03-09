import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/supabase_config.dart';
import '../support/support_chat_screen.dart';
import '../../core/favorite_store.dart';
import '../../core/payment_store.dart';
import '../../core/navigation.dart';
import '../../core/pro_theme.dart';
import '../../core/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../support/help_center_screens.dart';
import '../support/support_tickets_screen.dart';

// Profile Feature Pages - Legacy "Old Design" Restoration
// 1. EDIT PROFILE SCREEN
class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;

  const EditProfileScreen(
      {super.key, required this.currentName, required this.currentPhone});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 🚀 FIX: If the name is just a phone number fallback, leave it empty for easier editing
    String initialName = widget.currentName;
    if (initialName.contains('+91') || initialName.contains('sms_auth')) {
      initialName = "";
    }
    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: widget.currentPhone);
  }

  void _saveProfile() async {
    final userId = SupabaseConfig.forcedUserId;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      // 🚀 TEMP FIX: Removed 'updated_at' as the column is missing in the DB
      await SupabaseConfig.client.from('customer_profiles').upsert({
        'id': userId,
        'full_name': _nameController.text,
        'phone': _phoneController.text
            .replaceAll(RegExp(r'\D'), '')
            .replaceFirst(RegExp(r'^91'), ''),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Profile Updated Successfully"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text("EDIT PROFILE",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.grey[100], shape: BoxShape.circle),
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.grey),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4500),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  )
                ],
              ).animate().scale(),
            ),
            const SizedBox(height: 32),
            _buildInput("Full Name", _nameController),
            const SizedBox(height: 16),
            _buildInput("Phone Number", _phoneController,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("SAVE CHANGES",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
            label: Text(hint,
                style: GoogleFonts.inter(
                    color: Colors.grey, fontWeight: FontWeight.bold)),
            border: InputBorder.none),
      ),
    );
  }
}

// 2. FAVORITES SCREEN
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text("MY FAVORITES",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavoriteStore.favorites,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.favorite_outline,
                        size: 60, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 48),
                  Text("WHERE IS THE LOVE?",
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                        "Once you favorite a Curry Point, it will appear here.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5)),
                  ),
                ],
              ),
            );
          }

          final favoriteItems = favorites.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favoriteItems.length,
            itemBuilder: (context, index) {
              final id = favoriteItems[index];
              final v = FavoriteStore.favoriteDetails[id] ?? {};
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02), blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        v['banner_url'] ?? 'https://via.placeholder.com/100',
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['name'] ?? "Curry Point",
                              style: GoogleFonts.outfit(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(v['cuisine_type'] ?? "Indian",
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 14),
                              Text(" ${v['rating'] ?? '4.8'}",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => FavoriteStore.toggle(v),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 3. (SECTION RESERVED OR MOVED TO notification_preferences_screen.dart)

// 4. REFUND STATUS SCREEN
class RefundStatusScreen extends StatelessWidget {
  const RefundStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseConfig.forcedUserId ??
        SupabaseConfig.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("RefuND STATUS",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: userId == null
          ? const Center(child: Text("Please login to see refunds"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from('refund_requests')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                final refunds = snapshot.data ?? [];

                if (refunds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: Center(
                            child: Text("₹",
                                style: GoogleFonts.inter(
                                    fontSize: 60,
                                    color: Colors.grey[300],
                                    fontWeight: FontWeight.w300)),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text("No Active Refunds",
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black)),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                              "When you cancel an order or an item is missing, your refund status will appear here.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.5)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: refunds.length,
                  itemBuilder: (context, index) {
                    final r = refunds[index];
                    return _buildRefundTile(r);
                  },
                );
              },
            ),
    );
  }

  Widget _buildRefundTile(Map<String, dynamic> r) {
    final status = r['status'] ?? 'PENDING';
    final isComplete = status == 'COMPLETE';
    final isFailed = status == 'FAIL';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Order ID: #${r['order_id'].toString().substring(0, 8)}",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green[50]
                      : isFailed
                          ? Colors.red[50]
                          : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isComplete
                            ? Colors.green[700]
                            : isFailed
                                ? Colors.red[700]
                                : Colors.orange[700])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Amount: ₹${r['refund_amount']}",
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black)),
          const SizedBox(height: 4),
          Text("Requested on: ${r['created_at'].toString().substring(0, 10)}",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// 5. PAYMENT MODES SCREEN
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  void _addPaymentMethod(String type) {
    final labelController = TextEditingController();
    final valueController = TextEditingController();
    final issuerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add $type",
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: "Label (e.g. My Bank)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: type == 'CARD' ? "Card Number" : "UPI ID / Email",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    PaymentStore().addMethod({
                      'type': type,
                      'label': labelController.text,
                      'value': valueController.text,
                      'issuer': issuerController.text.isEmpty
                          ? 'Other'
                          : issuerController.text,
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProTheme.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      const Text("SAVE", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text("Payment Modes",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B4332))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListenableBuilder(
        listenable: PaymentStore(),
        builder: (context, _) {
          final methods = PaymentStore().methods;
          final upi = methods.where((m) => m['type'] == 'UPI').toList();
          final cards = methods.where((m) => m['type'] == 'CARD').toList();
          final wallets = methods.where((m) => m['type'] == 'WALLET').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("UPI"),
                ...upi.map((m) => _buildPaymentTile(m)),
                _buildAddCard(Icons.add, "Add New UPI ID",
                    "GPay, PhonePe, etc.", () => _addPaymentMethod('UPI')),
                const SizedBox(height: 24),
                _buildSectionHeader("CARDS"),
                ...cards.map((m) => _buildPaymentTile(m)),
                _buildAddCard(
                    Icons.add,
                    "Add New Card",
                    "Save cards for faster checkout",
                    () => _addPaymentMethod('CARD')),
                const SizedBox(height: 24),
                _buildSectionHeader("WALLETS"),
                ...wallets.map((m) => _buildPaymentTile(m)),
                _buildAddCard(
                    Icons.account_balance_wallet_outlined,
                    "Link New Wallet",
                    "Amazon Pay, Paytm, etc.",
                    () => _addPaymentMethod('WALLET')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey[500],
              letterSpacing: 0.5)),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.green[50]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
                m['type'] == 'CARD'
                    ? Icons.credit_card
                    : Icons.account_balance_wallet_outlined,
                color: const Color(0xFF1B4332),
                size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['label'] ?? "Payment Method",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(m['value'] ?? "",
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => PaymentStore().removeMethod(m['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.green[50]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF1B4332), size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, color: Colors.yellow[700], size: 20),
          ],
        ),
      ),
    );
  }
}

// 6. HELP & SUPPORT SCREEN
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  bool _isConnecting = false;

  void _makeCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _sendEmail(String email) async {
    final Uri url = Uri.parse("mailto:$email?subject=Support Request");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _initiateLiveChat(BuildContext context) async {
    final userId = SupabaseConfig.forcedUserId ??
        SupabaseConfig.client.auth.currentUser?.id ??
        'GUEST_USER';

    debugPrint(">>> [TACTICAL] INITIATING LIVE CHAT FOR: $userId");
    setState(() => _isConnecting = true);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("📡 ESTABLISHING COMMAND LINK..."),
      backgroundColor: Color(0xFFFF4500),
      duration: Duration(milliseconds: 800),
    ));

    try {
      // 🕵️ Search for any active command session.
      final response = await SupabaseConfig.client
          .from('support_chats')
          .select()
          .eq('user_id', userId)
          .neq('status', 'RESOLVED')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String chatId;
      if (response != null) {
        chatId = response['id'];
        debugPrint(">>> [RECONNECT] ACTIVE SESSION DETECTED: $chatId");
      } else {
        debugPrint(">>> [NEW SESSION] INITIALIZING NEURAL UPLINK...");
        final res = await SupabaseConfig.client
            .from('support_chats')
            .insert({
              'user_id': userId,
              'user_type': 'CUSTOMER',
              'status': 'BOT',
              'priority': 'NORMAL',
              'subject': 'Live Support Session',
            })
            .select()
            .single();
        chatId = res['id'];
      }

      if (!mounted) return;

      debugPrint(">>> [NAVIGATE] REDIRECTING TO THEATRE: $chatId");

      final route = MaterialPageRoute(
        builder: (_) => SupportChatScreen(
          id: chatId,
          subject: 'Live Support',
        ),
      );

      // Prefer direct navigator if context is valid
      Navigator.of(context).push(route);
    } catch (e) {
      debugPrint(">>> [CRITICAL] Neural Link Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Neural Link Interrupted: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("Help & Support",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          // Refund Summary Card
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("You have 0 active refund",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            debugPrint(">>> ACTION: View My Refunds");
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
                              navigatorKey.currentState?.push(MaterialPageRoute(
                                  builder: (_) => const RefundStatusScreen()));
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text("VIEW MY REFUNDS >",
                                style: GoogleFonts.outfit(
                                    color: const Color(0xFFFF4500),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5)
                      ]),
                  child: Text("₹",
                      style: GoogleFonts.inter(
                          fontSize: 24, color: Colors.grey[300])),
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text("REAL-TIME SUPPORT",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5)),
          ),

          StreamBuilder<Map<String, dynamic>?>(
            stream: SupabaseConfig.client
                .from('app_settings')
                .stream(primaryKey: ['key'])
                .eq('key', 'system_config')
                .limit(1)
                .map((list) => list.isNotEmpty
                    ? (list.first['value'] as Map<String, dynamic>)
                    : null),
            builder: (context, snapshot) {
              final config = snapshot.data;
              final phone = config?['supportPhone'] ?? "+919940407600";
              final email = config?['supportEmail'] ?? "support@univfoods.in";

              return Column(
                children: [
                  _buildRealtimeSupportTile("Start Live Chat", "Available Now",
                      Icons.chat_bubble_outline,
                      isLive: true,
                      isLoading: _isConnecting,
                      onTap: _isConnecting
                          ? () {}
                          : () => _initiateLiveChat(context)),
                  _buildRealtimeSupportTile("Call Support",
                      "Instant Connection", Icons.phone_in_talk_outlined,
                      isLive: true, onTap: () {
                    _makeCall(phone);
                  }),
                  _buildRealtimeSupportTile(
                      "Email Support", "Active Dispatch", Icons.mail_outline,
                      isLive: true, onTap: () {
                    _sendEmail(email);
                  }),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text("HELP WITH OTHER QUERIES",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5)),
          ),

          _buildHelpTile(context, "UNIV Plus FAQs", Icons.star_outline),
          _buildHelpTile(context, "General Issues", Icons.help_outline),
          _buildHelpTile(
              context, "Become a Partner", Icons.business_center_outlined),
          _buildHelpTile(
              context, "Report Safety Emergency", Icons.emergency_outlined),
          _buildHelpTile(
              context, "Quick Commerce FAQs", Icons.flash_on_outlined),
          _buildHelpTile(
              context, "Legal, Terms & Conditions", Icons.description_outlined),
          _buildHelpTile(context, "FAQs", Icons.question_answer_outlined),
        ],
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context, String title, IconData icon) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint(">>> HELP TILE TAP: $title");

                Widget destination;
                if (title.contains("Become a Partner")) {
                  destination = const BecomePartnerScreen();
                } else if (title.contains("General Issues")) {
                  destination = const SupportTicketsScreen();
                } else if (title.contains("Safety Emergency")) {
                  destination = const SafetyEmergencyScreen();
                } else if (title.contains("Legal") || title.contains("Terms")) {
                  destination = const LegalPolicyScreen(
                      type: 'TERMS_CONDITIONS', title: "Legal & Policies");
                } else {
                  destination = FAQDetailScreen(title: title);
                }

                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => destination));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.black.withOpacity(0.6), size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.grey[400], size: 20),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[50]),
        ],
      ),
    );
  }

  Widget _buildRealtimeSupportTile(String title, String subtitle, IconData icon,
      {bool isLive = false,
      bool isLoading = false,
      required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint(">>> SUPPORT TILE TAP: $title");
                onTap();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF4500).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12)),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFFF4500)),
                            )
                          : Icon(icon,
                              color: const Color(0xFFFF4500), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(title,
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87)),
                              if (isLive && !isLoading) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle),
                                ).animate(onPlay: (c) => c.repeat()).scale(
                                    duration: 800.ms,
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.3, 1.3)),
                              ],
                            ],
                          ),
                          Text(subtitle,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    if (!isLoading)
                      Icon(Icons.chevron_right,
                          color: Colors.grey[400], size: 20),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[50]),
        ],
      ),
    );
  }
}

// 7. SAVED ADDRESSES SCREEN (Real-time Action)
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _userId = SupabaseConfig.forcedUserId;

  Future<void> _addAddress() async {
    final labelController = TextEditingController(text: 'Home');
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final pincodeController = TextEditingController();
    String selectedLabel = 'Home';

    bool isSaving = false; // Local state for the modal - MOVED OUTSIDE builder

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... (rest of the UI)
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ProTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_location_alt_rounded,
                              color: ProTheme.secondary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Add New Address",
                                style: GoogleFonts.outfit(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            Text("Fill in your delivery details",
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Label Chips ─────────────────────────────────────────
                    Text("Address Type",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[500],
                            letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Home', 'Work', 'Other'].map((lbl) {
                        final isSelected = selectedLabel == lbl;
                        final icon = lbl == 'Home'
                            ? Icons.home_rounded
                            : lbl == 'Work'
                                ? Icons.work_rounded
                                : Icons.location_on_rounded;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ProTheme.secondary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? ProTheme.secondary
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: ProTheme.secondary
                                              .withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setModalState(() {
                                      selectedLabel = lbl;
                                      labelController.text = lbl;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(icon,
                                            size: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey[500]),
                                        const SizedBox(width: 6),
                                        Text(lbl,
                                            style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Full Address ────────────────────────────────────────
                    Text("Full Address",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[500],
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _buildCustomInput(
                      controller: addressController,
                      label: "House no., Street, Area, City",
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // ── Phone + Pincode row ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Phone Number",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              _buildCustomInput(
                                controller: phoneController,
                                label: "10-digit mobile",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Pincode",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              _buildCustomInput(
                                controller: pincodeController,
                                label: "6-digit code",
                                icon: Icons.pin_drop_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final addr = addressController.text.trim();
                                final phone = phoneController.text.trim();
                                final pincode = pincodeController.text.trim();

                                if (addr.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Please enter a full address"),
                                      backgroundColor: Colors.orange[800],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  );
                                  return;
                                }
                                if (_userId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("User not found")),
                                  );
                                  return;
                                }

                                if (ctx.mounted) {
                                  setModalState(() => isSaving = true);
                                }
                                debugPrint(
                                    ">>> ATTEMPTING SAVE for UID: $_userId");

                                try {
                                  // 🔍 GEOCODE the address first!
                                  debugPrint(">>> GEOCODING ADDR: $addr");
                                  final coords = await LocationService
                                      .getLatLngFromAddress(addr);

                                  double savedLat =
                                      9.5127; // Fallback to Srivi center if absolute failure
                                  double savedLng = 77.6337;

                                  if (coords != null) {
                                    savedLat = coords['lat']!;
                                    savedLng = coords['lng']!;
                                    debugPrint(
                                        ">>> GEOCODE SUCCESS: ($savedLat, $savedLng)");
                                  } else {
                                    debugPrint(">>> GEOCODE FAILED for: $addr");
                                    // Optionally block or warn
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Warning: Could not pinpoint exact location. Using city center.")));
                                  }

                                  final basePayload = <String, dynamic>{
                                    'user_id': _userId,
                                    'address_line': addr,
                                    'latitude': savedLat,
                                    'longitude': savedLng,
                                  };

                                  // 1. Try with ALL fields (label, phone, pincode)
                                  try {
                                    debugPrint(
                                        ">>> TRY 1 (Full): label=$selectedLabel");
                                    await SupabaseConfig.client
                                        .from('user_addresses')
                                        .insert({
                                      ...basePayload,
                                      'label': selectedLabel,
                                      'phone': phone,
                                      'pincode': pincode,
                                    });
                                  } catch (e1) {
                                    final msg = e1.toString();
                                    debugPrint(">>> TRY 1 FAILED: $msg");

                                    // 2. Fallback: Check if 'label' vs 'title' is the issue
                                    String labelKey = 'label';
                                    if (msg.contains('label') ||
                                        msg.contains('PGRST204')) {
                                      labelKey = 'title';
                                    }

                                    debugPrint(
                                        ">>> RETRYING with $labelKey...");

                                    // 3. Try with minimal safe fields
                                    final retryPayload = {
                                      ...basePayload,
                                      labelKey: selectedLabel,
                                    };

                                    await SupabaseConfig.client
                                        .from('user_addresses')
                                        .insert(retryPayload);
                                  }

                                  debugPrint(">>> SAVE SUCCESS!");

                                  if (mounted) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "✅ $selectedLabel saved successfully!"),
                                        backgroundColor: Colors.green[700],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint("FINAL ERROR ADDING ADDRESS: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Save failed: $e"),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => isSaving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProTheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text("SAVE ADDRESS",
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200] ?? Colors.grey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.grey[400], size: 20),
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(String id) async {
    try {
      await SupabaseConfig.client.from('user_addresses').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting address: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text("MY ADDRESSES",
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _addAddress,
            child: Text("+ ADD NEW",
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF4500),
                    fontWeight: FontWeight.w900)),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userId == null
            ? Stream.value([])
            : SupabaseConfig.client
                .from('user_addresses')
                .stream(primaryKey: ['id']).eq('user_id', _userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No saved addresses yet.",
                      style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final a = addresses[index];
              final label = a['label'] ?? a['title'] ?? "Location";
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAddressTile(
                  label,
                  a['address_line'] ?? "",
                  label == 'Home'
                      ? Icons.home_rounded
                      : label == 'Work'
                          ? Icons.work_rounded
                          : Icons.location_on_rounded,
                  phone: a['phone'],
                  pincode: a['pincode'],
                  onDelete: () => _deleteAddress(a['id']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddressTile(String label, String addr, IconData icon,
      {String? phone, String? pincode, required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ProTheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ProTheme.secondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(addr,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[600], height: 1.4)),
                if ((phone != null && phone.isNotEmpty) ||
                    (pincode != null && pincode.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (phone != null && phone.isNotEmpty) ...[
                          Icon(Icons.phone_android_rounded,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(phone,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                        if (phone != null &&
                            phone.isNotEmpty &&
                            pincode != null &&
                            pincode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.circle,
                                size: 3, color: Colors.grey[300]),
                          ),
                        if (pincode != null && pincode.isNotEmpty) ...[
                          Icon(Icons.pin_drop_rounded,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(pincode,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            itemBuilder: (ctx) => [
              PopupMenuItem(onTap: onDelete, child: const Text("Delete")),
            ],
          ),
        ],
      ),
    );
  }
}

// 8. LIVE CHAT SCREEN (Real-time Action)
// 8. LIVE CHAT SCREEN (Real-time Action)
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-initiate live session if this screen is accidentally shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateAndRedirect();
    });
  }

  void _initiateAndRedirect() async {
    final userId = SupabaseConfig.forcedUserId ?? 'GUEST_USER';
    try {
      final existing = await SupabaseConfig.client
          .from('support_chats')
          .select()
          .eq('user_id', userId)
          .neq('status', 'RESOLVED')
          .maybeSingle();

      String chatId;
      if (existing != null) {
        chatId = existing['id'];
      } else {
        final res = await SupabaseConfig.client
            .from('support_chats')
            .insert({
              'user_id': userId,
              'user_type': 'CUSTOMER',
              'status': 'BOT',
              'priority': 'NORMAL',
              'subject': 'Live Support Session',
            })
            .select()
            .single();
        chatId = res['id'];
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(
              id: chatId,
              subject: 'Live Support',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Support Redirect Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: ProTheme.primary),
            const SizedBox(height: 24),
            Text("CONNECTING TO MISSION HQ...",
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// 9. FAQ DETAIL SCREEN (Real-time Action)
class FAQDetailScreen extends StatelessWidget {
  final String title;
  const FAQDetailScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title.toUpperCase(),
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseConfig.client
            .from('faqs')
            .stream(primaryKey: ['id']).eq('active_status', true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allFaqs = snapshot.data ?? [];
          // Filter by keyword match in title for dynamic category loading
          final filtered = allFaqs.where((f) {
            final cat = (f['category'] ?? 'GENERAL').toString().toUpperCase();
            final keywords =
                (f['keywords'] as List?)?.join(' ').toUpperCase() ?? '';
            return title.toUpperCase().contains(cat) ||
                keywords.contains(title.toUpperCase());
          }).toList();

          final displayFaqs =
              filtered.isEmpty ? allFaqs.take(5).toList() : filtered;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("REAL-TIME INTELLIGENCE",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF4500))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("LIVE SYNC",
                          style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (displayFaqs.isEmpty)
                  const Center(
                      child: Text("No specific intel found. Contact HQ.")),
                ...displayFaqs
                    .map((f) => _buildFaqItem(f['question'], f['answer'])),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Text("STILL NEED HELP?",
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                          "Establish a direct neural link with a tactical agent.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _initiateLiveChat(context,
                              subject: "Ref: $title"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4500),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text("ESTABLISH COMMAND LINK",
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _initiateLiveChat(BuildContext context,
      {required String subject}) async {
    final userId = SupabaseConfig.forcedUserId ?? 'GUEST_USER';

    debugPrint(">>> [FAQ INTELLIGENCE] ESCALATING TO HUMAN COMMAND: $userId");

    try {
      final existing = await SupabaseConfig.client
          .from('support_chats')
          .select()
          .eq('user_id', userId)
          .neq('status', 'RESOLVED')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String chatId;
      if (existing != null) {
        chatId = existing['id'];
      } else {
        final res = await SupabaseConfig.client
            .from('support_chats')
            .insert({
              'user_id': userId,
              'user_type': 'CUSTOMER',
              'status': 'BOT',
              'priority': 'NORMAL',
              'subject': subject,
            })
            .select()
            .single();
        chatId = res['id'];
      }

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(
              id: chatId,
              subject: subject,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Support Init Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Neural Link Interrupted: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _buildFaqItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: GoogleFonts.outfit(
                  fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(a,
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }
}
