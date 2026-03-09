import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProTheme {
  // 🎨 Hyper-Premium Palette
  static const Color primary = Color(0xFFFFD600); // Electric Gold
  static const Color secondary = Color(0xFF00C853); // Vibrant Pulse Green
  static const Color dark = Color(0xFF0F172A); // Midnight Slate
  static const Color surface = Colors.white;
  static const Color bg = Color(0xFFF8FAFC); // Ultra-clean Neutral
  static const Color gray = Color(0xFF64748B); // Cool Gray
  static const Color pureWhite = Colors.white;

  // Status Colors
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // 💎 Glassmorphism & Shadow Tokens
  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: dark.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: dark.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get intenseShadow => [
        BoxShadow(
          color: primary.withOpacity(0.35),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ];

  // 📝 Typography
  static TextStyle get header => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: dark,
        letterSpacing: -1,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: dark,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        color: gray,
        height: 1.6,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: gray,
        letterSpacing: 1.5,
      );

  static TextStyle get button => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      );

  // 🏗️ Global Theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        surface: surface,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.outfitTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: header.copyWith(fontSize: 24),
        iconTheme: const IconThemeData(color: dark, size: 28),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ctaButton),
    );
  }

  // 🔘 Premium Components
  static ButtonStyle get ctaButton => ElevatedButton.styleFrom(
        backgroundColor: dark,
        foregroundColor: pureWhite,
        elevation: 4,
        shadowColor: dark.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      );

  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: dark,
        elevation: 8,
        shadowColor: primary.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      );

  static InputDecoration inputDecor(String hint, IconData icon) =>
      InputDecoration(
        filled: true,
        fillColor: pureWhite,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: gray.withOpacity(0.5), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: dark.withOpacity(0.7), size: 22),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: dark.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      );

  // 🪄 Visual Utilities
  static BoxDecoration get cardDecor => BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: shadow,
      );

  static BoxDecoration get glassDecor => BoxDecoration(
        color: pureWhite.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: pureWhite.withOpacity(0.5)),
        backgroundBlendMode: BlendMode.overlay,
      );
}
