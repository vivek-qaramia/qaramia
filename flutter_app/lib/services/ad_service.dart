import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ad.dart';
import '../models/product_info.dart';

class AdService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ads => _db.collection('ads');

  // ── Tokenisation (mirrors web `tokenize` + `keywordsFromProducts`) ────────
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s,.!?;:]+'))
        .where((t) => t.length > 1)
        .toList();
  }

  List<String> keywordsFromProducts(List<ProductInfo> products) {
    final tokens = <String>[];
    for (final p in products) {
      tokens.addAll(_tokenize(p.brand ?? ''));
      tokens.addAll(_tokenize(p.name ?? ''));
    }
    return tokens.toSet().take(10).toList();
  }

  /// Match the best active ad for a set of detected products.
  ///
  /// Runs keyword + category queries in parallel, merges results, scores by
  /// keyword overlap (+0.5 bonus for category match), returns the highest-
  /// scoring ad or null.
  Future<Ad?> matchAd(List<ProductInfo> products) async {
    if (products.isEmpty) return null;

    final tokens = keywordsFromProducts(products);
    final category = products.first.category;

    final fetches = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    if (tokens.isNotEmpty) {
      fetches.add(_ads
          .where('status', isEqualTo: 'active')
          .where('keywords', arrayContainsAny: tokens)
          .get());
    }
    if (category != null && category.isNotEmpty) {
      fetches.add(_ads
          .where('status', isEqualTo: 'active')
          .where('categories', arrayContains: category)
          .get());
    }
    if (fetches.isEmpty) return null;

    final snaps = await Future.wait(fetches);

    final adMap = <String, Ad>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        adMap.putIfAbsent(
          doc.id,
          () => Ad.fromJson({...doc.data(), 'id': doc.id}),
        );
      }
    }
    if (adMap.isEmpty) return null;

    final tokenSet = tokens.toSet();
    Ad? best;
    double bestScore = 0;
    for (final ad in adMap.values) {
      var score = ad.keywords.where(tokenSet.contains).length.toDouble();
      if (category != null && ad.categories.contains(category)) score += 0.5;
      if (score > bestScore) {
        best = ad;
        bestScore = score;
      }
    }
    return best;
  }

  Future<void> trackImpression(String adId) async {
    await _ads.doc(adId).update({'impressions': FieldValue.increment(1)});
  }

  Future<void> trackClick(String adId) async {
    await _ads.doc(adId).update({'clicks': FieldValue.increment(1)});
  }

  // ── Advertiser-side management ────────────────────────────────────────────
  Stream<List<Ad>> watchMyAds(String advertiserUid) {
    return _ads
        .where('advertiserId', isEqualTo: advertiserUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Ad.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<Ad> createAd({
    required String advertiserId,
    required String advertiserName,
    required String headline,
    required String ctaUrl,
    String ctaText = 'Shop Now',
    String? imageUrl,
    List<String> keywords = const [],
    List<String> categories = const [],
  }) async {
    final docRef = _ads.doc();
    final ad = Ad(
      id: docRef.id,
      advertiserId: advertiserId,
      advertiserName: advertiserName,
      headline: headline,
      imageUrl: imageUrl,
      ctaText: ctaText,
      ctaUrl: ctaUrl,
      keywords: keywords.map((k) => k.toLowerCase().trim()).where((k) => k.length > 1).toList(),
      categories: categories,
      createdAt: DateTime.now(),
    );
    await docRef.set(ad.toJson()..['createdAt'] = FieldValue.serverTimestamp());
    return ad;
  }

  Future<void> updateAdStatus(String adId, AdStatus status) async {
    await _ads.doc(adId).update({'status': status.name});
  }

  Future<void> deleteAd(String adId) async {
    await _ads.doc(adId).delete();
  }
}
