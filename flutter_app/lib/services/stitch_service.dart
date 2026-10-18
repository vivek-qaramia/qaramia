import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stitch_request.dart';

/// Stitch permission handshake: requester creates a 'pending' request, the
/// video owner approves or declines it.
class StitchService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('stitchRequests');

  Future<void> request({
    required String requesterUid,
    required String requesterUsername,
    required String ownerUid,
    required String videoId,
    required double startMs,
    required double endMs,
  }) {
    return _col.add({
      'requesterUid': requesterUid,
      'requesterUsername': requesterUsername,
      'ownerUid': ownerUid,
      'videoId': videoId,
      'startMs': startMs,
      'endMs': endMs,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respond(String requestId, {required bool approve}) {
    return _col.doc(requestId).update({
      'status': approve ? 'approved' : 'declined',
    });
  }

  /// Requests sent to [uid] (the inbox). Newest first, sorted client-side to
  /// avoid needing a composite index.
  Stream<List<StitchRequest>> watchIncoming(String uid) =>
      _watch(_col.where('ownerUid', isEqualTo: uid));

  /// Requests [uid] has sent, so they can see which ones were approved.
  Stream<List<StitchRequest>> watchSent(String uid) =>
      _watch(_col.where('requesterUid', isEqualTo: uid));

  Stream<List<StitchRequest>> _watch(Query<Map<String, dynamic>> q) {
    return q.snapshots().map((snap) {
      final list = snap.docs.map(StitchRequest.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }
}
