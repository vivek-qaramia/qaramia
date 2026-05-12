import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/live_stream.dart';
import '../models/gift.dart';
import '../models/product_info.dart';
import '../models/ad.dart';

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

  Future<void> updateViewerCount(String streamId, int delta) async {
    await _db.collection('streams').doc(streamId).update({
      'viewerCount': FieldValue.increment(delta),
    });
  }

  Future<void> sendGift({
    required String streamId,
    required String senderUid,
    required String senderUsername,
    required GiftType giftType,
    int quantity = 1,
  }) async {
    final id = _uuid.v4();
    final event = GiftEvent(
      id: id,
      streamId: streamId,
      senderUid: senderUid,
      senderUsername: senderUsername,
      giftTypeId: giftType.id,
      quantity: quantity,
      totalCoins: giftType.coinCost * quantity,
      sentAt: DateTime.now(),
    );
    final batch = _db.batch();
    batch.set(_db.collection('streams').doc(streamId).collection('gifts').doc(id),
        event.toJson());
    batch.update(_db.collection('streams').doc(streamId), {
      'totalGifts': FieldValue.increment(event.totalCoins),
    });
    await batch.commit();
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
