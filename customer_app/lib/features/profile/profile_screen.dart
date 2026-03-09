import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/supabase_config.dart';
import 'profile_pages.dart';
import 'notifications_screen.dart';
import 'notification_preferences_screen.dart';
import '../../core/location_store.dart';
import '../../core/profile_store.dart';

class ProfileScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const ProfileScreen({super.key, this.onTabChange});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    debugPrint("TAP: Logout (Profile)");
    try {
      await SupabaseConfig.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint("LOGOUT ERROR: $e");
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showLoginPrompt() {
    if (!mounted) return;
    Navigator.of(context).pushNamed('/login');
  }

  void _openFeature(Widget screen) {
    debugPrint(">>> NAVIGATING TO: ${screen.runtimeType}");
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SupabaseConfig.sessionUser,
      builder: (context, userId, _) {
        // Double check with currentUid for robustness
        final String? activeId = userId ?? SupabaseConfig.currentUid;
        final bool isLoggedIn = activeId != null && activeId.isNotEmpty;

        if (!isLoggedIn) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Please Login to View Profile",
                      style: GoogleFonts.outfit(fontSize: 20)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _showLoginPrompt,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4500)),
                    child: const Text("LOGIN NOW"),
                  )
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text("MY ACCOUNT",
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5)),
            centerTitle: false,
          ),
          body: ListenableBuilder(
            listenable: LocationStore(),
            builder: (context, _) => ListenableBuilder(
              listenable: ProfileStore(),
              builder: (context, _) {
                final profile = ProfileStore().profile;
                final fbUser = FirebaseAuth.instance.currentUser;

                final String fullName = profile?['full_name']?.toString() ?? '';
                final String profilePhone = profile?['phone']?.toString() ?? '';
                final String fbPhone =
                    fbUser?.phoneNumber?.replaceAll('+91', '') ?? '';

                final String rawPhoneNumber =
                    profilePhone.isNotEmpty ? profilePhone : fbPhone;

                // 📞 PHONE FALLBACK (If profile lookup is incomplete or user has no name)
                String displayPhone = (rawPhoneNumber.isNotEmpty)
                    ? (rawPhoneNumber.startsWith('+91')
                        ? rawPhoneNumber
                        : "+91 $rawPhoneNumber")
                    : 'No Phone';

                // Try to extract from ID if still empty
                if (displayPhone == 'No Phone') {
                  if (activeId.contains('sms_auth')) {
                    final extracted = activeId
                        .split('_')
                        .last
                        .replaceFirst(RegExp(r'^91'), '');
                    if (extracted.length >= 10) {
                      displayPhone = "+91 $extracted";
                    }
                  }
                }

                final String displayName =
                    fullName.trim().isNotEmpty ? fullName : displayPhone;

                final String address = LocationStore().selectedAddress;
                final avatarUrl = profile?['avatar_url'];

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. User Info Section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5)),
                                  const SizedBox(height: 6),
                                  // 🆔 USER ID & PHONE
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.badge_outlined,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text("ID: $activeId",
                                              style: GoogleFonts.inter(
                                                  color: Colors.grey[700],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(displayPhone,
                                              style: GoogleFonts.inter(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // 📍 CURRENT ADDRESS
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 14,
                                              color: Color(0xFFFF4500)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(address,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                    color: Colors.black87,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.2)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        debugPrint("NAV: Edit Profile");
                                        _openFeature(EditProfileScreen(
                                            currentName: displayName,
                                            currentPhone: displayPhone));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Text("EDIT PROFILE >",
                                            style: GoogleFonts.outfit(
                                                color: const Color(0xFFFF4500),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle),
                              child: avatarUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(35),
                                      child: CachedNetworkImage(
                                          imageUrl: SupabaseConfig.imageUrl(
                                              avatarUrl,
                                              bucket: 'avatars'),
                                          fit: BoxFit.cover,
                                          placeholder: (c, u) =>
                                              const CircularProgressIndicator(),
                                          errorWidget: (c, e, s) => const Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.grey)))
                                  : const Icon(Icons.person,
                                      size: 40, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ... rest of the build logic ...
                      _buildSectionLabel("MY ACCOUNT"),
                      _buildSectionCard([
                        _buildClassicTile(Icons.shopping_bag_outlined, 'Orders',
                            onTap: () {
                          if (widget.onTabChange != null) {
                            widget.onTabChange!(3);
                          }
                        }),
                        _buildDivider(),
                        _buildClassicTile(Icons.favorite_outline, 'Favorites',
                            onTap: () {
                          _openFeature(const FavoritesScreen());
                        }),
                        _buildDivider(),
                        _buildClassicTile(
                            Icons.location_on_outlined, 'My Addresses',
                            onTap: () {
                          _openFeature(const SavedAddressesScreen());
                        }),
                        _buildDivider(),
                        _buildClassicTile(Icons.settings_outlined, 'Settings',
                            onTap: () {
                          _openFeature(const NotificationPreferencesScreen());
                        }),
                      ]),

                      // 3. PAYMENTS & REFUNDS Section
                      _buildSectionLabel("PAYMENTS & REFUNDS"),
                      _buildSectionCard([
                        _buildClassicTile(
                            Icons.credit_card_outlined, 'Refund Status',
                            onTap: () {
                          _openFeature(const RefundStatusScreen());
                        }),
                        _buildDivider(),
                        _buildClassicTile(
                            Icons.credit_card_outlined, 'Payment Modes',
                            onTap: () {
                          _openFeature(const PaymentMethodsScreen());
                        }),
                      ]),

                      // 4. HELP Section
                      _buildSectionLabel("HELP"),
                      _buildSectionCard([
                        _buildClassicTile(
                            Icons.headset_mic_outlined, 'Help & Support',
                            onTap: () {
                          _openFeature(const HelpSupportScreen());
                        }),
                        _buildDivider(),
                        _buildClassicTile(
                            Icons.notifications_none_outlined, 'Notifications',
                            onTap: () {
                          _openFeature(const NotificationsScreen());
                        }),
                      ]),

                      const SizedBox(height: 40),

                      // 5. Logout Button
                      Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _logout();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 24),
                              child: Text("LOGOUT",
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey[700],
              letterSpacing: 0.5)),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildClassicTile(IconData icon, String title,
      {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint(">>> NAV: $title");
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.black.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black87)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: Colors.grey[100],
    );
  }
}
