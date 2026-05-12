import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Qaramia brand tokens.
///
/// The brand is a sunrise-to-crimson arc — gold radiance giving way to
/// devoted love. Colours flow warm only; there are no cool neutrals by design.
class QBrand {
  // ── Core palette ──────────────────────────────────────────────────────────
  static const gold  = Color(0xFFFFD166); // accent — radiance
  static const coral = Color(0xFFFF8A5C); // bridge tone
  static const peach = Color(0xFFFF7043); // primary
  static const rose  = Color(0xFFFF6B81); // inner love
  static const love  = Color(0xFFE94560); // deeper love
  static const deep  = Color(0xFFC9184A); // devotion

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const dark   = Color(0xFF14060C);
  static const wine   = Color(0xFF1F0B14);
  static const card   = Color(0xFF111118);
  static const cream  = Color(0xFFFFF6EC);

  // ── Convenience text colours ──────────────────────────────────────────────
  static const fg     = Colors.white;
  static const fgMute = Color(0x73FFFFFF); // 45% white
  static const fgDim  = Color(0x40FFFFFF); // 25% white

  // ── Gradients (used by mark and wordmark) ─────────────────────────────────
  static const ringGradient = LinearGradient(
    begin: Alignment(-0.7, -1),
    end:   Alignment(0.7, 1),
    colors: [gold, coral, love],
    stops:  [0.0, 0.45, 1.0],
  );

  static const cGradient = LinearGradient(
    begin: Alignment(-0.5, -0.8),
    end:   Alignment(0.5, 0.8),
    colors: [rose, deep],
  );

  static const wordmarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [coral, love],
  );

  /// Radial halo used behind the mark for the radiance effect.
  static const haloGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.6,
    colors: [
      Color(0x73FFD166), // 45% gold
      Color(0x2EFF8A5C), // 18% coral
      Color(0x00FF7043), //  0% peach
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // ── Typography ────────────────────────────────────────────────────────────
  static TextStyle wordmark({double fontSize = 32, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: weight,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.5,
        height: 1.0,
      );

  static TextTheme textTheme() => GoogleFonts.interTextTheme().apply(
        bodyColor: fg,
        displayColor: fg,
      );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData themeData() {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary:   peach,
        secondary: gold,
        tertiary:  love,
        surface:   card,
        error:     deep,
      ),
      scaffoldBackgroundColor: dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: dark,
        foregroundColor: fg,
        elevation: 0,
      ),
      textTheme: textTheme(),
      iconTheme: const IconThemeData(color: fg),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: peach,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: peach, width: 1.5),
        ),
        hintStyle: const TextStyle(color: fgDim),
      ),
    );
  }
}
