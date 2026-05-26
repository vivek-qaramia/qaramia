import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gift.dart';

/// Streams the gift catalog from Firestore (`giftCatalog/{giftId}`). The
/// app reads from here at runtime so Qaramia ops can add/remove/edit gifts
/// without an app release.
///
/// If the Firestore collection is empty (e.g. before the seed Cloud
/// Function has run) or the request fails, callers should fall back to
/// the in-code [GiftType.catalog] static list — that's wired in the
/// provider so individual UI widgets don't have to handle this.
class GiftCatalogService {
  final _db = FirebaseFirestore.instance;

  Stream<List<GiftType>> watchCatalog() {
    return _db
        .collection('giftCatalog')
        .orderBy('coinCost')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<GiftType>> fetchCatalog() async {
    final snap =
        await _db.collection('giftCatalog').orderBy('coinCost').get();
    return snap.docs.map(_fromDoc).toList();
  }

  static GiftType _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return GiftType(
      id: doc.id,
      name: data['name'] as String,
      emoji: data['emoji'] as String,
      coinCost: (data['coinCost'] as num).toInt(),
      diamondYield: (data['diamondYield'] as num).toInt(),
      tier: _parseTier(data['tier'] as String?),
      animationAsset:
          data['animationAsset'] as String? ?? (doc.id),
    );
  }

  static GiftTier _parseTier(String? raw) {
    switch (raw) {
      case 'premium':
        return GiftTier.premium;
      case 'whale':
        return GiftTier.whale;
      case 'standard':
      default:
        return GiftTier.standard;
    }
  }
}
