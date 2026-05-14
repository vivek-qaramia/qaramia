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
/// Floating 🛍 button when products are detected; tap opens a white slide-up
/// drawer (template-aligned) with numbered product rows, star ratings, prices
/// in indigo, and pill "Add to bag" CTAs.
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
  String? _trackedAdId;

  @override
  void didUpdateWidget(covariant ProductDrawer old) {
    super.didUpdateWidget(old);
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
        // Floating bag icon — white pill with indigo count badge (template style).
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
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('🛍', style: TextStyle(fontSize: 24)),
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: QBrand.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
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

        // Slide-up white drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: _open ? 0 : -520,
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: QBrand.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Header: "Product (N)" + close
            Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: QBrand.fg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Product (${products.length})',
                    style: const TextStyle(color: QBrand.fg, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                // Small purple-bordered chat-bubble icon with count (decorative, matches template)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: QBrand.cardAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: QBrand.fg, size: 16),
                    ),
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: QBrand.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${products.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (featuredAd != null) ...[
                    _SponsoredCard(ad: featuredAd!, onTap: onSponsoredTap),
                    const SizedBox(height: 14),
                  ] else ...[
                    _AffiliateCard(products: products, onTap: onAffiliateTap),
                    const SizedBox(height: 14),
                  ],
                  for (int i = 0; i < products.length; i++) ...[
                    _ProductRow(
                      index: i + 1,
                      product: products[i],
                      onBuyTap: onAffiliateTap,
                    ),
                    if (i < products.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: QBrand.hairline),
                      ),
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
        color: QBrand.primaryDim,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ad.imageUrl != null)
            Image.network(ad.imageUrl!, height: 96, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SPONSORED',
                          style: TextStyle(color: QBrand.primaryDeep, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(ad.headline,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: QBrand.fg),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: QBrand.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: QBrand.cardAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AFFILIATE',
                      style: TextStyle(color: QBrand.fgMute, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: QBrand.fg),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: QBrand.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int index;
  final ProductInfo product;
  final ValueChanged<String> onBuyTap;
  const _ProductRow({required this.index, required this.product, required this.onBuyTap});

  @override
  Widget build(BuildContext context) {
    final query = [product.brand, product.name].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final hasQuery = query.isNotEmpty;
    final priceText = _displayPrice(product);
    final rating = _displayRating(product);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl != null
                  ? Image.network(product.imageUrl!, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _sourceBadge())
                  : _sourceBadge(),
            ),
            Positioned(
              left: -4, top: -4,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: QBrand.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text('$index',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (product.name ?? product.brand ?? 'Unknown product').toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: QBrand.fg),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: QBrand.gold, size: 14),
                    const SizedBox(width: 2),
                    Text(rating,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: QBrand.fg)),
                  ],
                ),
              ],
              if (priceText != null) ...[
                const SizedBox(height: 4),
                Text(
                  priceText,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: QBrand.primary),
                ),
              ],
            ],
          ),
        ),
        if (hasQuery)
          GestureDetector(
            onTap: () => onBuyTap(affiliateUrl(query)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: QBrand.cardAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Add to bag',
                  style: TextStyle(color: QBrand.fg, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _sourceBadge() {
    final emoji = switch (product.source) {
      ProductSource.barcode => '📦',
      ProductSource.speech => '🎙',
      ProductSource.vision => '🔍',
    };
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: QBrand.cardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }

  String? _displayPrice(ProductInfo p) {
    final px = p.price;
    if (px == null || px <= 0) return null;
    return '\$ ${px.toStringAsFixed(px == px.roundToDouble() ? 0 : 2)}';
  }

  String? _displayRating(ProductInfo p) {
    final r = p.rating;
    final c = p.reviewCount;
    if (r == null && c == null) return null;
    final rs = r != null ? r.toStringAsFixed(1) : '—';
    final cs = c != null ? ' ($c reviews)' : '';
    return '$rs$cs';
  }
}
