import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game.dart';

/// Tap-the-moving-targets mini-game. Targets drift to new spots each tick;
/// tapping one scores a point and respawns it elsewhere. When the timer hits
/// zero, [onFinish] fires with the score and whether it cleared the threshold.
///
/// The v1 engine behind the Game Zone catalog's tapTargets entries — difficulty
/// tunes target count and tick speed.
class TapTargetsGame extends StatefulWidget {
  final Game game;
  final void Function(GameResult) onFinish;
  const TapTargetsGame({super.key, required this.game, required this.onFinish});

  @override
  State<TapTargetsGame> createState() => _TapTargetsGameState();
}

class _Target {
  final int id;
  double fx; // 0..1 fractional position
  double fy;
  _Target(this.id, this.fx, this.fy);
}

class _TapTargetsGameState extends State<TapTargetsGame> {
  static const _targetSize = 56.0;
  final _rng = Random();
  final List<_Target> _targets = [];
  int _score = 0;
  late int _secondsLeft;
  Timer? _loop;
  Timer? _clock;
  bool _finished = false;
  int _nextId = 0;

  // Difficulty → (target count, move interval).
  int get _count => switch (widget.game.difficulty) {
        'Hard' => 5,
        'Medium' => 4,
        _ => 4,
      };
  Duration get _interval => switch (widget.game.difficulty) {
        'Hard' => const Duration(milliseconds: 450),
        'Medium' => const Duration(milliseconds: 650),
        _ => const Duration(milliseconds: 900),
      };

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.game.timeLimitSec;
    for (var i = 0; i < _count; i++) {
      _targets.add(_Target(_nextId++, _rng.nextDouble(), _rng.nextDouble()));
    }
    _loop = Timer.periodic(_interval, (_) => _moveAll());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  void _moveAll() {
    if (!mounted) return;
    setState(() {
      for (final t in _targets) {
        t.fx = _rng.nextDouble();
        t.fy = _rng.nextDouble();
      }
    });
  }

  void _tickClock() {
    if (!mounted) return;
    setState(() => _secondsLeft--);
    if (_secondsLeft <= 0) _finish();
  }

  void _hit(_Target t) {
    if (_finished) return;
    setState(() {
      _score++;
      t.fx = _rng.nextDouble();
      t.fy = _rng.nextDouble();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _loop?.cancel();
    _clock?.cancel();
    widget.onFinish(GameResult(score: _score, success: _score >= widget.game.successScore));
  }

  @override
  void dispose() {
    _loop?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_secondsLeft / widget.game.timeLimitSec).clamp(0.0, 1.0);
    return Container(
      color: const Color(0xFF0A1430),
      child: SafeArea(
        child: Column(
          children: [
            // HUD
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Score $_score / ${widget.game.successScore}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('⏱ $_secondsLeft s',
                      style: TextStyle(
                          color: _secondsLeft <= 5 ? const Color(0xFFE94560) : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5BE1FF)),
                ),
              ),
            ),
            // Play area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = (constraints.maxWidth - _targetSize).clamp(0.0, double.infinity);
                  final maxH = (constraints.maxHeight - _targetSize).clamp(0.0, double.infinity);
                  return Stack(
                    children: [
                      for (final t in _targets)
                        AnimatedPositioned(
                          key: ValueKey(t.id),
                          duration: _interval,
                          curve: Curves.easeInOut,
                          left: t.fx * maxW,
                          top: t.fy * maxH,
                          child: GestureDetector(
                            onTap: () => _hit(t),
                            child: Container(
                              width: _targetSize,
                              height: _targetSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF5BE1FF).withValues(alpha: 0.15),
                                border: Border.all(color: const Color(0xFF5BE1FF), width: 2),
                                boxShadow: const [BoxShadow(color: Color(0x335BE1FF), blurRadius: 12)],
                              ),
                              alignment: Alignment.center,
                              child: Text(widget.game.emoji, style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
