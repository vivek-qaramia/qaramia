import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/game.dart';
import '../models/game_challenge.dart';

/// Viewer challenges (Game Zone Phase 3c): a viewer dares the streamer to play
/// a game live for coins. Coins move only on accept, done by the *viewer's*
/// client (the wallet owner) — the host can't spend someone else's coins under
/// the Firestore rules. Diamonds credited to the streamer at coins/2, matching
/// the gift economy.
///
/// v1 trust note: the pay step runs on the viewer's client after the host
/// accepts, so a malicious viewer could skip it. Acceptable while challenge
/// coins are low-value; move [payAccepted] into a Cloud Function if it matters.
class GameChallengeService {
  final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> _col(String streamId) =>
      _db.collection('streams').doc(streamId).collection('gameChallenges');

  /// Viewer sends a challenge. No coins move yet — charged only if accepted.
  Future<void> send({
    required String streamId,
    required String fromUid,
    required String fromUsername,
    required Game game,
  }) async {
    await _col(streamId).doc(_uuid.v4()).set({
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'gameId': game.id,
      'gameName': game.name,
      'coins': game.challengeCost,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> accept(String streamId, String challengeId) =>
      _col(streamId).doc(challengeId).update({'status': 'accepted'});

  Future<void> decline(String streamId, String challengeId) =>
      _col(streamId).doc(challengeId).update({'status': 'declined'});

  /// Viewer-side settlement once the host accepts: deduct the viewer's coins,
  /// credit the host's diamonds (coins/2), and mark paid. Marks 'failed' if the
  /// viewer can no longer afford it. No-op if the challenge isn't 'accepted'.
  Future<void> payAccepted({
    required String streamId,
    required GameChallenge ch,
    required String hostUid,
  }) async {
    final walletRef = _db.collection('users').doc(ch.fromUid).collection('wallet').doc('default');
    final creatorBalRef = _db.collection('users').doc(hostUid).collection('creatorBalance').doc('default');
    final chRef = _col(streamId).doc(ch.id);
    final diamonds = ch.coins ~/ 2;

    await _db.runTransaction((txn) async {
      final chSnap = await txn.get(chRef);
      if ((chSnap.data()?['status']) != 'accepted') return; // already settled
      final coins = ((await txn.get(walletRef)).data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < ch.coins) {
        txn.update(chRef, {'status': 'failed'});
        return;
      }
      txn.set(walletRef, {
        'coins': FieldValue.increment(-ch.coins),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      txn.set(creatorBalRef, {
        'diamonds': FieldValue.increment(diamonds),
        'lifetimeDiamonds': FieldValue.increment(diamonds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      txn.update(chRef, {'status': 'paid'});
    });
  }

  /// Host: pending challenges awaiting accept/decline.
  Stream<List<GameChallenge>> watchPending(String streamId) =>
      _col(streamId).where('status', isEqualTo: 'pending').snapshots().map(
            (s) => s.docs.map((d) => GameChallenge.fromJson(d.id, d.data())).toList(),
          );

  /// Viewer: their own challenges on this stream (single-field query, no index
  /// needed). The caller reacts to 'accepted' ones by calling [payAccepted].
  Stream<List<GameChallenge>> watchMine(String streamId, String fromUid) =>
      _col(streamId).where('fromUid', isEqualTo: fromUid).snapshots().map(
            (s) => s.docs.map((d) => GameChallenge.fromJson(d.id, d.data())).toList(),
          );
}
