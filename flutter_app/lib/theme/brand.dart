import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Qaramia brand tokens — light + bright palette.
///
/// Sunrise-to-crimson accents on warm cream surfaces. The hue family stays
/// the same as the dark theme (gold → peach → love → crimson) so the logo
/// and gradients remain on-brand; only the surfaces invert.
class QBrand {
  // ── Accent palette (unchanged from dark theme — these are the brand) ──────
  static const gold   = Color(0xFFFFD166); // sun
  static const coral  = Color(0xFFFF8A5C); // bridge
  static const peach  = Color(0xFFFF7043); // primary
  static const rose   = Color(0xFFFF6B81); // pink
  static const love   = Color(0xFFE94560); // hot
  static const deep   = Color(0xFFC9184A); // devotion

  // ── Surfaces (the change: light + warm instead of dark + moody) ───────────
  static const bg     = Color(0xFFFFF8F0); // soft warm cream — main scaffold
  static const card   = Color(0xFFFFFFFF); // pure white — cards
  static const cardAlt= Color(0xFFFFEFE2); // peach-tinted cream — secondary surface
  static const hairline = Color(0xFFEED8C8); // soft border tone

  // ── Foreground text colours (dark on the light surfaces) ──────────────────
  static const fg     = Color(0xFF1F0B14); // dark wine — primary text
  static const fgMute = Color(0xFF6B4A55); // warm grey — secondary text
  static const fgDim  = Color(0xFF9C7A85); // even softer — tertiary / labels

  // ── Dark variants (used by live-stream chrome where video reads better) ──
  static const darkSurface = Color(0xFF14060C);
  static const wineSurface = Color(0xFF1F0B14);
  static const cardOnDark  = Color(0xFF1A1A2E);

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
    final base = ThemeData.light();
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary:    peach,
        onPrimary:  Colors.white,
        secondary:  gold,
        onSecondary: fg,
        tertiary:   love,
        onTertiary: Colors.white,
        surface:    card,
        onSurface:  fg,
        error:      deep,
        onError:    Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: textTheme(),
      iconTheme: const IconThemeData(color: fg),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: peach,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: peach,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: peach.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? peach : fgMute,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? peach : fgMute,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: peach, width: 1.5),
        ),
        labelStyle: const TextStyle(color: fgMute),
        hintStyle: const TextStyle(color: fgDim),
        prefixIconColor: fgMute,
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: fg,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
