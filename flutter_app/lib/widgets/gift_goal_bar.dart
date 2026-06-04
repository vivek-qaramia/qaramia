import 'package:flutter/material.dart';

import '../models/live_stream.dart';
import '../theme/brand.dart';

/// Compact gift-goal progress bar: fills as totalGifts approaches the host's
/// coin target. Renders nothing when the stream has no goal set.
class GiftGoalBar extends StatelessWidget {
  final LiveStream stream;
  const GiftGoalBar({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    if (!stream.hasGiftGoal) return const SizedBox.shrink();
    final pct = stream.giftGoalProgress;
    final reached = stream.totalGifts >= stream.giftGoalTarget;
    final remaining = (stream.giftGoalTarget - stream.totalGifts).clamp(0, stream.giftGoalTarget);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🎯 ${stream.giftGoalLabel ?? 'Gift goal'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${stream.totalGifts} / ${stream.giftGoalTarget} 🪙',
                  style: const TextStyle(color: QBrand.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(QBrand.gold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reached ? 'Goal reached! 🎉' : '${(pct * 100).round()}% · $remaining 🪙 to go',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
