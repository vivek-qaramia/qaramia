import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/brand.dart';

/// The Qaramia mark — a Q ring enclosing a C.
///
/// Renders the bundled SVG (assets/branding/qaramia-mark.svg) at the requested
/// size, optionally with a soft drop-shadow halo for emphasis on dark surfaces.
class LogoMark extends StatelessWidget {
  final double size;
  final bool glow;

  const LogoMark({super.key, this.size = 36, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final svg = SvgPicture.asset(
      'assets/branding/qaramia-mark.svg',
      width: size,
      height: size,
    );
    if (!glow) return svg;
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x55E94560),
            blurRadius: 40,
            spreadRadius: -4,
          ),
        ],
      ),
      child: svg,
    );
  }
}

/// The full Qaramia lockup — mark on the left, italic wordmark on the right.
///
/// Use this in app bars, login hero, etc. Renders an inline italic Playfair
/// Display "qara-mia!" with a coral-to-love gradient.
class LogoLockup extends StatelessWidget {
  final double markSize;
  final double wordmarkSize;
  final bool glow;

  const LogoLockup({
    super.key,
    this.markSize = 32,
    this.wordmarkSize = 24,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LogoMark(size: markSize, glow: glow),
        const SizedBox(width: 8),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => QBrand.wordmarkGradient.createShader(rect),
          child: Text(
            'qara-mia!',
            style: QBrand.wordmark(fontSize: wordmarkSize),
          ),
        ),
      ],
    );
  }
}
