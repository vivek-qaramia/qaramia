import 'package:flutter/material.dart';

const _accent = Color(0xFF5BE1FF);
const _danger = Color(0xFFE94560);

/// Shared score + countdown HUD for Game Zone mini-games (score line + time
/// line + a draining progress bar). Each engine supplies its own play area.
class GameHud extends StatelessWidget {
  final int score;
  final int successScore;
  final int secondsLeft;
  final int timeLimitSec;
  const GameHud({
    super.key,
    required this.score,
    required this.successScore,
    required this.secondsLeft,
    required this.timeLimitSec,
  });

  @override
  Widget build(BuildContext context) {
    final progress = timeLimitSec > 0 ? (secondsLeft / timeLimitSec).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Score $score / $successScore',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('⏱ $secondsLeft s',
                  style: TextStyle(
                      color: secondsLeft <= 5 ? _danger : Colors.white,
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
              valueColor: const AlwaysStoppedAnimation(_accent),
            ),
          ),
        ),
      ],
    );
  }
}
