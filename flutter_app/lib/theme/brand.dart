import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Qaramia brand tokens — clean white + indigo (template-aligned).
///
/// Visual language: near-white surfaces, indigo primary, black CTA pills,
/// gold stars, soft pill chips, hairline dividers. Live-stream chrome keeps
/// dark surfaces so overlays still read on top of video.
class QBrand {
  // ── Primary palette (indigo, eyedropped from template) ───────────────────
  static const primary    = Color(0xFF3830CC); // electric indigo — buttons, prices, links
  static const primaryDim = Color(0xFFD0D0F8); // pastel indigo — voucher banners, tints
  static const primaryDeep= Color(0xFF2C2898); // pressed/active state

  // ── Accents (used sparingly — stars, live badge, "Seller" tag) ───────────
  static const gold   = Color(0xFFFFB400); // amber — star ratings
  static const love   = Color(0xFFE94560); // red — live badge, hearts
  static const seller = Color(0xFF22C55E); // green — "Seller" pill
  static const deep   = Color(0xFFC9184A); // crimson — errors/warnings

  // ── Brand gradient family (used by logo + signup hero) ───────────────────
  static const coral  = Color(0xFFFF8A5C);
  static const peach  = Color(0xFFFF7043);
  static const rose   = Color(0xFFFF6B81);

  // ── Surfaces (white-first, with subtle grey for inputs) ──────────────────
  static const bg       = Color(0xFFFFFFFF); // pure white scaffold
  static const card     = Color(0xFFFFFFFF); // cards = same as bg, separated by hairlines
  static const cardAlt  = Color(0xFFF4F5F7); // light cool grey — input fills, secondary surface
  static const hairline = Color(0xFFE5E7EB); // subtle dividers
  static const surround = Color(0xFFE4E8EC); // page surround / app shell grey

  // ── Foreground text colours ──────────────────────────────────────────────
  static const fg     = Color(0xFF0F1115); // near-black — primary text + CTA pill bg
  static const fgMute = Color(0xFF6B7280); // mid-grey — secondary text
  static const fgDim  = Color(0xFF9CA3AF); // light grey — tertiary/labels

  // ── Dark variants (live-stream chrome, video overlays) ───────────────────
  static const darkSurface = Color(0xFF14060C);
  static const wineSurface = Color(0xFF1F0B14);
  static const cardOnDark  = Color(0xFF1A1A2E);

  // ── Gradients (logo mark + wordmark — kept warm so brand stays recognisable)
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

  static const haloGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.6,
    colors: [
      Color(0x73FFD166),
      Color(0x2EFF8A5C),
      Color(0x00FF7043),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // ── Typography ───────────────────────────────────────────────────────────
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

  // ── Theme ────────────────────────────────────────────────────────────────
  static ThemeData themeData() {
    final base = ThemeData.light();
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary:     primary,
        onPrimary:   Colors.white,
        secondary:   primary,
        onSecondary: Colors.white,
        tertiary:    gold,
        onTertiary:  fg,
        surface:     card,
        onSurface:   fg,
        error:       love,
        onError:     Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: textTheme(),
      iconTheme: const IconThemeData(color: fg),
      // Primary CTA = black pill (matches template "Checkout now")
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // ElevatedButton (legacy callers) = indigo pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: const BorderSide(color: hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairline, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? primary : fgMute,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : fgMute,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: fgMute),
        hintStyle: const TextStyle(color: fgDim),
        prefixIconColor: fgMute,
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: cardAlt,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: fg, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: fg,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
