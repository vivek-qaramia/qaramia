import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video.dart';

class VideoService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Video>> watchFeed({int limit = 20}) {
    return _db
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Video.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<List<Video>> fetchUserVideos(String uid) async {
    final snap = await _db
        .collection('videos')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Video.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<void> likeVideo(String videoId, String uid) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('videos').doc(videoId).collection('likes').doc(uid),
      {'likedAt': FieldValue.serverTimestamp()},
    );
    batch.update(_db.collection('videos').doc(videoId), {
      'likeCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> unlikeVideo(String videoId, String uid) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection('videos').doc(videoId).collection('likes').doc(uid),
    );
    batch.update(_db.collection('videos').doc(videoId), {
      'likeCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<bool> hasLiked(String videoId, String uid) async {
    final doc = await _db
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(uid)
        .get();
    return doc.exists;
  }

  Future<void> incrementView(String videoId) async {
    await _db.collection('videos').doc(videoId).update({
      'viewCount': FieldValue.increment(1),
    });
  }
}
