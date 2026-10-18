import 'package:cloud_firestore/cloud_firestore.dart';

/// User A (requester) asks User B (owner) for permission to use the
/// [startMs]–[endMs] segment of B's video in a stitched clip.
/// [status] is 'pending', 'approved' or 'declined'; only B can change it.
class StitchRequest {
  final String id;
  final String requesterUid;
  final String requesterUsername;
  final String ownerUid;
  final String videoId;
  final double startMs;
  final double endMs;
  final String status;
  final DateTime? createdAt;

  const StitchRequest({
    required this.id,
    required this.requesterUid,
    required this.requesterUsername,
    required this.ownerUid,
    required this.videoId,
    required this.startMs,
    required this.endMs,
    required this.status,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  factory StitchRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return StitchRequest(
      id: doc.id,
      requesterUid: d['requesterUid'] as String,
      requesterUsername: d['requesterUsername'] as String? ?? '',
      ownerUid: d['ownerUid'] as String,
      videoId: d['videoId'] as String,
      startMs: (d['startMs'] as num).toDouble(),
      endMs: (d['endMs'] as num).toDouble(),
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
