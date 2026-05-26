import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gift.dart';
import '../models/live_stream.dart';
import '../models/sponsorship.dart';
import '../providers/providers.dart';
import '../providers/sponsorship_providers.dart';
import '../providers/wallet_providers.dart';
import '../theme/brand.dart';

/// Tiered gift picker for a live stream.
///
/// Sponsored gifts (currently active + applicable to this streamer) appear in
/// a dedicated row at the top with brand styling. Below that, the standard
/// catalogue is grouped by tier (Standard / Premium / Whale). Gifts the
/// viewer can't afford are visually dimmed but still tappable — the
/// transactional sendGift will surface the "TOP UP" SnackBar.
class GiftPanel extends ConsumerWidget {
  final LiveStream stream;
  final void Function(GiftType, {Sponsorship? sponsorship}) onGiftSelected;

  const GiftPanel({super.key, required this.stream, required this.onGiftSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final coins = user == null
        ? 0
        : ref.watch(walletProvider(user.uid)).valueOrNull?.coins ?? 0;
    final sponsorshipsAsync = ref.watch(activeSponsorshipsProvider);

    // Collect product keywords / categories from currently featured products
    final keywords = <String>[];
    final categories = <String>[];
    for (final p in stream.featuredProducts) {
      for (final field in [p.brand, p.name]) {
        if (field == null) continue;
        keywords.addAll(field.toLowerCase().split(RegExp(r'[\s,]+')).where((t) => t.length > 1));
      }
      if (p.category != null) categories.add(p.category!);
    }

    final applicableSponsorships = sponsorshipsAsync.valueOrNull
            ?.where((s) => s.appliesTo(
                  streamerUid: stream.hostUid,
                  streamProductKeywords: keywords,
                  streamProductCategories: categories,
                ))
            .toList() ??
        const [];

    final catalog = ref.watch(giftCatalogProvider);
    final byTier = {
      GiftTier.standard: catalog.where((g) => g.tier == GiftTier.standard).toList(),
      GiftTier.premium:  catalog.where((g) => g.tier == GiftTier.premium).toList(),
      GiftTier.whale:    catalog.where((g) => g.tier == GiftTier.whale).toList(),
    };

    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: const BoxDecoration(
        color: Color(0xEE14060C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle + balance
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Send a Gift',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$coins',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  if (applicableSponsorships.isNotEmpty)
                    _SponsoredRow(
                      sponsorships: applicableSponsorships,
                      coins: coins,
                      onSelected: onGiftSelected,
                    ),
                  _TierSection(label: 'Standard', tier: GiftTier.standard, gifts: byTier[GiftTier.standard]!, coins: coins, onSelected: onGiftSelected),
                  _TierSection(label: 'Premium',  tier: GiftTier.premium,  gifts: byTier[GiftTier.premium]!,  coins: coins, onSelected: onGiftSelected),
                  _TierSection(label: 'Whale',    tier: GiftTier.whale,    gifts: byTier[GiftTier.whale]!,    coins: coins, onSelected: onGiftSelected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  final String label;
  final GiftTier tier;
  final List<GiftType> gifts;
  final int coins;
  final void Function(GiftType, {Sponsorship? sponsorship}) onSelected;

  const _TierSection({
    required this.label,
    required this.tier,
    required this.gifts,
    required this.coins,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = switch (tier) {
      GiftTier.standard => Colors.white70,
      GiftTier.premium => QBrand.primary,
      GiftTier.whale => QBrand.love,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(label.toUpperCase(),
                style: TextStyle(color: tierColor, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: gifts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _GiftTile(gift: gifts[i], coins: coins, onTap: () => onSelected(gifts[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredRow extends ConsumerWidget {
  final List<Sponsorship> sponsorships;
  final int coins;
  final void Function(GiftType, {Sponsorship? sponsorship}) onSelected;

  const _SponsoredRow({
    required this.sponsorships,
    required this.coins,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(giftCatalogProvider);
    final pairs = <(GiftType, Sponsorship)>[];
    for (final s in sponsorships) {
      final g = catalog.where((g) => g.id == s.giftTypeId).firstOrNull;
      if (g != null) pairs.add((g, s));
    }
    if (pairs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 12, color: QBrand.gold),
              const SizedBox(width: 4),
              Text('SPONSORED',
                  style: TextStyle(color: QBrand.gold, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: pairs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (gift, sponsorship) = pairs[i];
              return _GiftTile(
                gift: gift,
                coins: coins,
                sponsorship: sponsorship,
                onTap: () => onSelected(gift, sponsorship: sponsorship),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        ),
      ],
    );
  }
}

class _GiftTile extends StatelessWidget {
  final GiftType gift;
  final int coins;
  final Sponsorship? sponsorship;
  final VoidCallback onTap;

  const _GiftTile({
    required this.gift,
    required this.coins,
    this.sponsorship,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePrice = sponsorship?.viewerCoinCost(gift.coinCost) ?? gift.coinCost;
    final canAfford = coins >= effectivePrice;
    final showFree = effectivePrice == 0;
    final showDiscount = sponsorship != null &&
        sponsorship!.pricingModel == SponsorshipPricingModel.discounted &&
        effectivePrice < gift.coinCost;

    return Opacity(
      opacity: canAfford ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 68,
          decoration: BoxDecoration(
            color: sponsorship != null
                ? QBrand.gold.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sponsorship != null
                  ? QBrand.gold.withValues(alpha: 0.4)
                  : Colors.white12,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(gift.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 2),
              Text(gift.name,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (showFree)
                Text('FREE',
                    style: TextStyle(color: QBrand.gold, fontSize: 9, fontWeight: FontWeight.w900))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 8)),
                    const SizedBox(width: 2),
                    if (showDiscount) ...[
                      Text('$effectivePrice',
                          style: const TextStyle(color: QBrand.gold, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 3),
                      Text('${gift.coinCost}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                          )),
                    ] else
                      Text('$effectivePrice',
                          style: TextStyle(
                            color: canAfford ? QBrand.gold : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                  ],
                ),
              if (sponsorship != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sponsorship!.brandName,
                      style: const TextStyle(color: QBrand.gold, fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
