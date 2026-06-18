import 'package:flutter/material.dart';

import '../models/streamer_stats.dart';

/// LitRPG "System" status window. Renders a streamer's [StreamerStats] as a
/// glowing sci-fi panel (à la the blue status screens in cultivation / system
/// web novels). Two entry points:
///   - [SystemStatusCard]   — the panel itself, for inline use (e.g. profile).
///   - [SystemPanelOverlay] — a floating ⚡ button + slide-up panel, for the
///     live viewer screen (mirrors the ProductDrawer pattern).

// Sci-fi palette — kept local; this is deliberately off-brand "system UI".
const _panelBg = Color(0xF20A1430); // deep translucent navy
const _accent = Color(0xFF5BE1FF); // cyan glow
const _accentDim = Color(0x335BE1FF);
const _ink = Color(0xFFCFE8FF); // pale blue text
const _inkMute = Color(0xFF6E86B0);
const _mono = 'monospace';

class SystemStatusCard extends StatelessWidget {
  final StreamerStats stats;
  final String name;
  final VoidCallback? onClose;

  const SystemStatusCard({
    super.key,
    required this.stats,
    required this.name,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.55), width: 1.2),
        boxShadow: const [
          BoxShadow(color: _accentDim, blurRadius: 24, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text('STATUS',
                  style: TextStyle(
                      fontFamily: _mono,
                      color: _accent,
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Flexible(
                child: Text(name.toUpperCase(),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: _mono, color: _inkMute, fontSize: 11, letterSpacing: 1)),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: _inkMute, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: _accent.withValues(alpha: 0.25)),
          const SizedBox(height: 12),

          // Level + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Lv. ${stats.level}',
                  style: const TextStyle(
                      fontFamily: _mono, color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text('${stats.title} ★',
                  style: const TextStyle(
                      fontFamily: _mono, color: _accent, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          // EXP bar
          Row(
            children: [
              const Text('EXP',
                  style: TextStyle(fontFamily: _mono, color: _inkMute, fontSize: 10, letterSpacing: 1)),
              const SizedBox(width: 8),
              Expanded(child: _ExpBar(progress: stats.expProgress)),
              const SizedBox(width: 8),
              Text('${(stats.expProgress * 100).round()}%',
                  style: const TextStyle(fontFamily: _mono, color: _inkMute, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),

          // Stat lines
          for (final s in stats.stats) ...[
            _StatLine(stat: s),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          const Text('// stats derived from live activity',
              style: TextStyle(fontFamily: _mono, color: _inkMute, fontSize: 9, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final SystemStat stat;
  const _StatLine({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(stat.code,
              style: const TextStyle(
                  fontFamily: _mono, color: _accent, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          width: 66,
          child: Text(stat.label,
              style: const TextStyle(fontFamily: _mono, color: _inkMute, fontSize: 10)),
        ),
        Expanded(child: _SegBar(fill: stat.fill)),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(stat.display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: _mono, color: _ink, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Discrete segmented bar (▰▰▰▱▱) — the classic "system" look.
class _SegBar extends StatelessWidget {
  final double fill; // 0..1
  const _SegBar({required this.fill});

  static const segments = 10;

  @override
  Widget build(BuildContext context) {
    final lit = (fill * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (i) {
        return Expanded(
          child: Container(
            height: 9,
            margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 3),
            decoration: BoxDecoration(
              color: i < lit ? _accent : _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(2),
              boxShadow: i < lit
                  ? const [BoxShadow(color: _accentDim, blurRadius: 4)]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _ExpBar extends StatelessWidget {
  final double progress; // 0..1
  const _ExpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 6, color: _accent.withValues(alpha: 0.14)),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(height: 6, color: _accent),
          ),
        ],
      ),
    );
  }
}

/// Compact, tappable "⚡ Lv.N" badge for the live header — sits next to the
/// host's name and opens the [SystemStatusCard]. Replaces a second floating
/// button so the live viewer keeps a single floating control (the product bag).
class SystemLevelBadge extends StatelessWidget {
  final int level;
  final VoidCallback onTap;
  const SystemLevelBadge({super.key, required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1.2),
          boxShadow: const [BoxShadow(color: _accentDim, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('Lv.$level',
                style: const TextStyle(
                    fontFamily: _mono, color: _accent, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
