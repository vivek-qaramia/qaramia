import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  Stream<AppUser?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (snap) =>
              snap.exists ? AppUser.fromJson({...snap.data()!, 'uid': snap.id}) : null,
        );
  }

  Future<void> followUser(String currentUid, String targetUid) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(currentUid).collection('following').doc(targetUid),
      {'followedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(currentUid),
      {'followedAt': FieldValue.serverTimestamp()},
    );
    batch.update(_db.collection('users').doc(currentUid), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'followerCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> unfollowUser(String currentUid, String targetUid) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection('users').doc(currentUid).collection('following').doc(targetUid),
    );
    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(currentUid),
    );
    batch.update(_db.collection('users').doc(currentUid), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'followerCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: '${query}z')
        .limit(20)
        .get();
    return snap.docs
        .map((d) => AppUser.fromJson({...d.data(), 'uid': d.id}))
        .toList();
  }
}
