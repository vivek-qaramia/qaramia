import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ad.dart';
import '../services/ad_service.dart';
import '../services/iap_service.dart';
import '../services/product_scanner_service.dart';

final adServiceProvider = Provider((ref) => AdService());
final productScannerServiceProvider = Provider((ref) => ProductScannerService());

/// IapService is a singleton with a long-running purchaseStream subscription.
/// Created lazily on first access (typically when the wallet screen opens).
final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of the current advertiser's ads.
final myAdsProvider = StreamProvider.family<List<Ad>, String>((ref, advertiserUid) {
  return ref.watch(adServiceProvider).watchMyAds(advertiserUid);
});
