import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ad.dart';
import '../services/ad_service.dart';
import '../services/product_scanner_service.dart';

final adServiceProvider = Provider((ref) => AdService());
final productScannerServiceProvider = Provider((ref) => ProductScannerService());

/// Stream of the current advertiser's ads.
final myAdsProvider = StreamProvider.family<List<Ad>, String>((ref, advertiserUid) {
  return ref.watch(adServiceProvider).watchMyAds(advertiserUid);
});
