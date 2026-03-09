import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:latlong2/latlong.dart';
import '../../core/supabase_config.dart';
import '../../core/cart_state.dart';
import '../../core/pro_theme.dart';
import '../../core/razorpay_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/location_service.dart';
import '../../core/profile_store.dart';
import '../../core/widgets/pro_loader.dart';
import '../../core/location_store.dart';

class CartScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const CartScreen({super.key, this.onTabChange});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = GlobalCart();
  bool _placingOrder = false;
  final TextEditingController _instructionController = TextEditingController();
  RazorpayService? _razorpay;

  void _initRazorpay() {
    _razorpay = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
      onExternalWallet: (res) {},
    );
  }

  @override
  void initState() {
    super.initState();
    _cart.load();
  }

  @override
  void dispose() {
    _razorpay?.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  // Store pending order data for UPI flow
  Map<String, dynamic>? _pendingOrderData;

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint(">>> PAY SUCCESS CALLBACK: ${response.paymentId}");
    // 🛡️ DAY 3 COMPLIANCE: No longer updating status from the frontend.
    // The backend webhook will receive the 'payment.captured' event and mark the order as PLACED + SUCCESS.

    try {
      if (mounted) {
        // Stop the placing order loader
        setState(() => _placingOrder = false);

        // Clear local cart (payment completed)
        _cart.clear();

        // 🚀 SUCCESS UI: Immediately show success because Razorpay confirms locally.
        // The Realtime engine in 'orders_screen' will catch the backend update.
        _showSuccessAnimation();
      }
    } catch (e) {
      debugPrint("POST-PAYMENT UI ERROR: $e");
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
          _pendingOrderData = null;
        });
      }
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    debugPrint(">>> PAY FAILURE: ${response.message}");
    if (mounted) {
      setState(() {
        _placingOrder = false;
        _pendingOrderData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Payment Failed: ${response.message}"),
        backgroundColor: Colors.red,
      ));
    }
  }

  final double deliveryFee = 20.0;
  final double platformFee = 5.0;

  double get _itemTotal => _cart.totalPrice;
  double get _gst => _itemTotal * 0.05;
  double get _grandTotal => _itemTotal + deliveryFee + platformFee + _gst;

  String _paymentMethod = "UPI";

  Future<void> _placeOrder() async {
    final store = LocationStore();
    if (store.selectedAddress == "Finding location..." ||
        store.selectedAddress == "Select your location") {
      _showLocationSheet();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a delivery address")));
      return;
    }

    setState(() => _placingOrder = true);

    try {
      final store = LocationStore();
      final lat = store.selectedLocation?.latitude;
      final lng = store.selectedLocation?.longitude;

      if (lat == null || lng == null) {
        throw "Could not determine your location. Please select address again.";
      }

      // STRICT VALIDATION: Ensure phone, house number, and pincode are present
      if (store.phone.isEmpty ||
          store.houseNumber.isEmpty ||
          store.pincode.isEmpty) {
        setState(() => _placingOrder = false);
        _showAddressDetailsDialog(
          lat: lat,
          lng: lng,
          address: store.selectedAddress,
          pincode: store.pincode,
        );
        return;
      }

      final vendor = _cart.currentVendor;
      if (vendor == null) throw "No vendor selected. Please add items first.";

      final String? userId = SupabaseConfig.client.auth.currentUser?.id ??
          SupabaseConfig.forcedUserId;

      if (userId == null || userId.isEmpty) {
        throw "Please login to place an order";
      }

      if (userId.toLowerCase().contains("guest") && userId != "guest_tester") {
        throw "Guest users cannot place orders. Please login with a phone number.";
      }

      if (_cart.items.isEmpty) throw "Your cart is empty.";

      // Build items list
      final itemsJson = _cart.items.entries.map((e) {
        final product = _cart.productDetails[e.key];
        return {
          'product_id': e.key,
          'qty': e.value,
          'name': product?['name'] ?? 'Product',
          'price': product?['discount_price'] ?? product?['price'] ?? 0
        };
      }).toList();

      // Combine full address
      final fullAddr =
          "${store.houseNumber.isNotEmpty ? '${store.houseNumber}, ' : ''}${store.selectedAddress}${store.pincode.isNotEmpty ? ' - ${store.pincode}' : ''}";

      // Build base order data (shared by UPI and COD)
      final Map<String, dynamic> baseOrderData = {
        'customer_id': userId,
        'vendor_id': vendor['id'],
        'items': itemsJson,
        'total': _grandTotal,
        'delivery_address': fullAddr,
        'delivery_lat': lat,
        'delivery_lng': lng,
        'delivery_address_id': (await SharedPreferences.getInstance())
            .getString('selected_address_id'),
        'cooking_instructions': _instructionController.text.trim(),
      };

      // For UPI - Create order first in PAYMENT_PENDING state
      if (_paymentMethod == 'UPI') {
        final orderId =
            await SupabaseConfig.client.rpc('place_order_v21', params: {
          'p_params': {
            'customer_id': userId,
            'vendor_id': vendor['id'].toString(),
            'lat': lat,
            'lng': lng,
            'total': _grandTotal,
            'items': itemsJson,
            'payment_method': 'UPI',
            'address': fullAddr,
            'pincode': store.pincode,
            'customer_phone': store.phone,
          }
        });

        _pendingOrderData = {...baseOrderData, 'id': orderId.toString()};
        _initRazorpay();

        final profileRes = await SupabaseConfig.client
            .from('customer_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        _razorpay?.openCheckout(
          amount: _grandTotal,
          description: "Order #${orderId.toString().substring(0, 6)}",
          email: profileRes?['email'] ?? "customer@univfoods.in",
          phone: store.phone.isNotEmpty
              ? store.phone
              : (profileRes?['phone'] ?? "9876543210"),
        );
        return;
      }
      // For COD - direct insert via RPC
      await SupabaseConfig.client.rpc('place_order_stabilized_v4', params: {
        'p_customer_id': SupabaseConfig.currentUid,
        'p_vendor_id': _cart.currentVendor?['id']?.toString(), // Ensure string
        'p_items': itemsJson,
        'p_total': _grandTotal,
        'p_address':
            "${store.houseNumber.isNotEmpty ? '${store.houseNumber}, ' : ''}${store.selectedAddress}",
        'p_lat': lat ?? store.selectedLocation?.latitude,
        'p_lng': lng ?? store.selectedLocation?.longitude,
        'p_instructions': _instructionController.text.trim(),
        'p_payment_method': 'COD',
        'p_payment_status': 'PENDING',
        'p_address_id': null, // Explicit null for exact signature match
        'p_payment_id': null // Explicit null for exact signature match
      }).timeout(const Duration(seconds: 20));

      // _syncLocalOrder removed for Day 2 compliance.
      _cart.clear();

      if (mounted) {
        setState(() => _placingOrder = false);
        _showSuccessAnimation();
      }

      // 🚀 Background sync AFTER navigating to success screen to keep it snappy
      Future.delayed(
          const Duration(milliseconds: 500), () => SupabaseConfig.bootstrap());
    } catch (e) {
      debugPrint(">>> [ORDER FAILED] Full Error Trace: $e");
      if (mounted) {
        String displayError = "Could not place order.";
        final errStr = e.toString();

        if (errStr.contains('OUT_OF_RADIUS')) {
          displayError =
              "This shop is too far from your location. Please choose another address.";
        } else if (errStr.contains('SHOP_CLOSED')) {
          displayError =
              "This restaurant just closed. Please try another shop.";
        } else if (errStr.contains('MISSING_COORDINATES')) {
          displayError =
              "Location error. Please re-select your address on the Home screen.";
        } else if (errStr.contains("permission denied")) {
          displayError =
              "Permission Denied: Your account might be restricted or you need to re-login.";
        } else {
          displayError = "Order failed: $e";
        }

        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayError), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted && _paymentMethod != 'UPI') {
        setState(() => _placingOrder = false);
      }
    }
  }

  void _showSuccessAnimation() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) => SuccessScreen(onTabChange: widget.onTabChange)),
      (route) => false,
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text('Deliver To', style: ProTheme.header.copyWith(fontSize: 20)),
              const SizedBox(height: 16),
              Material(
                color: ProTheme.bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(context);
                    final pos = await LocationService.getCurrentPosition();
                    if (pos != null) {
                      final details =
                          await LocationService.getDetailedAddressFromLatLng(
                              pos.latitude, pos.longitude);

                      final String addr = details['full_address'] ??
                          await LocationService.getAddressFromLatLng(
                              pos.latitude, pos.longitude);

                      if (mounted) {
                        _showAddressDetailsDialog(
                          lat: pos.latitude,
                          lng: pos.longitude,
                          address: addr,
                          pincode: details['postcode'] ?? '',
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: ProTheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.my_location_rounded,
                              color: ProTheme.secondary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text('Use Current Location',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('SAVED ADDRESSES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              // Real-time stream from Supabase — same source as Profile page
              Flexible(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: () {
                    final uid = SupabaseConfig.client.auth.currentUser?.id ??
                        SupabaseConfig.forcedUserId;
                    if (uid == null || uid.isEmpty || uid.contains('guest')) {
                      return Stream.value(<Map<String, dynamic>>[]);
                    }
                    return SupabaseConfig.client
                        .from('user_addresses')
                        .stream(primaryKey: ['id']).eq('user_id', uid);
                  }(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: ProLoader(
                                message: "Fetching your addresses...")),
                      );
                    }
                    final addresses = snapshot.data ?? [];
                    if (addresses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No saved addresses.\nAdd them in Profile → My Addresses.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx2, i) {
                        final addr = addresses[i];
                        final label = addr['label'] ?? 'Address';
                        final line = addr['address_line'] ?? '';
                        final icon = label == 'Home'
                            ? Icons.home_rounded
                            : label == 'Work'
                                ? Icons.work_rounded
                                : Icons.location_on_rounded;
                        return Material(
                          color: ProTheme.bg,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              Navigator.pop(context);
                              final String h =
                                  addr['house_number']?.toString() ?? '';
                              final String p =
                                  addr['pincode']?.toString() ?? '';
                              final String ph = (addr['phone'] ??
                                          addr['phone_number'] ??
                                          addr['phone_number_snapshot'])
                                      ?.toString() ??
                                  '';

                              if (h.isEmpty || p.isEmpty || ph.isEmpty) {
                                // Missing details? Show the verification dialog
                                _showAddressDetailsDialog(
                                  label: label,
                                  lat: (addr['latitude'] as num?)?.toDouble() ??
                                      0,
                                  lng:
                                      (addr['longitude'] as num?)?.toDouble() ??
                                          0,
                                  address: line,
                                  pincode: p,
                                );
                              } else {
                                // All good? Set it
                                _setAddress(label, line,
                                    pin: p,
                                    house: h,
                                    phone: ph,
                                    id: addr['id']?.toString(),
                                    lat: (addr['latitude'] as num?)?.toDouble(),
                                    lng: (addr['longitude'] as num?)
                                        ?.toDouble());
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color:
                                            ProTheme.primary.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Icon(icon,
                                        color: ProTheme.secondary, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(label,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                        if (line.isNotEmpty)
                                          Text(
                                            "$line${addr['house_number'] != null ? ', ${addr['house_number']}' : ''}${addr['pincode'] != null ? ', ${addr['pincode']}' : ''}\nPhone: ${addr['phone'] ?? addr['phone_number'] ?? 'N/A'}",
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddressDetailsDialog({
    String label = 'Current Location',
    required double lat,
    required double lng,
    required String address,
    required String pincode,
  }) async {
    final store = LocationStore();
    final houseCtrl = TextEditingController(text: store.houseNumber);
    final pinCtrl = TextEditingController(
        text: pincode.isNotEmpty ? pincode : store.pincode);
    final phoneCtrl = TextEditingController(
        text: store.phone.isNotEmpty
            ? store.phone
            : (ProfileStore().profile?['phone'] ?? ''));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Details',
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(address,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[600])),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showLocationSheet();
                  },
                  child: const Text("Change",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: houseCtrl,
              label: 'HOUSE / FLAT / BUILDING NUMBER *',
              hint: 'e.g. Flat 402, Sai Residency',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: pinCtrl,
                    label: 'PINCODE *',
                    hint: '6-digit code',
                    icon: Icons.pin_drop_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: phoneCtrl,
                    label: 'CONTACT PHONE *',
                    hint: '10-digit number',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (houseCtrl.text.isEmpty ||
                      pinCtrl.text.isEmpty ||
                      phoneCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text("Please fill all required fields (*)")));
                    return;
                  }
                  Navigator.pop(ctx);
                  _setAddress(
                    label,
                    address,
                    house: houseCtrl.text.trim(),
                    pin: pinCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    lat: lat,
                    lng: lng,
                  );
                },
                child: Text('Confirm Delivery Location',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey[600],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(icon, size: 20, color: ProTheme.primary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _setAddress(String label, String sub,
      {String? pin,
      String? house,
      String? phone,
      String? id,
      double? lat,
      double? lng}) async {
    final store = LocationStore();
    final finalLat = lat ?? store.selectedLocation?.latitude ?? 0;
    final finalLng = lng ?? store.selectedLocation?.longitude ?? 0;

    await store.updateLocation(
      LatLng(finalLat, finalLng),
      sub,
      label,
      house: house ?? '',
      pincode: pin ?? '',
      phone: phone ?? '',
    );

    if (id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_address_id', id);
    }

    // Force a small delay and a local setState for transition stability
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isStandalone = ModalRoute.of(context)?.settings.name == '/cart';

    Widget bodyContent = ListenableBuilder(
      listenable: Listenable.merge([_cart, LocationStore()]),
      builder: (context, _) => _cart.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          )
                        ],
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          size: 80, color: ProTheme.primary.withOpacity(0.5)),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 32),
                    Text('Your cart is empty',
                        style: ProTheme.header.copyWith(fontSize: 22)),
                    const SizedBox(height: 12),
                    Text(
                        'Looks like you haven\'t added any curries to your cart yet.',
                        textAlign: TextAlign.center,
                        style: ProTheme.body.copyWith(color: Colors.grey[500])),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.onTabChange != null) {
                            widget.onTabChange!(0);
                          } else {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 8,
                          shadowColor: ProTheme.primary.withOpacity(0.4),
                        ),
                        child: Text(
                          'START BROWSING',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).moveY(begin: 30, end: 0),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // ── Delivery Address ──────────────────────────────────
                      Material(
                        color: ProTheme.bg,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final store = LocationStore();
                            if (store.selectedAddress ==
                                    "Finding location..." ||
                                store.selectedAddress ==
                                    "Select your location") {
                              _showLocationSheet();
                            } else {
                              _showAddressDetailsDialog(
                                label: store.selectedLabel,
                                lat: store.selectedLocation?.latitude ?? 0,
                                lng: store.selectedLocation?.longitude ?? 0,
                                address: store.selectedAddress,
                                pincode: store.pincode,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: ProTheme.primary.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on_rounded,
                                      color: ProTheme.secondary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Deliver to',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12)),
                                      Text(LocationStore().selectedLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      if (LocationStore()
                                              .selectedAddress
                                              .isNotEmpty &&
                                          LocationStore().selectedAddress !=
                                              "Select your location")
                                        Text(
                                            "${LocationStore().houseNumber.isNotEmpty ? '${LocationStore().houseNumber}, ' : ''}${LocationStore().selectedAddress}${LocationStore().pincode.isNotEmpty ? ', ${LocationStore().pincode}' : ''}\nPhone: ${LocationStore().phone}",
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Your Order ────────────────────────────────────────
                      Text('Your Order',
                          style: ProTheme.title.copyWith(fontSize: 16)),
                      const SizedBox(height: 12),
                      ..._cart.items.entries.map((e) {
                        final p = _cart.productDetails[e.key];
                        final imgUrl = SupabaseConfig.imageUrl(
                            p?['image_url'] ?? p?['image']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: ProTheme.softShadow,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.grey[50]),
                                    errorWidget: (context, url, err) =>
                                        _cartItemPlaceholder()),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p?['name'] ?? 'Item',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '₹${((p?['price'] ?? 0) * e.value).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: ProTheme.secondary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15)),
                                  ],
                                ),
                              ),
                              // Quantity stepper
                              Container(
                                decoration: BoxDecoration(
                                  color: ProTheme.bg,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () => _cart.removeItem(e.key),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.remove_rounded,
                                              size: 18,
                                              color: ProTheme.secondary),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text('${e.value}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16)),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () => _cart.addItem(
                                            p, _cart.currentVendor!),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.add_rounded,
                                              size: 18,
                                              color: ProTheme.secondary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // ── Cooking Instructions ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: ProTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.restaurant_menu_rounded,
                                    size: 18, color: ProTheme.secondary),
                                const SizedBox(width: 8),
                                Text('Cooking Instructions',
                                    style:
                                        ProTheme.title.copyWith(fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _instructionController,
                              maxLines: 2,
                              style: ProTheme.body,
                              decoration: InputDecoration(
                                hintText:
                                    'Any special requests? (e.g. less spicy)',
                                hintStyle: ProTheme.body
                                    .copyWith(color: Colors.grey[400]),
                                filled: true,
                                fillColor: ProTheme.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Bill Summary ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: ProTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bill Summary',
                                style: ProTheme.title.copyWith(fontSize: 16)),
                            const SizedBox(height: 16),
                            _buildBillRow('Item Total', _itemTotal),
                            _buildBillRow('Delivery Fee', deliveryFee),
                            _buildBillRow('Platform Fee', platformFee),
                            _buildBillRow('GST (5%)', _gst),
                            const Divider(height: 24),
                            _buildBillRow('Total Amount', _grandTotal,
                                isTotal: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom Action ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(15), blurRadius: 20)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildPayOption(
                                  'UPI', _paymentMethod == 'UPI')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildPayOption(
                                  'COD', _paymentMethod == 'COD')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: ProTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _placingOrder ? null : _placeOrder,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            child: _placingOrder
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    'PLACE ORDER  •  ₹${_grandTotal.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Checkout', style: ProTheme.header.copyWith(fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading:
            isStandalone ? const BackButton(color: ProTheme.secondary) : null,
      ),
      body: bodyContent,
    );
  }

  Widget _cartItemPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: ProTheme.bg,
      child: const Icon(Icons.restaurant_rounded, color: ProTheme.secondary),
    );
  }

  Widget _buildBillRow(String label, double val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isTotal ? ProTheme.dark : Colors.grey[600],
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                  fontSize: isTotal ? 17 : 14)),
          Text('₹${val.toStringAsFixed(2)}',
              style: TextStyle(
                  color: isTotal ? ProTheme.dark : Colors.grey[700],
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                  fontSize: isTotal ? 17 : 14)),
        ],
      ),
    );
  }

  Widget _buildPayOption(String type, bool selected) {
    return Material(
      color: selected ? ProTheme.secondary : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Text(type,
              style: TextStyle(
                  color: selected ? Colors.white : ProTheme.dark,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ),
      ),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  final Function(int)? onTabChange;
  const SuccessScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home',
                (route) => false,
                arguments: {'index': 0},
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 100),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 32),
              Text("Order Placed!",
                  style: ProTheme.header.copyWith(fontSize: 28)),
              const SizedBox(height: 12),
              Text(
                "Your delicious meal is being prepared and will be with you soon.",
                textAlign: TextAlign.center,
                style: ProTheme.body.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // 🚀 ROBUST NAVIGATION: Go back to Home and force-select the Orders tab (index 3)
                    try {
                      if (onTabChange != null) {
                        onTabChange!(3);
                      }
                    } catch (e) {
                      debugPrint(">>> [NAV] onTabChange Error: $e");
                    }

                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                      arguments: {'index': 3},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: ProTheme.primary.withOpacity(0.4),
                  ),
                  child: const Text("TRACK ORDER",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1)),
                ),
              ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (route) => false,
                    arguments: {'index': 0},
                  );
                },
                child: Text(
                  "Explore More Food 🍛",
                  style: GoogleFonts.outfit(
                      color: ProTheme.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
