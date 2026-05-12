import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/wallet.dart';

/// Thin wrapper around the `in_app_purchase` plugin that drives the coin-pack
/// purchase flow end-to-end:
///
///   1. Query store metadata for the registered product IDs
///   2. Trigger a consumable purchase via `buyConsumable`
///   3. Listen on `purchaseStream` for status updates
///   4. On purchase or restore, call the validate*Purchase Cloud Function
///   5. Once validated, mark the local purchase complete so the OS retries
///      stop firing
///
/// The Cloud Function is authoritative: it verifies the receipt with Apple /
/// Google and atomically credits Firestore `users/{uid}/wallet/default`. The
/// wallet UI subscribes via Riverpod and reflects the new balance.
class IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _statusController = StreamController<IapStatus>.broadcast();
  Stream<IapStatus> get status => _statusController.stream;

  IapService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Call once during app startup. Boots the platform listener and surfaces
  /// purchase events on [status].
  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      _statusController.add(const IapStatus.unavailable());
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (err) => _statusController.add(IapStatus.error('$err')),
    );
  }

  /// Look up store metadata (localised price + title) for every registered
  /// pack. Run-time prices may differ from CoinPack.priceUsd because Apple /
  /// Google deliver them in the user's local currency tier.
  Future<List<ProductDetails>> queryProducts() async {
    final response = await _iap.queryProductDetails(CoinPack.allProductIds);
    return response.productDetails;
  }

  /// Initiate the purchase flow for a single coin pack. The actual coin credit
  /// happens later, when the platform delivers the purchase via [purchaseStream]
  /// and the validate*Purchase Cloud Function confirms it.
  Future<bool> buyPack(CoinPack pack) async {
    final productId = pack.iosProductId ?? pack.androidProductId;
    if (productId == null) return false;

    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      _statusController.add(IapStatus.error(
        'Product $productId not configured in App Store Connect / Play Console',
      ));
      return false;
    }
    final product = response.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyConsumable(purchaseParam: param);
  }

  /// Re-deliver any purchases that the OS still considers "pending delivery".
  /// Safe to call at app start so we don't lose a purchase made while offline.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _statusController.add(IapStatus.pending(purchase.productID));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final coins = await _verifyAndCredit(purchase);
            _statusController.add(IapStatus.success(purchase.productID, coins));
          } catch (e) {
            _statusController.add(IapStatus.error('Verification failed: $e'));
          }
          // ALWAYS complete the purchase or the OS will keep re-delivering it.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          _statusController.add(IapStatus.error(
            purchase.error?.message ?? 'Unknown purchase error',
          ));
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          _statusController.add(const IapStatus.cancelled());
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Hand the verification data to the platform-specific Cloud Function and
  /// return the credited coin count. Throws on validation failure.
  Future<int> _verifyAndCredit(PurchaseDetails purchase) async {
    final verificationData = purchase.verificationData.serverVerificationData;
    final productId = purchase.productID;

    if (Platform.isIOS) {
      final res = await _functions.httpsCallable('validateApplePurchase').call({
        'receiptData': verificationData,
        'productId': productId,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['coins'] as num?)?.toInt() ?? 0;
    }
    if (Platform.isAndroid) {
      // verificationData on Android is the purchase token
      final res = await _functions.httpsCallable('validateGooglePurchase').call({
        'purchaseToken': verificationData,
        'productId': productId,
        'packageName': _androidPackageName,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['coins'] as num?)?.toInt() ?? 0;
    }
    throw UnsupportedError('IAP only supported on iOS and Android');
  }

  // Mirror the applicationId from android/app/build.gradle.kts. Hardcoded
  // because the Flutter plugin doesn't expose the package name natively
  // until we ship a custom platform channel.
  static const _androidPackageName = 'com.streamr.streamr';

  Future<void> dispose() async {
    await _sub?.cancel();
    await _statusController.close();
  }
}

/// Lifecycle event emitted by IapService.status.
class IapStatus {
  final IapStatusType type;
  final String? productId;
  final int? creditedCoins;
  final String? message;

  const IapStatus._(this.type, {this.productId, this.creditedCoins, this.message});

  const IapStatus.unavailable() : this._(IapStatusType.unavailable);
  const IapStatus.cancelled() : this._(IapStatusType.cancelled);
  const IapStatus.pending(String pid) : this._(IapStatusType.pending, productId: pid);
  const IapStatus.success(String pid, int coins)
      : this._(IapStatusType.success, productId: pid, creditedCoins: coins);
  const IapStatus.error(String msg) : this._(IapStatusType.error, message: msg);
}

enum IapStatusType { unavailable, pending, success, error, cancelled }
