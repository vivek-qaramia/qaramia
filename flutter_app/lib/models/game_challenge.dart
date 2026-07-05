import 'package:cloud_firestore/cloud_firestore.dart';

/// A viewer's coin-backed dare for the streamer to play a game live.
///
/// Lifecycle: pending → accepted | declined; an accepted challenge is then
/// settled by the *viewer's* client → paid | failed (coins only move on
/// accept; a decline never charges, so "refund on decline" is automatic).
class GameChallenge {
  final String id;
  final String fromUid;
  final String fromUsername;
  final String gameId;
  final String gameName;
  final int coins;
  final String status; // pending | accepted | declined | paid | failed
  final DateTime createdAt;

  const GameChallenge({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.gameId,
    required this.gameName,
    required this.coins,
    required this.status,
    required this.createdAt,
  });

  factory GameChallenge.fromJson(String id, Map<String, dynamic> j) => GameChallenge(
        id: id,
        fromUid: j['fromUid'] as String? ?? '',
        fromUsername: j['fromUsername'] as String? ?? 'viewer',
        gameId: j['gameId'] as String? ?? '',
        gameName: j['gameName'] as String? ?? 'a game',
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'pending',
        createdAt: (j['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
