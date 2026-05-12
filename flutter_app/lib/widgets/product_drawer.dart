import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';
import '../models/product_info.dart';
import '../providers/ad_providers.dart';
import '../theme/brand.dart';
import '../utils/affiliate.dart';

/// Viewer-facing live-commerce surface.
///
/// Renders a floating 🛍 button while products are detected; tapping it opens
/// a slide-up drawer showing either the matched paid ad or an Amazon affiliate
/// card, followed by per-product Buy ↗ rows.
class ProductDrawer extends ConsumerStatefulWidget {
  final List<ProductInfo> products;
  final Ad? featuredAd;
  final VoidCallback? onClose;
  final VoidCallback? onAffiliateClick;

  const ProductDrawer({
    super.key,
    required this.products,
    this.featuredAd,
    this.onClose,
    this.onAffiliateClick,
  });

  @override
  ConsumerState<ProductDrawer> createState() => _ProductDrawerState();
}

class _ProductDrawerState extends ConsumerState<ProductDrawer> with TickerProviderStateMixin {
  bool _open = false;
  bool _pulsing = false;
  String? _trackedAdId; // last ad ID this session has logged an impression for

  @override
  void didUpdateWidget(covariant ProductDrawer old) {
    super.didUpdateWidget(old);
    // Pulse the icon when a new detection event arrives
    if (widget.products.length != old.products.length ||
        (widget.products.isNotEmpty && old.products.isNotEmpty &&
         widget.products.first.name != old.products.first.name)) {
      _pulse();
    }
    if (widget.products.isEmpty) {
      _open = false;
    }
  }

  void _pulse() {
    setState(() => _pulsing = true);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _pulsing = false);
    });
  }

  /// MRC-style impression: counted only after the drawer has been open ≥ 1s
  /// and only once per ad ID per session.
  void _scheduleImpression() {
    final ad = widget.featuredAd;
    if (ad == null || _trackedAdId == ad.id) return;
    final adId = ad.id;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (!_open || widget.featuredAd?.id != adId) return;
      _trackedAdId = adId;
      ref.read(adServiceProvider).trackImpression(adId).catchError((_) {});
    });
  }

  Future<void> _openCta(String url, {String? adId}) async {
    if (adId != null) {
      ref.read(adServiceProvider).trackClick(adId).catchError((_) {});
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        // Floating bag icon (lower-right of stream)
        Positioned(
          right: 16,
          bottom: 96,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            scale: _pulsing ? 1.25 : 1.0,
            child: GestureDetector(
              onTap: () {
                setState(() => _open = !_open);
                if (_open) _scheduleImpression();
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('🛍', style: TextStyle(fontSize: 22)),
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          color: QBrand.peach,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.products.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Slide-up drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: _open ? 0 : -360,
          child: _Drawer(
            products: widget.products,
            featuredAd: widget.featuredAd,
            onClose: () {
              setState(() => _open = false);
              widget.onClose?.call();
            },
            onSponsoredTap: () {
              if (widget.featuredAd != null) {
                _openCta(widget.featuredAd!.ctaUrl, adId: widget.featuredAd!.id);
              }
            },
            onAffiliateTap: (url) {
              widget.onAffiliateClick?.call();
              _openCta(url);
            },
          ),
        ),
      ],
    );
  }
}

class _Drawer extends StatelessWidget {
  final List<ProductInfo> products;
  final Ad? featuredAd;
  final VoidCallback onClose;
  final VoidCallback onSponsoredTap;
  final ValueChanged<String> onAffiliateTap;

  const _Drawer({
    required this.products,
    required this.featuredAd,
    required this.onClose,
    required this.onSponsoredTap,
    required this.onAffiliateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xCC1A0F18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32, height: 3,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    products.length == 1 ? '1 product spotted' : '${products.length} products spotted',
                    style: const TextStyle(color: QBrand.fgMute, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white54, size: 18)),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (featuredAd != null)
                    _SponsoredCard(ad: featuredAd!, onTap: onSponsoredTap)
                  else
                    _AffiliateCard(products: products, onTap: onAffiliateTap),
                  const SizedBox(height: 12),
                  for (final p in products) ...[
                    _ProductRow(product: p, onBuyTap: onAffiliateTap),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsoredCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  const _SponsoredCard({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ad.imageUrl != null)
            Image.network(ad.imageUrl!, height: 96, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SPONSORED', style: TextStyle(color: QBrand.fgDim, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ad.headline,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: QBrand.peach,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(ad.ctaText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliateCard extends StatelessWidget {
  final List<ProductInfo> products;
  final ValueChanged<String> onTap;
  const _AffiliateCard({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = products.first;
    final query = [first.brand, first.name].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (query.isEmpty) return const SizedBox.shrink();
    final label = products.length == 1
        ? 'Find "${first.name ?? first.brand}" on Amazon'
        : 'Shop ${products.length} products on Amazon';
    return InkWell(
      onTap: () => onTap(affiliateUrl(query)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x1AFF9900),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FF9900)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AFFILIATE', style: TextStyle(color: Color(0x99FF9900), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Text('→', style: TextStyle(color: Color(0xFFFF9900), fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductInfo product;
  final ValueChanged<String> onBuyTap;
  const _ProductRow({required this.product, required this.onBuyTap});

  @override
  Widget build(BuildContext context) {
    final query = [product.brand, product.name].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final hasQuery = query.isNotEmpty;
    return Row(
      children: [
        if (product.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(product.imageUrl!, width: 40, height: 40, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _sourceBadge(product)),
          )
        else
          _sourceBadge(product),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null && product.brand!.isNotEmpty)
                Text(product.brand!,
                    style: const TextStyle(color: QBrand.fgMute, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(product.name ?? 'Unknown product',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (hasQuery)
          GestureDetector(
            onTap: () => onBuyTap(affiliateUrl(query)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: QBrand.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('Buy ↗',
                  style: TextStyle(color: QBrand.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _sourceBadge(ProductInfo product) {
    final emoji = switch (product.source) {
      ProductSource.barcode => '📦',
      ProductSource.speech => '🎙',
      ProductSource.vision => '🔍',
    };
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
