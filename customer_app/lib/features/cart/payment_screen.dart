import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final Function(String method) onPaymentSelected;

  const PaymentScreen(
      {super.key, required this.totalAmount, required this.onPaymentSelected});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Payment Options",
                style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text("Total: ₹${widget.totalAmount}",
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // UPI Apps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Pay by any UPI App",
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _paymentTile("Google Pay", "gpay",
                      iconUrl:
                          "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png"),
                  const Divider(height: 1, indent: 60),
                  _paymentTile("PhonePe UPI", "phonepe",
                      subtitle:
                          "Flat ₹50 cashback on first ever RuPay Credit Card on UPI transaction above ₹199",
                      subtitleColor: Colors.green[700],
                      iconUrl:
                          "https://download.logo.wine/logo/PhonePe/PhonePe-Logo.wine.png"),
                  const Divider(height: 1, indent: 60),
                  _paymentTile("Paytm UPI", "paytm",
                      subtitle:
                          "₹30 to ₹300 Cashback on First Ever New Paytm Txn",
                      subtitleColor: Colors.green[700],
                      iconUrl:
                          "https://download.logo.wine/logo/Paytm/Paytm-Logo.wine.png"),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    onTap: () => _showAddUpiDialog(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add, color: Colors.deepOrange),
                    ),
                    title: Text("Add New UPI ID",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text("You need to have a registered UPI ID",
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.grey)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.keyboard_arrow_down,
                      color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Text("View all UPI options",
                      style: GoogleFonts.inter(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))
                ],
              ),
            ),

            // Credit Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Credit & Debit Cards",
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4)),
                  child:
                      const Icon(Icons.add, color: Colors.deepOrange, size: 20),
                ),
                title: Text("Add New Card",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                        fontSize: 14)),
                subtitle: Text("Save and Pay via Cards.",
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
              ),
            ),

            const SizedBox(height: 24),

            // More Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("More Payment Options",
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _simpleOption("Pay on Delivery", "Pay in cash or pay online",
                      LucideIcons.banknote),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(String title, String id,
      {String? subtitle, Color? subtitleColor, String? iconUrl}) {
    return ListTile(
      onTap: () {
        setState(() => _selectedMethod = id);
        _confirmPayment(id);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8)),
        child: iconUrl != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: CachedNetworkImage(
                    imageUrl: iconUrl,
                    placeholder: (c, u) => const SizedBox(),
                    errorWidget: (c, e, s) => const Icon(Icons.payment)))
            : const Icon(Icons.payment, color: Colors.grey),
      ),
      title: Text(title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 10, color: subtitleColor ?? Colors.grey))
          : null,
      trailing: Radio<String>(
        value: id,
        groupValue: _selectedMethod,
        activeColor: Colors.deepOrange,
        onChanged: (v) {
          if (v != null) {
            setState(() => _selectedMethod = v);
            _confirmPayment(v);
          }
        },
      ),
    );
  }

  Widget _simpleOption(String title, String subtitle, IconData icon) {
    return ListTile(
      onTap: () {
        // Map titles to IDs if needed, or just return title
        String id = title;
        if (title == "Pay on Delivery") id = "COD";
        setState(() => _selectedMethod = id);
        _confirmPayment(id);
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, color: Colors.grey[700], size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  void _showAddUpiDialog() {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Enter UPI ID"),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                    hintText: "e.g. user@oksbi",
                    border: OutlineInputBorder(),
                    labelText: "UPI ID"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCEL")),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      Navigator.pop(ctx);
                      _confirmPayment("UPI:${controller.text}");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange),
                  child: const Text("VERIFY & PAY"),
                )
              ],
            ));
  }

  void _confirmPayment(String method) {
    // For now, auto-select and simulate navigation back or processing
    widget.onPaymentSelected(method);
    Navigator.pop(context, method);
  }
}
