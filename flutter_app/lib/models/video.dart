import 'package:cloud_firestore/cloud_firestore.dart';

/// An emoji sticker shown over the video between [startMs] and [endMs].
/// Renders as a large centred glyph (80px) so it's visible at a glance.
/// Position-on-frame and per-sticker scale are out of scope for v1.
class StickerOverlay {
  final String emoji;
  final double startMs;
  final double endMs;
  const StickerOverlay({
    required this.emoji,
    required this.startMs,
    required this.endMs,
  });
  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'startMs': startMs,
        'endMs': endMs,
      };
  factory StickerOverlay.fromJson(Map<String, dynamic> json) => StickerOverlay(
        emoji: json['emoji'] as String,
        startMs: (json['startMs'] as num).toDouble(),
        endMs: (json['endMs'] as num).toDouble(),
      );
}

/// A text overlay shown over the video between [startMs] and [endMs].
/// Position is centered for v1 (no per-overlay position/colour/size). Text
/// renders above all visual effects so it stays crisp regardless of blur,
/// colour grading, or zoom.
class TextOverlay {
  final String text;
  final double startMs;
  final double endMs;
  const TextOverlay({
    required this.text,
    required this.startMs,
    required this.endMs,
  });
  Map<String, dynamic> toJson() => {
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
      };
  factory TextOverlay.fromJson(Map<String, dynamic> json) => TextOverlay(
        text: json['text'] as String,
        startMs: (json['startMs'] as num).toDouble(),
        endMs: (json['endMs'] as num).toDouble(),
      );
}

/// A single zoom-at-point marker. The video animates a Transform.scale
/// from 1.0 → [scale] and back over [durationMs], starting at [timeMs]
/// (measured from the start of the published file).
class ZoomMarker {
  final double timeMs;
  final double scale;
  final double durationMs;
  const ZoomMarker({
    required this.timeMs,
    required this.scale,
    this.durationMs = 2000,
  });
  Map<String, dynamic> toJson() => {
        'timeMs': timeMs,
        'scale': scale,
        'durationMs': durationMs,
      };
  factory ZoomMarker.fromJson(Map<String, dynamic> json) => ZoomMarker(
        timeMs: (json['timeMs'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
        durationMs: (json['durationMs'] as num?)?.toDouble() ?? 2000,
      );
}

class Video {
  final String id;
  final String authorUid;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final String? audioTitle;
  final String filterId;
  // Zero or more zoom markers. Each fires independently at its timestamp.
  // Markers are sorted by timeMs for predictable rendering when windows
  // overlap (earlier marker wins).
  final List<ZoomMarker> zooms;
  // Gaussian blur sigma applied to the whole frame. 0 = no blur.
  final double blurAmount;
  // Radial-vignette opacity at the corners. 0 = no vignette, 1 = solid.
  final double vignetteIntensity;
  // Zero or more text overlays, each visible during its own time window.
  final List<TextOverlay> textOverlays;
  // Emoji stickers shown over the video at their respective time windows.
  final List<StickerOverlay> stickers;
  final DateTime createdAt;

  const Video({
    required this.id,
    required this.authorUid,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.audioTitle,
    this.filterId = 'none',
    this.zooms = const [],
    this.blurAmount = 0,
    this.vignetteIntensity = 0,
    this.textOverlays = const [],
    this.stickers = const [],
    required this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    // Read the new `zooms` array if present. Older docs from the brief
    // single-zoom phase had `zoomTimeMs`/`zoomScale`/`zoomDurationMs` —
    // promote those into a one-element list so they still play correctly.
    List<ZoomMarker> zooms;
    final zoomsRaw = json['zooms'] as List?;
    if (zoomsRaw != null) {
      zooms = zoomsRaw
          .map((e) => ZoomMarker.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      final legacyScale = (json['zoomScale'] as num?)?.toDouble() ?? 1.0;
      zooms = legacyScale > 1.0
          ? [
              ZoomMarker(
                timeMs: (json['zoomTimeMs'] as num?)?.toDouble() ?? 0,
                scale: legacyScale,
                durationMs:
                    (json['zoomDurationMs'] as num?)?.toDouble() ?? 2000,
              ),
            ]
          : const [];
    }
    return Video(
      id: json['id'] as String,
      authorUid: json['authorUid'] as String,
      authorUsername: json['authorUsername'] as String,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      caption: json['caption'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? []),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      audioTitle: json['audioTitle'] as String?,
      filterId: json['filterId'] as String? ?? 'none',
      zooms: zooms,
      blurAmount: (json['blurAmount'] as num?)?.toDouble() ?? 0,
      vignetteIntensity: (json['vignetteIntensity'] as num?)?.toDouble() ?? 0,
      textOverlays: (json['textOverlays'] as List?)
              ?.map((e) => TextOverlay.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      stickers: (json['stickers'] as List?)
              ?.map((e) => StickerOverlay.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorUid': authorUid,
        'authorUsername': authorUsername,
        'authorAvatarUrl': authorAvatarUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'tags': tags,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'shareCount': shareCount,
        'viewCount': viewCount,
        'audioTitle': audioTitle,
        'filterId': filterId,
        'zooms': zooms.map((z) => z.toJson()).toList(),
        'blurAmount': blurAmount,
        'vignetteIntensity': vignetteIntensity,
        'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        'stickers': stickers.map((s) => s.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
