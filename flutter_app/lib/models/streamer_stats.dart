import 'dart:math' as math;

import 'app_user.dart';
import 'game.dart' show kAttributeLabels;
import 'live_stream.dart';

/// One RPG-style stat line: an abbreviation, a label, a 0..1 bar fill, and a
/// short human display value.
class SystemStat {
  final String code; // e.g. 'CHA'
  final String label; // e.g. 'charisma'
  final double fill; // 0..1, drives the segmented bar
  final String display; // e.g. '1.2K'
  const SystemStat({
    required this.code,
    required this.label,
    required this.fill,
    required this.display,
  });
}

/// LitRPG "System" status for a streamer, derived entirely from existing
/// behavioural signals — followers, likes, live viewers, session gifts. There
/// is no personal or appearance data here: it's a character sheet built from
/// what the streamer *does*, not how they look.
///
/// Pure (no I/O), so it recomputes cheaply on any data change and is trivially
/// unit-testable. Formulas are intentionally simple and tunable.
class StreamerStats {
  final int level;
  final String title; // realm/title for the level band
  final double expProgress; // 0..1 within the current level
  final List<SystemStat> stats;

  const StreamerStats({
    required this.level,
    required this.title,
    required this.expProgress,
    required this.stats,
  });

  /// Cumulative, monotonic XP so the level only ever climbs: each follower is
  /// worth 12, each like 1.
  static int _xpOf(AppUser u) => u.followerCount * 12 + u.likeCount;

  /// Level N requires `50 * N^2` total XP — a classic quadratic curve (fast
  /// early levels, slower later).
  static int _levelForXp(int xp) => math.max(1, (math.sqrt(xp / 50)).floor());

  factory StreamerStats.from({required AppUser user, LiveStream? stream}) {
    // Game-earned attribute points also feed XP, so playing Game Zone tasks
    // visibly levels the streamer up.
    final earnedTotal = user.attributes.values.fold<int>(0, (a, b) => a + b);
    final xp = _xpOf(user) + earnedTotal * 5;
    final level = _levelForXp(xp);
    final curBase = 50 * level * level;
    final nextBase = 50 * (level + 1) * (level + 1);
    final expProgress = nextBase > curBase
        ? ((xp - curBase) / (nextBase - curBase)).clamp(0.0, 1.0)
        : 0.0;

    final stats = <SystemStat>[
      SystemStat(code: 'CHA', label: 'charisma', fill: _sat(user.likeCount, 800), display: _short(user.likeCount)),
      SystemStat(code: 'INF', label: 'influence', fill: _sat(user.followerCount, 1500), display: _short(user.followerCount)),
    ];
    if (stream != null) {
      final hypeFill = stream.peakViewerCount > 0
          ? (stream.viewerCount / stream.peakViewerCount).clamp(0.0, 1.0)
          : (stream.viewerCount > 0 ? 1.0 : 0.0);
      stats.add(SystemStat(code: 'FOR', label: 'fortune', fill: _sat(stream.totalGifts, 500), display: _short(stream.totalGifts)));
      stats.add(SystemStat(code: 'HYP', label: 'hype', fill: hypeFill, display: '${(hypeFill * 100).round()}%'));
    }

    // Game-earned attributes (e.g. PWR from Game Zone tasks) as extra lines.
    final earned = user.attributes.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in earned) {
      stats.add(SystemStat(
        code: e.key.toUpperCase(),
        label: kAttributeLabels[e.key] ?? e.key,
        fill: _sat(e.value, 200),
        display: _short(e.value),
      ));
    }

    return StreamerStats(
      level: level,
      title: _titleFor(level),
      expProgress: expProgress,
      stats: stats,
    );
  }

  /// Smooth saturating curve: 0 → 0, ~`soft` → ~0.5, large → ~1. Keeps a small
  /// streamer's bars visibly non-empty while never quite maxing out.
  static double _sat(int v, int soft) =>
      v <= 0 ? 0.0 : (1 - 1 / (1 + v / soft)).clamp(0.0, 1.0);

  static String _titleFor(int lv) {
    if (lv >= 50) return 'Legend';
    if (lv >= 35) return 'Master';
    if (lv >= 20) return 'Elite';
    if (lv >= 10) return 'Veteran';
    if (lv >= 5) return 'Rising Star';
    return 'Novice';
  }

  static String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    return '$v';
  }
}
