import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsorship.dart';

class SponsorshipService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('sponsorships');

  /// All currently-active sponsorships. The picker filters further by
  /// streamer UID + visible products via Sponsorship.appliesTo().
  Stream<List<Sponsorship>> watchActive() {
    return _col
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Sponsorship.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Record a sponsored-gift send. Increments send count + brand spend on
  /// the sponsorship doc, and writes a per-send ledger entry under
  /// sponsorships/{id}/sends/{txId} for downstream brand invoicing.
  Future<void> recordSend({
    required Sponsorship sponsorship,
    required String streamId,
    required String streamerUid,
    required String senderUid,
  }) async {
    final perSendCost = sponsorship.perSendRateUsd
        ?? sponsorship.creatorPayoutUsd
        ?? 0;
    final txRef = _col.doc(sponsorship.id).collection('sends').doc();
    final batch = _db.batch();
    batch.set(txRef, {
      'streamId': streamId,
      'streamerUid': streamerUid,
      'senderUid': senderUid,
      'brandCostUsd': perSendCost,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(_col.doc(sponsorship.id), {
      'totalSendCount': FieldValue.increment(1),
      'totalBrandSpendUsd': FieldValue.increment(perSendCost),
    });
    await batch.commit();
  }
}
