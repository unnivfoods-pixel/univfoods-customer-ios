import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/cart_state.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _isFavorite = false;
  int _quantity = 1;
  String _selectedSize = 'Small';

  // Mock variations for the UI demo (Inline values used below)

  void _addToCart() {
    // Basic Add to Cart Logic
    if (widget.product['vendor_id'] != null) {
      final fakeVendor = {
        'id': widget.product['vendor_id'],
        'name': 'Vendor',
        'address': 'Nearby',
        'latitude': 0.0,
        'longitude': 0.0,
        'zone_id': null
      };

      final vendorRaw = widget.product['vendors'];
      final vendor = vendorRaw is Map<String, dynamic> ? vendorRaw : fakeVendor;

      // Add base item logic (simplified for demo)
      for (int i = 0; i < _quantity; i++) {
        GlobalCart().addItem(widget.product, vendor);
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Added ${widget.product['name']} to cart"),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Data Setup
    final String imageUrl = SupabaseConfig.imageUrl(
        widget.product['image_url'] ?? widget.product['image']);
    final String name = widget.product['name'] ?? 'Cheese Burger';
    final double basePrice = (widget.product['price'] ?? 8.99).toDouble();
    final int calories = widget.product['calories'] ?? 271;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Row (X, Share, Heart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share, size: 24),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : Colors.black,
                        ),
                        onPressed: () =>
                            setState(() => _isFavorite = !_isFavorite),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 10),
                  // 2. Big Image with Floating Price
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        Container(
                          height: 300,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            //  color: Colors.grey[100], // Background for transparent PNGs
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (c, u) =>
                                  Container(color: Colors.grey[50]),
                              errorWidget: (c, e, s) => Container(
                                color: Colors.grey[100],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey, size: 50),
                              ),
                            ),
                          ),
                        ),

                        // Price Tag Pill
                        Positioned(
                          bottom: 20,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(
                                color: ProTheme.primary, // VIBRANT YELLOW
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                )),
                            child: Text(
                              "\$${basePrice.toStringAsFixed(2)}",
                              style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black), // Contrast Text
                            ),
                          ).animate().slideX(begin: -0.5, duration: 400.ms),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Title & Calories
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(LucideIcons.flame,
                              color: ProTheme.secondary,
                              size: 20), // GREEN FLAME
                          const SizedBox(width: 4),
                          Text(
                            "$calories Cal.",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600]),
                          )
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 4. Promo Text
                  Text(
                    "\$0 Delivery fee over \$26",
                    style: GoogleFonts.inter(
                        color: ProTheme.secondary, // GREEN
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                  ),

                  const SizedBox(height: 24),

                  // 5. Ingredients List
                  Text(
                    "Ingredients",
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletText("Juicy beef"),
                  _buildBulletText("Slice of cheddar cheese"),
                  _buildBulletText("Fresh Lettuce"),
                  _buildBulletText("Pickles for crunch"),
                  _buildBulletText("Onions and bacon"),

                  const SizedBox(height: 24),

                  // 6. Variation Radio List
                  Text(
                    "Variation",
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildVariationOption("Small", basePrice),
                  _buildVariationOption("Medium", basePrice + 1.5),
                  _buildVariationOption("Large", basePrice + 3.0),

                  const SizedBox(height: 100), // Space for fab
                ],
              ),
            )
          ],
        ),
      ),

      // 7. Floating Bottom Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 1. Quantity Stepper
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 4,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    _buildStepperBtn(Icons.remove, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    SizedBox(
                      width: 30,
                      child: Text(
                        "$_quantity",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStepperBtn(
                        Icons.add, () => setState(() => _quantity++)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 2. Add to Cart Button
            Expanded(
              child: Material(
                color: ProTheme.primary,
                borderRadius: BorderRadius.circular(20),
                elevation: 4,
                child: InkWell(
                  onTap: () {
                    debugPrint(">>> ACTION: Add to Cart (Final)");
                    _addToCart();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 64,
                    alignment: Alignment.center,
                    child: Text(
                      "Add to Cart",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildBulletText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration:
                const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(text,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVariationOption(String label, double price) {
    final bool isSelected = _selectedSize == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedSize = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Custom Radio
              AnimatedContainer(
                duration: 200.ms,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: isSelected ? ProTheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            isSelected ? ProTheme.primary : Colors.grey[400]!,
                        width: 2)),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const Spacer(),
              Text(
                "\$${price.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        width: 48,
        height: 56,
        child: Icon(icon, color: Colors.black, size: 20), // Dark Icons
      ),
    );
  }
}
