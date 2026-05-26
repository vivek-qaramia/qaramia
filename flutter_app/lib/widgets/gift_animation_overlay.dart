import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gift.dart';
import '../providers/providers.dart';

/// Renders a brief floating animation on the live stream for each new gift.
///
/// Subscribes to streams/{id}/gifts filtered to documents created in the last
/// 30 seconds (so a viewer who just joined doesn't see a flood of historical
/// gifts). Each new gift floats up + fades out over [_lifetimeMs]. Multiple
/// gifts arriving in quick succession fan across roughly 70% of the screen
/// width so they don't stack on top of each other.
class GiftAnimationOverlay extends ConsumerStatefulWidget {
  final String streamId;
  const GiftAnimationOverlay({super.key, required this.streamId});

  @override
  ConsumerState<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends ConsumerState<GiftAnimationOverlay> {
  static const int _lifetimeMs = 3500;
  final List<_ActiveGift> _active = [];
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _giftsStream;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    final since = Timestamp.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch - 30000,
    );
    _giftsStream = FirebaseFirestore.instance
        .collection('streams').doc(widget.streamId)
        .collection('gifts')
        .where('sentAt', isGreaterThanOrEqualTo: since)
        .orderBy('sentAt', descending: true)
        .limit(20)
        .snapshots();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;

      // Reverse-engineer the gift emoji from the live catalog (Firestore
      // when available, static fallback when not).
      final giftTypeId = (data['giftTypeId'] ?? data['giftId']) as String?;
      final catalog = ref.read(giftCatalogProvider);
      final emoji = catalog
          .where((g) => g.id == giftTypeId)
          .map((g) => g.emoji)
          .firstOrNull ?? '🎁';
      final sender = data['senderUsername'] as String? ?? '';

      final id = ++_seq;
      final lane = id % 7; // distribute horizontally
      final active = _ActiveGift(
        id: id,
        emoji: emoji,
        sender: sender,
        laneIndex: lane,
      );
      if (mounted) setState(() => _active.add(active));
      Future.delayed(const Duration(milliseconds: _lifetimeMs), () {
        if (!mounted) return;
        setState(() => _active.removeWhere((g) => g.id == id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _giftsStream,
      builder: (context, snap) {
        if (snap.hasData) _onSnapshot(snap.data!);
        if (_active.isEmpty) return const SizedBox.shrink();
        return IgnorePointer(
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final g in _active)
                    _GiftSprite(
                      key: ValueKey(g.id),
                      gift: g,
                      maxWidth: width,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ActiveGift {
  final int id;
  final String emoji;
  final String sender;
  final int laneIndex;
  _ActiveGift({
    required this.id,
    required this.emoji,
    required this.sender,
    required this.laneIndex,
  });
}

class _GiftSprite extends StatefulWidget {
  final _ActiveGift gift;
  final double maxWidth;
  const _GiftSprite({super.key, required this.gift, required this.maxWidth});

  @override
  State<_GiftSprite> createState() => _GiftSpriteState();
}

class _GiftSpriteState extends State<_GiftSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _GiftAnimationOverlayState._lifetimeMs),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Distribute laneIndex 0..6 across 15%–85% of width
    final laneFraction = 0.15 + 0.10 * (widget.gift.laneIndex % 7);
    final dx = widget.maxWidth * laneFraction;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Match the web keyframe shape: 0→15% rises fast, 15–80% drifts up,
        // 80–100% fades out and decelerates.
        final dy = _easeOutY(t);
        final opacity = _opacityAt(t);
        final scale = _scaleAt(t);
        return Positioned(
          left: dx - 28,
          bottom: 80 + dy,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.gift.emoji, style: const TextStyle(fontSize: 44, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
                  if (widget.gift.sender.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '@${widget.gift.sender}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 0 → -340 over the lifetime, slowing toward the end.
  double _easeOutY(double t) {
    if (t < 0.15) return -200 * (t / 0.15);
    if (t < 0.80) {
      final p = (t - 0.15) / 0.65;
      return -200 + (-80 * p);
    }
    final p = (t - 0.80) / 0.20;
    return -280 + (-60 * p);
  }

  double _opacityAt(double t) {
    if (t < 0.15) return t / 0.15;
    if (t < 0.80) return 1.0;
    return 1.0 - ((t - 0.80) / 0.20);
  }

  double _scaleAt(double t) {
    if (t < 0.15) return 0.6 + (0.5 * (t / 0.15)); // 0.6 → 1.1
    if (t < 0.80) return 1.1 - (0.1 * ((t - 0.15) / 0.65)); // 1.1 → 1.0
    return 1.0 - (0.1 * ((t - 0.80) / 0.20)); // 1.0 → 0.9
  }
}

