import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/streamer_stats.dart';
import '../../providers/providers.dart';
import '../profile/profile_screen.dart';

/// All-time System-level leaderboard — top streamers ranked by the denormalized
/// `systemXp` scalar. Mirrors the web /leaderboard page.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static const _cyan = Color(0xFF5BE1FF);
  static const _bg = Color(0xFF0A1430);
  static const _text = Color(0xFFCFE8FF);
  static const _muted = Color(0xFF6E86B0);

  static String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  static String? _medal(int rank) => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        title: const Text('🏆 System Leaderboard'),
      ),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _cyan)),
        error: (_, _) => const Center(
          child: Text('Could not load the leaderboard.', style: TextStyle(color: _muted)),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 12),
                    Text('No ranked streamers yet',
                        style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Gain followers, likes, or play Game Zone tasks to climb.',
                        textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _row(context, users[i], i + 1, users[i].uid == myUid),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, AppUser user, int rank, bool isMe) {
    final stats = StreamerStats.from(user: user);
    final medal = _medal(rank);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? _cyan.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? _cyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: medal != null
                    ? Text(medal, style: const TextStyle(fontSize: 20))
                    : Text('$rank', style: const TextStyle(color: _muted, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${user.username}${isMe ? ' · you' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontWeight: FontWeight.bold)),
                  Text('Lv ${stats.level} · ${stats.title}',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Lv ${stats.level}',
                    style: const TextStyle(color: _cyan, fontWeight: FontWeight.w900)),
                Text('${_short(user.systemXp)} XP',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
