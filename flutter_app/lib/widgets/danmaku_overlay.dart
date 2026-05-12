import 'dart:math';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

// Danmaku (bullet comment) overlay — messages float right-to-left across the screen
class DanmakuOverlay extends StatefulWidget {
  final List<ChatMessage> messages;
  const DanmakuOverlay({super.key, required this.messages});

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> {
  final _active = <_DanmakuItem>[];
  final _rng = Random();
  int _prevLength = 0;

  @override
  void didUpdateWidget(DanmakuOverlay old) {
    super.didUpdateWidget(old);
    if (widget.messages.length > _prevLength) {
      final newMessages = widget.messages.sublist(_prevLength);
      for (final msg in newMessages) {
        _spawnItem(msg);
      }
      _prevLength = widget.messages.length;
    }
  }

  void _spawnItem(ChatMessage msg) {
    final lane = _rng.nextInt(5); // 5 horizontal lanes
    setState(() {
      _active.add(_DanmakuItem(message: msg, lane: lane));
    });
    // Remove after animation
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() => _active.removeWhere((i) => i.message.id == msg.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _active.map((item) => _FloatingMessage(item: item)).toList(),
      ),
    );
  }
}

class _DanmakuItem {
  final ChatMessage message;
  final int lane;
  _DanmakuItem({required this.message, required this.lane});
}

class _FloatingMessage extends StatefulWidget {
  final _DanmakuItem item;
  const _FloatingMessage({required this.item});

  @override
  State<_FloatingMessage> createState() => _FloatingMessageState();
}

class _FloatingMessageState extends State<_FloatingMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7));
    _anim = Tween<double>(begin: 1.0, end: -0.3).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topFraction = 0.05 + widget.item.lane * 0.07;
    final isGift = widget.item.message.type == 'gift';

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * topFraction,
          left: MediaQuery.of(context).size.width * _anim.value,
          child: child!,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isGift ? Colors.amber.withValues(alpha: 0.85) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${widget.item.message.authorUsername}: ${widget.item.message.text}',
          style: TextStyle(
            color: isGift ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: isGift ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
