import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Draws editor overlays (vignette, text, emoji sticker) to full-frame
/// transparent PNGs so FFmpeg can composite them onto the video. Drawing in
/// Flutter avoids needing a font file and colour-emoji support in FFmpeg.
/// Sizes are authored in logical pixels for a ~[_refWidth]-wide preview, so
/// everything is scaled by width / [_refWidth] to look the same on the video.
class EffectsOverlayRenderer {
  static const _refWidth = 320.0;
  static const _uuid = Uuid();

  /// Same factor used to scale blur sigma so it matches the preview.
  static double scaleFor(int width) => width / _refWidth;

  static Future<String> vignette(int w, int h, double intensity) {
    return _render(w, h, (canvas) {
      final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
      final shader = RadialGradient(
        radius: 1.0,
        colors: [
          const Color(0x00000000),
          Color.fromRGBO(0, 0, 0, intensity),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, ui.Paint()..shader = shader);
    });
  }

  static Future<String> text(String text, int w, int h) {
    final k = scaleFor(w);
    return _centered(
      w,
      h,
      TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: 26 * k,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              offset: Offset(0, 1.5 * k),
              blurRadius: 4 * k,
              color: const Color(0xDD000000),
            ),
          ],
        ),
      ),
      maxWidth: w - 48 * k,
    );
  }

  static Future<String> sticker(String emoji, int w, int h) {
    return _centered(
      w,
      h,
      TextSpan(text: emoji, style: TextStyle(fontSize: 80 * scaleFor(w))),
    );
  }

  static Future<String> _centered(int w, int h, TextSpan span, {double? maxWidth}) {
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth ?? w.toDouble());
    return _render(w, h, (canvas) {
      tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
    });
  }

  static Future<String> _render(int w, int h, void Function(ui.Canvas) draw) async {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder));
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final tmp = await getTemporaryDirectory();
    final path = '${tmp.path}/overlay_${_uuid.v4()}.png';
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    return path;
  }
}
