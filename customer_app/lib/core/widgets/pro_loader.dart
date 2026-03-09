import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pro_theme.dart';

class ProLoader extends StatelessWidget {
  final String? message;
  final double size;

  const ProLoader({
    super.key,
    this.message,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Rotating animated border
              SizedBox(
                width: size + 20,
                height: size + 20,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(ProTheme.secondary),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(duration: 2.seconds),
              ),
              // Central Image or Logo
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/loader_partner.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset('assets/univ_logo.png',
                          fit: BoxFit.contain);
                    },
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ProTheme.secondary.withOpacity(0.8),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 1.5.seconds),
          ] else ...[
            const SizedBox(height: 24),
            Text(
              "Currying happiness, on time. 🧡",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 2.seconds),
          ],
        ],
      ),
    );
  }
}

// Global Static Access for easy replacement
class ProOverlayLoader {
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white.withOpacity(0.9),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ProLoader(message: message),
        ),
      ),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
