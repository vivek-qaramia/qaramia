import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_stats_provider.dart';
import '../theme/brand.dart';

/// Compact host-side earnings card. Surfaces three running counters and an
/// estimated session $ value so the creator gets real-time feedback that
/// product detection is producing inventory. Designed for an absolute
/// position in the broadcast Stack.
class SessionEarningsCard extends ConsumerWidget {
  final String streamId;
  const SessionEarningsCard({super.key, required this.streamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(sessionStatsProvider(streamId));
    // Hide entirely until something happens so it doesn't sit empty on screen.
    final hasActivity = stats.products > 0 || stats.affiliateClicks > 0;
    if (!hasActivity) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SESSION',
            style: TextStyle(
              color: QBrand.fgDim, fontSize: 9,
              letterSpacing: 1.4, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          _StatRow(label: '🏷', value: stats.products,        suffix: 'products'),
          _StatRow(label: '🎯', value: stats.impressions,     suffix: 'matches'),
          _StatRow(label: '🛒', value: stats.affiliateClicks, suffix: 'clicks'),
          const SizedBox(height: 6),
          Container(height: 0.5, color: Colors.white12),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Est. \$',
                  style: TextStyle(color: QBrand.fgMute, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(
                stats.estimatedEarningsUsd.toStringAsFixed(2),
                style: const TextStyle(
                  color: QBrand.peach, fontSize: 14, fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  const _StatRow({required this.label, required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text(
            suffix,
            style: const TextStyle(color: QBrand.fgMute, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
