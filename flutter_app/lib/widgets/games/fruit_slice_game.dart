import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game.dart';
import 'game_hud.dart';

/// Fruit-slice mini-game: fruit falls from the top; swipe across it to slice
/// (score). Time-bound; success = score >= threshold. Same GameResult contract
/// as the other engines.
class FruitSliceGame extends StatefulWidget {
  final Game game;
  final void Function(GameResult) onFinish;
  const FruitSliceGame({super.key, required this.game, required this.onFinish});

  @override
  State<FruitSliceGame> createState() => _FruitSliceGameState();
}

class _Fruit {
  final int id;
  final String emoji;
  double fx; // 0..1 horizontal
  double fy; // vertical, starts <0 (above) and falls past 1 (below)
  _Fruit(this.id, this.emoji, this.fx, this.fy);
}

const _bg = Color(0xFF0A1430);
const _fruitSize = 54.0;
const _fruitEmojis = ['🍉', '🍊', '🍎', '🍓', '🍇', '🍌', '🥝', '🍑'];

class _FruitSliceGameState extends State<FruitSliceGame> {
  final _rng = Random();
  final List<_Fruit> _items = [];
  int _score = 0;
  late int _secondsLeft;
  int _nextId = 0;
  int _spawnTick = 0;
  Timer? _loop;
  Timer? _clock;
  bool _finished = false;
  Size _area = Size.zero;

  double get _fallSpeed => switch (widget.game.difficulty) {
        'Hard' => 0.022,
        'Medium' => 0.016,
        _ => 0.012,
      };
  int get _spawnEvery => switch (widget.game.difficulty) {
        'Hard' => 6,
        'Medium' => 9,
        _ => 12,
      };

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.game.timeLimitSec;
    _loop = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final f in _items) {
        f.fy += _fallSpeed;
      }
      _items.removeWhere((f) => f.fy > 1.1);
      if (++_spawnTick >= _spawnEvery) {
        _spawnTick = 0;
        _items.add(_Fruit(_nextId++, _fruitEmojis[_rng.nextInt(_fruitEmojis.length)],
            0.04 + _rng.nextDouble() * 0.9, -0.06));
      }
    });
  }

  void _tickClock() {
    if (!mounted) return;
    setState(() => _secondsLeft--);
    if (_secondsLeft <= 0) _finish();
  }

  void _sliceAt(Offset local) {
    if (_finished || _area == Size.zero) return;
    final maxW = _area.width - _fruitSize;
    final maxH = _area.height - _fruitSize;
    for (final f in _items) {
      final center = Offset(f.fx * maxW + _fruitSize / 2, f.fy * maxH + _fruitSize / 2);
      if ((local - center).distance < _fruitSize * 0.75) {
        setState(() {
          _score++;
          _items.remove(f);
        });
        return;
      }
    }
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  _area = Size(c.maxWidth, c.maxHeight);
                  final maxW = c.maxWidth - _fruitSize;
                  final maxH = c.maxHeight - _fruitSize;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _sliceAt(d.localPosition),
                    onPanUpdate: (d) => _sliceAt(d.localPosition),
                    child: Stack(
                      children: [
                        // Fruit glyphs are pointer-ignored; the pan handler
                        // hit-tests their positions directly.
                        for (final f in _items)
                          Positioned(
                            left: f.fx * maxW,
                            top: f.fy * maxH,
                            child: IgnorePointer(
                              child: SizedBox(
                                width: _fruitSize,
                                height: _fruitSize,
                                child: Center(child: Text(f.emoji, style: const TextStyle(fontSize: 42))),
                              ),
                            ),
                          ),
                      ],
                    ),
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
