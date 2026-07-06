import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';

/// Game Zone backend glue. v1 is intentionally client-only: the daily task set
/// is derived deterministically from a date seed (no cron needed), and a
/// successful play increments the streamer's attribute points directly on their
/// user doc (allowed by the owner-update Firestore rule).
///
/// Attribute points are currently cosmetic — they only feed the System status
/// panel — so client writes are acceptable for v1. If/when points gain real
/// value (payouts, ranked leaderboards), move [completeTask] behind a Cloud
/// Function that validates the score server-side to prevent cheating.
class GameService {
  final _db = FirebaseFirestore.instance;

  /// 'yyyy-mm-dd' key for [d] (local date) — identifies a task day.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Deterministic daily task set: the same [count] games for everyone on a
  /// given date, rotating day to day. With a small catalog this just returns
  /// all enabled games.
  List<Game> tasksForDay(List<Game> catalog, DateTime day, {int count = 3}) {
    final enabled = catalog.where((g) => g.enabled).toList();
    if (enabled.length <= count) return enabled;
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final shuffled = [...enabled]..shuffle(Random(seed));
    return shuffled.take(count).toList();
  }

  /// Record a successful play: award the game's points to its attribute and
  /// mark it done for [day]. [doneToday] must already be reset to empty by the
  /// caller when the stored task date is stale.
  Future<void> completeTask({
    required String uid,
    required Game game,
    required DateTime day,
    required List<String> doneToday,
  }) async {
    final newDone = {...doneToday, game.id}.toList();
    await _db.collection('users').doc(uid).update({
      'attributes.${game.attribute}': FieldValue.increment(game.rewardPoints),
      'gameTasksDate': dayKey(day),
      'gameTasksDone': newDone,
    });
  }
}
