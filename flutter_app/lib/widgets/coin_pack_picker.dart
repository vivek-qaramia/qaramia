import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/wallet.dart';
import '../providers/ad_providers.dart';
import '../services/iap_service.dart';
import '../theme/brand.dart';

/// Lists every coin pack and triggers the platform-appropriate IAP flow on tap.
///
/// Listens to IapService.status so the UI can surface "pending", "success",
/// "error" feedback inline. The wallet balance updates separately via the
/// Firestore stream once the Cloud Function credits coins.
class CoinPackPicker extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseComplete;
  const CoinPackPicker({super.key, this.onPurchaseComplete});

  @override
  ConsumerState<CoinPackPicker> createState() => _CoinPackPickerState();
}

class _CoinPackPickerState extends ConsumerState<CoinPackPicker> {
  String? _pendingPackId;
  String? _statusMessage;
  Map<String, ProductDetails> _productsByPackId = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    final iap = ref.read(iapServiceProvider);
    iap.status.listen(_handleStatus);
  }

  Future<void> _loadProducts() async {
    final iap = ref.read(iapServiceProvider);
    final products = await iap.queryProducts();
    final byId = <String, ProductDetails>{};
    for (final p in products) {
      final pack = CoinPack.findByProductId(p.id);
      if (pack != null) byId[pack.id] = p;
    }
    if (mounted) setState(() => _productsByPackId = byId);
  }

  void _handleStatus(IapStatus status) {
    if (!mounted) return;
    switch (status.type) {
      case IapStatusType.pending:
        setState(() => _statusMessage = 'Confirming with App Store…');
        break;
      case IapStatusType.success:
        setState(() {
          _statusMessage = '+${status.creditedCoins ?? 0} coins added';
          _pendingPackId = null;
        });
        widget.onPurchaseComplete?.call();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _statusMessage = null);
        });
        break;
      case IapStatusType.error:
        setState(() {
          _statusMessage = status.message ?? 'Purchase failed';
          _pendingPackId = null;
        });
        break;
      case IapStatusType.cancelled:
        setState(() {
          _statusMessage = null;
          _pendingPackId = null;
        });
        break;
      case IapStatusType.unavailable:
        setState(() => _statusMessage = 'In-app purchase unavailable on this device.');
        break;
    }
  }

  Future<void> _buy(CoinPack pack) async {
    if (_pendingPackId != null) return;
    setState(() { _pendingPackId = pack.id; _statusMessage = null; });
    final ok = await ref.read(iapServiceProvider).buyPack(pack);
    if (!ok && mounted) {
      setState(() {
        _pendingPackId = null;
        _statusMessage = 'Could not initiate purchase.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Text('Top up coins',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: QBrand.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: QBrand.primary.withValues(alpha: 0.4)),
            ),
            child: Text(_statusMessage!,
                style: const TextStyle(color: QBrand.fg, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        for (final pack in CoinPack.catalog) ...[
          _PackTile(
            pack: pack,
            product: _productsByPackId[pack.id],
            pending: _pendingPackId == pack.id,
            onTap: () => _buy(pack),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        const Text(
          'Coins have no cash value, are non-refundable once spent, and cannot be transferred.',
          style: TextStyle(color: QBrand.fgDim, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PackTile extends StatelessWidget {
  final CoinPack pack;
  final ProductDetails? product;
  final bool pending;
  final VoidCallback onTap;

  const _PackTile({
    required this.pack,
    required this.product,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = pack.totalCoins;
    final ratePer1k = ((pack.priceUsd / total) * 1000).toStringAsFixed(2);
    final displayPrice = product?.price ?? '\$${pack.priceUsd.toStringAsFixed(2)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: pending ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: QBrand.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QBrand.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: QBrand.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🪙', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(pack.label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (pack.bonusCoins > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: QBrand.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '+${(pack.bonusCoins / pack.coins * 100).round()}% bonus',
                              style: const TextStyle(color: QBrand.gold, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${total.toLocaleString()} coins · \$$ratePer1k per 1,000',
                      style: const TextStyle(color: QBrand.fgMute, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (pending)
                const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: QBrand.primary))
              else
                Text(displayPrice,
                    style: const TextStyle(
                      color: QBrand.primary, fontSize: 16, fontWeight: FontWeight.w800,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// Tiny helper because Dart's int doesn't have a locale-aware toString.
extension on int {
  String toLocaleString() {
    final s = toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
