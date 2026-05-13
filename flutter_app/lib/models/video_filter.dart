import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// A camera-stream filter preset.
///
/// Two effect channels are combined per preset:
///   * [colorMatrix] — 20-element (4x5) matrix passed to Flutter's
///     `ColorFilter.matrix(...)` wrapping the AgoraVideoView. Null means
///     identity (no overlay).
///   * [beautyOptions] — Agora native beauty filter applied via the engine's
///     `setBeautyEffectOptions`. Null means beauty disabled.
///
/// Color matrix layout (per row, applied to RGBA):
///   [ Rr Rg Rb Ra Rconst,
///     Gr Gg Gb Ga Gconst,
///     Br Bg Bb Ba Bconst,
///     Ar Ag Ab Aa Aconst ]
class VideoFilter {
  final String id;
  final String name;
  final String emoji;
  final List<double>? colorMatrix;
  final BeautyOptions? beautyOptions;

  const VideoFilter({
    required this.id,
    required this.name,
    required this.emoji,
    this.colorMatrix,
    this.beautyOptions,
  });

  bool get hasBeauty => beautyOptions != null;
  bool get hasColorOverlay => colorMatrix != null;

  // ── Catalogue ────────────────────────────────────────────────────────────
  static const List<VideoFilter> all = [
    VideoFilter(id: 'none', name: 'Normal', emoji: '⚪'),

    // Beauty: Agora native skin smoothing + slight lightening + warm tone.
    // Tuned to match what creators expect from TikTok / Snapchat defaults.
    VideoFilter(
      id: 'beauty',
      name: 'Beauty',
      emoji: '✨',
      beautyOptions: BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.55,
        smoothnessLevel: 0.6,
        rednessLevel: 0.25,
        sharpnessLevel: 0.5,
      ),
    ),

    // Warm: boost red + slight saturation, gentle blue reduction.
    VideoFilter(
      id: 'warm',
      name: 'Warm',
      emoji: '🌅',
      colorMatrix: [
        1.10, 0.05, 0.00, 0.0, 0.0,
        0.00, 1.05, 0.00, 0.0, 0.0,
        0.00, 0.00, 0.92, 0.0, 0.0,
        0.00, 0.00, 0.00, 1.0, 0.0,
      ],
    ),

    // Cool: shift blue up, slight green-channel ghosting for cinematic teal.
    VideoFilter(
      id: 'cool',
      name: 'Cool',
      emoji: '❄️',
      colorMatrix: [
        0.92, 0.00, 0.05, 0.0, 0.0,
        0.00, 1.00, 0.05, 0.0, 0.0,
        0.05, 0.00, 1.15, 0.0, 0.0,
        0.00, 0.00, 0.00, 1.0, 0.0,
      ],
    ),

    // Noir: BT.601 luma weights — proper grayscale plus a touch of contrast
    // via the rec-709-ish 0.299/0.587/0.114 split.
    VideoFilter(
      id: 'noir',
      name: 'Noir',
      emoji: '🎞',
      colorMatrix: [
        0.299, 0.587, 0.114, 0.0, 0.0,
        0.299, 0.587, 0.114, 0.0, 0.0,
        0.299, 0.587, 0.114, 0.0, 0.0,
        0.000, 0.000, 0.000, 1.0, 0.0,
      ],
    ),

    // Cinema: teal/orange grade — boost red highlights, dim blue, pull green
    // toward teal. Classic Hollywood look.
    VideoFilter(
      id: 'cinema',
      name: 'Cinema',
      emoji: '🎬',
      colorMatrix: [
        1.12, -0.05, 0.00, 0.0,  0.0,
        0.00, 0.95, -0.05, 0.0,  0.0,
        -0.05, 0.00, 0.90, 0.0,  0.0,
        0.00, 0.00, 0.00,  1.0,  0.0,
      ],
    ),
  ];

  static VideoFilter byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);
}
