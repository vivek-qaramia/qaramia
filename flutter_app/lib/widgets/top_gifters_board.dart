import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gift.dart';
import '../providers/providers.dart';
import '../theme/brand.dart';

/// Compact live leaderboard of a stream's top gifters (by coins spent).
///
/// Shows the top 3 plus a "You: #N" line for the signed-in viewer. If the
/// viewer is already inside the top 3 their row is highlighted and no extra
/// query runs; otherwise a single count() aggregation resolves their rank.
class TopGiftersBoard extends ConsumerStatefulWidget {
  final String streamId;
  const TopGiftersBoard({super.key, required this.streamId});

  @override
  ConsumerState<TopGiftersBoard> createState() => _TopGiftersBoardState();
}

class _TopGiftersBoardState extends ConsumerState<TopGiftersBoard> {
  // Cached rank/total for the viewer when they're OUTSIDE the visible top
  // rows — fetched via count() and refreshed when the board changes.
  ({int rank, int totalCoins})? _myRank;
  int _lastFetchSignature = -1;

  @override
  Widget build(BuildContext context) {
    final topAsync = ref.watch(topGiftersProvider(widget.streamId));
    final top = topAsync.valueOrNull ?? const <TopGifter>[];
    if (top.isEmpty) return const SizedBox.shrink();

    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final visible = top.take(3).toList();
    final myIndexInTop = uid == null
        ? -1
        : top.indexWhere((g) => g.senderUid == uid);

    // Refresh the viewer's rank only when they're not already visible and the
    // leaderboard has actually changed (cheap signature = top coins + length).
    if (uid != null && myIndexInTop < 0) {
      final sig = Object.hash(top.length, top.first.totalCoins);
      if (sig != _lastFetchSignature) {
        _lastFetchSignature = sig;
        ref
            .read(streamServiceProvider)
            .myGifterRank(widget.streamId, uid)
            .then((r) {
          if (mounted) setState(() => _myRank = r);
        }).catchError((_) {});
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('🏆', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text('Top Gifters',
                  style: TextStyle(
                      color: QBrand.gold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < visible.length; i++)
            _GifterRow(
              rank: i + 1,
              gifter: visible[i],
              isMe: uid != null && visible[i].senderUid == uid,
            ),
          // "You" footer — only when the viewer has gifted but isn't in the
          // visible top rows.
          if (uid != null && myIndexInTop < 0 && _myRank != null) ...[
            Divider(
                color: Colors.white.withValues(alpha: 0.12),
                height: 10,
                thickness: 0.5),
            _YouRow(rank: _myRank!.rank, totalCoins: _myRank!.totalCoins),
          ],
        ],
      ),
    );
  }
}

class _GifterRow extends StatelessWidget {
  final int rank;
  final TopGifter gifter;
  final bool isMe;
  const _GifterRow({required this.rank, required this.gifter, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) { 1 => '👑', 2 => '🥈', 3 => '🥉', _ => '$rank.' };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(medal,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              '@${gifter.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? QBrand.gold : Colors.white,
                fontSize: 11,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('${gifter.totalCoins}',
              style: const TextStyle(
                  color: QBrand.gold, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          const Text('🪙', style: TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}

class _YouRow extends StatelessWidget {
  final int rank;
  final int totalCoins;
  const _YouRow({required this.rank, required this.totalCoins});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('You: #$rank',
            style: const TextStyle(
                color: QBrand.gold, fontSize: 11, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('$totalCoins',
            style: const TextStyle(
                color: QBrand.gold, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 2),
        const Text('🪙', style: TextStyle(fontSize: 8)),
      ],
    );
  }
}
