import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game.dart';
import 'game_hud.dart';

/// Find-the-object mini-game: a target emoji is shown; tap the single matching
/// one hidden among decoys. Each correct tap reshuffles a new round. Time-bound;
/// success = score >= threshold. Same GameResult contract as the other engines.
class FindObjectGame extends StatefulWidget {
  final Game game;
  final void Function(GameResult) onFinish;
  const FindObjectGame({super.key, required this.game, required this.onFinish});

  @override
  State<FindObjectGame> createState() => _FindObjectGameState();
}

class _Item {
  final String emoji;
  final double fx;
  final double fy;
  final bool isTarget;
  _Item(this.emoji, this.fx, this.fy, this.isTarget);
}

const _bg = Color(0xFF0A1430);
const _accent = Color(0xFF5BE1FF);
const _itemSize = 44.0;
const _pool = ['🐱', '🐶', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐸', '🐵', '🐰', '🐹', '🐮', '🐷'];

class _FindObjectGameState extends State<FindObjectGame> {
  final _rng = Random();
  List<_Item> _items = [];
  String _target = '🐱';
  int _score = 0;
  late int _secondsLeft;
  Timer? _clock;
  bool _finished = false;

  int get _count => switch (widget.game.difficulty) {
        'Hard' => 26,
        'Medium' => 18,
        _ => 12,
      };

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.game.timeLimitSec;
    _newRound();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  void _newRound() {
    final target = _pool[_rng.nextInt(_pool.length)];
    final decoys = _pool.where((e) => e != target).toList();
    final items = <_Item>[
      _Item(target, _rng.nextDouble(), _rng.nextDouble(), true),
      for (var i = 0; i < _count - 1; i++)
        _Item(decoys[_rng.nextInt(decoys.length)], _rng.nextDouble(), _rng.nextDouble(), false),
    ]..shuffle(_rng);
    setState(() {
      _target = target;
      _items = items;
    });
  }

  void _tickClock() {
    if (!mounted) return;
    setState(() => _secondsLeft--);
    if (_secondsLeft <= 0) _finish();
  }

  void _tap(_Item item) {
    if (_finished) return;
    if (item.isTarget) {
      setState(() => _score++);
      _newRound();
    }
    // Wrong taps are free in v1 (kept friendly).
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _clock?.cancel();
    widget.onFinish(GameResult(score: _score, success: _score >= widget.game.successScore));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            GameHud(
              score: _score,
              successScore: widget.game.successScore,
              secondsLeft: _secondsLeft,
              timeLimitSec: widget.game.timeLimitSec,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Find:', style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(_target, style: const TextStyle(fontSize: 28)),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final maxW = c.maxWidth - _itemSize;
                  final maxH = c.maxHeight - _itemSize;
                  return Stack(
                    children: [
                      for (final it in _items)
                        Positioned(
                          left: it.fx * maxW,
                          top: it.fy * maxH,
                          child: GestureDetector(
                            onTap: () => _tap(it),
                            child: SizedBox(
                              width: _itemSize,
                              height: _itemSize,
                              child: Center(child: Text(it.emoji, style: const TextStyle(fontSize: 30))),
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
