import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cohost.dart';

class CoHostService {
  final _db = FirebaseFirestore.instance;

  Stream<List<CoHost>> watchCohosts(String streamId) {
    return _db
        .collection('streams')
        .doc(streamId)
        .collection('cohosts')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CoHost.fromJson({...d.data(), 'uid': d.id}))
            .toList());
  }

  Future<void> inviteCoHost({
    required String streamId,
    required String hostUsername,
    required String targetUid,
    required String targetUsername,
    String? targetAvatarUrl,
  }) async {
    final batch = _db.batch();
    // Write to stream cohost list
    batch.set(
      _db.collection('streams').doc(streamId).collection('cohosts').doc(targetUid),
      {
        'uid': targetUid,
        'username': targetUsername,
        'avatarUrl': targetAvatarUrl,
        'status': 'invited',
        'invitedAt': FieldValue.serverTimestamp(),
      },
    );
    // Denormalised invite on the user's profile
    batch.set(
      _db.collection('users').doc(targetUid).collection('cohost_invites').doc('latest'),
      {
        'streamId': streamId,
        'hostUsername': hostUsername,
        'status': 'invited',
        'invitedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<void> acceptInvite(String streamId, String uid) async {
    await _db
        .collection('streams')
        .doc(streamId)
        .collection('cohosts')
        .doc(uid)
        .update({'status': 'accepted'});
    await _db
        .collection('users')
        .doc(uid)
        .collection('cohost_invites')
        .doc('latest')
        .update({'status': 'accepted'});
  }

  Future<void> setActive(String streamId, String uid) async {
    await _db
        .collection('streams')
        .doc(streamId)
        .collection('cohosts')
        .doc(uid)
        .update({'status': 'active', 'joinedAt': FieldValue.serverTimestamp()});
  }

  Future<void> declineInvite(String streamId, String uid) async {
    await _db
        .collection('streams')
        .doc(streamId)
        .collection('cohosts')
        .doc(uid)
        .update({'status': 'declined'});
    await _db
        .collection('users')
        .doc(uid)
        .collection('cohost_invites')
        .doc('latest')
        .update({'status': 'declined'});
  }

  Stream<Map<String, dynamic>?> watchPendingInvite(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('cohost_invites')
        .doc('latest')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] == 'invited') return data;
      return null;
    });
  }
}
