import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/live_stream.dart';
import '../models/gift.dart';
import '../models/product_info.dart';
import '../models/ad.dart';

class InsufficientCoinsException implements Exception {
  final int needed;
  final int has;
  int get shortfall => needed - has;
  const InsufficientCoinsException({required this.needed, required this.has});
  @override
  String toString() => 'Insufficient coins: need $needed, have $has';
}

class StreamService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<List<LiveStream>> watchLiveStreams() {
    return _db
        .collection('streams')
        .where('status', isEqualTo: 'live')
        .orderBy('viewerCount', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LiveStream.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<LiveStream?> watchStream(String streamId) {
    return _db.collection('streams').doc(streamId).snapshots().map((snap) =>
        snap.exists
            ? LiveStream.fromJson({...snap.data()!, 'id': snap.id})
            : null);
  }

  Future<LiveStream> startStream({
    required String hostUid,
    required String hostUsername,
    String? hostAvatarUrl,
    required String title,
    required String category,
  }) async {
    final id = _uuid.v4();
    final stream = LiveStream(
      id: id,
      hostUid: hostUid,
      hostUsername: hostUsername,
      hostAvatarUrl: hostAvatarUrl,
      title: title,
      category: category,
      agoraChannel: id,
      startedAt: DateTime.now(),
    );
    await _db.collection('streams').doc(id).set(stream.toJson());
    await _db.collection('users').doc(hostUid).update({'isLive': true});
    return stream;
  }

  Future<void> endStream(String streamId, String hostUid) async {
    await _db.collection('streams').doc(streamId).update({
      'status': StreamStatus.ended.name,
      'endedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(hostUid).update({'isLive': false});
  }

  /// End every `status: 'live'` stream owned by [hostUid]. Called at app
  /// startup to reap docs orphaned by crashes / force-quits / hot-restarts
  /// where the proper End flow never ran. Best-effort: failures are logged
  /// but don't propagate, so a flaky network at launch doesn't block the UI.
  Future<int> endStaleStreams(String hostUid) async {
    try {
      final snap = await _db
          .collection('streams')
          .where('hostUid', isEqualTo: hostUid)
          .where('status', isEqualTo: 'live')
          .get();
      if (snap.docs.isEmpty) return 0;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': StreamStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(
        _db.collection('users').doc(hostUid),
        {'isLive': false},
      );
      await batch.commit();
      return snap.docs.length;
    } catch (e) {
      // Don't crash startup over this — it'll get tried again next launch.
      return 0;
    }
  }

  Future<void> updateViewerCount(String streamId, int delta) async {
    await _db.collection('streams').doc(streamId).update({
      'viewerCount': FieldValue.increment(delta),
    });
  }

  /// Send a gift inside a single Firestore transaction:
  ///   1. Read viewer's wallet
  ///   2. If insufficient coins → throw [InsufficientCoinsException]
  ///   3. Decrement viewer wallet.coins
  ///   4. Increment recipient creatorBalance.diamonds + lifetimeDiamonds
  ///   5. Create the gift event document
  ///   6. Update stream.totalGifts (display counter)
  ///
  /// All five writes commit atomically — either the gift is sent and the
  /// balances reflect it, or nothing changes.
  Future<void> sendGift({
    required String streamId,
    required String senderUid,
    required String senderUsername,
    required String recipientUid,
    required GiftType giftType,
    int quantity = 1,
  }) async {
    final totalCoins = giftType.coinCost * quantity;
    final totalDiamonds = giftType.diamondYield * quantity;

    final walletRef = _db.collection('users').doc(senderUid)
        .collection('wallet').doc('default');
    final creatorBalRef = _db.collection('users').doc(recipientUid)
        .collection('creatorBalance').doc('default');
    final streamRef = _db.collection('streams').doc(streamId);
    final giftRef = streamRef.collection('gifts').doc(_uuid.v4());

    await _db.runTransaction((txn) async {
      final walletSnap = await txn.get(walletRef);
      final current = (walletSnap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (current < totalCoins) {
        throw InsufficientCoinsException(needed: totalCoins, has: current);
      }

      txn.set(walletRef, {
        'coins': FieldValue.increment(-totalCoins),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(creatorBalRef, {
        'diamonds': FieldValue.increment(totalDiamonds),
        'lifetimeDiamonds': FieldValue.increment(totalDiamonds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final event = GiftEvent(
        id: giftRef.id,
        streamId: streamId,
        senderUid: senderUid,
        senderUsername: senderUsername,
        giftTypeId: giftType.id,
        quantity: quantity,
        totalCoins: totalCoins,
        totalDiamondYield: totalDiamonds,
        sentAt: DateTime.now(),
      );
      txn.set(giftRef, event.toJson());

      txn.update(streamRef, {'totalGifts': FieldValue.increment(totalCoins)});
    });
  }

  /// Push the latest detected products + matched ad to all viewers of a stream.
  /// Called by the Studio after each visual/spoken scan.
  Future<void> publishProducts(
    String streamId,
    List<ProductInfo> products,
    Ad? matchedAd,
  ) async {
    await _db.collection('streams').doc(streamId).update({
      'featuredProducts': products.map((p) => p.toJson()).toList(),
      'featuredAd': matchedAd?.toJson(),
    });
  }

  /// Clear the detected products / ad surface for all viewers.
  Future<void> dismissProducts(String streamId) async {
    await _db.collection('streams').doc(streamId).update({
      'featuredProducts': <Map<String, dynamic>>[],
      'featuredAd': null,
    });
  }

  Stream<List<GiftEvent>> watchGifts(String streamId) {
    return _db
        .collection('streams')
        .doc(streamId)
        .collection('gifts')
        .orderBy('sentAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GiftEvent.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }
}
