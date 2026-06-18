import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../providers/providers.dart';
import '../../services/game_service.dart';
import '../../widgets/games/tap_targets_game.dart';

const _bg = Color(0xFF0A1430);
const _accent = Color(0xFF5BE1FF);
const _ink = Color(0xFFCFE8FF);
const _inkMute = Color(0xFF6E86B0);

/// Game Zone — streamers play daily, time-bound mini-games to earn attribute
/// points that feed their System status panel. v1: a single tap-targets engine
/// in three difficulty tiers, picked as the day's tasks.
class GameZoneScreen extends ConsumerStatefulWidget {
  const GameZoneScreen({super.key});

  @override
  ConsumerState<GameZoneScreen> createState() => _GameZoneScreenState();
}

class _GameZoneScreenState extends ConsumerState<GameZoneScreen> {
  Future<void> _play(Game game, String uid, List<String> doneToday) async {
    final result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute(builder: (_) => _GamePlayScreen(game: game)),
    );
    if (result == null || !mounted) return;
    if (result.success) {
      try {
        await ref.read(gameServiceProvider).completeTask(
              uid: uid,
              game: game,
              day: DateTime.now(),
              doneToday: doneToday,
            );
        ref.invalidate(currentUserProvider);
      } catch (_) {/* non-fatal: the play still happened */}
      if (mounted) _showResult(game, result, won: true);
    } else {
      _showResult(game, result, won: false);
    }
  }

  void _showResult(Game game, GameResult r, {required bool won}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(won ? '⚡ Cleared!' : 'So close!',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: Text(
          won
              ? 'Score ${r.score}. +${game.rewardPoints} ${kAttributeLabels[game.attribute] ?? game.attribute} points!'
              : 'Score ${r.score} — you needed ${game.successScore}. Try again!',
          style: const TextStyle(color: _inkMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final today = GameService.dayKey(DateTime.now());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text('⚡ Game Zone', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accent)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: _inkMute))),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Sign in to play.', style: TextStyle(color: _inkMute)));
          }
          final tasks = ref.read(gameServiceProvider).tasksForDay(DateTime.now());
          final doneToday = user.gameTasksDate == today ? user.gameTasksDone : const <String>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AttributeStrip(user: user),
              const SizedBox(height: 8),
              const Text("Today's tasks",
                  style: TextStyle(color: _inkMute, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final g in tasks) ...[
                _TaskCard(
                  game: g,
                  done: doneToday.contains(g.id),
                  onPlay: () => _play(g, user.uid, doneToday),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              const Text('// new games and challenges coming soon',
                  style: TextStyle(color: _inkMute, fontSize: 10)),
            ],
          );
        },
      ),
    );
  }
}

class _AttributeStrip extends StatelessWidget {
  final AppUser user;
  const _AttributeStrip({required this.user});

  @override
  Widget build(BuildContext context) {
    final entries = user.attributes.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR ATTRIBUTES',
              style: TextStyle(color: _accent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text('Play a task to earn your first points.',
                style: TextStyle(color: _inkMute, fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(kAttributeLabels[e.key] ?? e.key).toUpperCase()}  ${e.value}',
                      style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Game game;
  final bool done;
  final VoidCallback onPlay;
  const _TaskCard({required this.game, required this.done, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: done ? 0.25 : 0.5)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Row(
        children: [
          Text(game.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name,
                    style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${game.difficulty} · ⏱ ${game.timeLimitSec}s · +${game.rewardPoints} ${(kAttributeLabels[game.attribute] ?? game.attribute)}',
                    style: const TextStyle(color: _inkMute, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (done)
            const Text('Done ✓', style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 13))
          else
            GestureDetector(
              onTap: onPlay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Play',
                    style: TextStyle(color: _bg, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen play wrapper — runs the right engine for the game type and pops
/// with the [GameResult].
class _GamePlayScreen extends StatelessWidget {
  final Game game;
  const _GamePlayScreen({required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: switch (game.type) {
        GameType.tapTargets => TapTargetsGame(
            game: game,
            onFinish: (r) => Navigator.of(context).pop(r),
          ),
      },
    );
  }
}
