import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProTheme {
  // Colors (Customer Orange/Amber)
  // Colors
  // Removing old definition in favor of new one below

  // 🎨 Ultra Premium Color Palette
  // 🎨 Client Request: Main Yellow, Background Green (Curry Theme)
  static const Color primary =
      Color(0xFFFFD600); // Vibrant Yellow (Turmeric/Gold)
  static const Color secondary =
      Color(0xFF1B5E20); // Deep Forest Green (Text/Icons)
  static const Color accent = Color(0xFF64DD17); // Bright Lime Green

  static const Color bg = Colors.white; // Reverted to Pure White as requested
  static const Color surface = Colors.white; // Surface stays white for cards
  static const Color dark =
      Color(0xFF003300); // Very Dark Green for high contrast text
  static const Color gray = Color(0xFFA4B0BE);
  static const Color success = Color(0xFF2ED573);
  static const Color error = Color(0xFFFF5252);
  static const Color white = Colors.white; // Added back for compatibility

  // Backwards compatibility alias
  static List<BoxShadow> get shadow => softShadow;

  // Typography
  static TextStyle get display => GoogleFonts.outfit(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: dark,
      letterSpacing: -1.0);

  // 🌈 Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFD600), Color(0xFFFFA000)], // Yellow to Amber
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF1F8E9)], // White to faint Green
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ✒️ Typography (Google Fonts: Outfit + Inter)
  static TextStyle get header => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: dark,
        letterSpacing: -0.5,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: dark,
        letterSpacing: -0.3,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF57606F),
        height: 1.5,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: dark,
        letterSpacing: 1.5,
      );

  static TextStyle get button => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  // 🖼️ Shadows & Decors
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: dark.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get hoverShadow => [
        BoxShadow(
          color: primary.withOpacity(0.25),
          blurRadius: 25,
          offset: const Offset(0, 10),
          spreadRadius: 2,
        ),
      ];

  // 🧊 Input Decorations
  static InputDecoration inputDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: body.copyWith(color: gray),
      prefixIcon: Icon(icon, color: gray.withOpacity(0.8)),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    );
  }

  // 🔘 Button Styles
  static ButtonStyle get ctaButton => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shadowColor: primary.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: 8,
      );

  // Custom button wrapper needed since gradients aren't supported directly in styleFrom
}
