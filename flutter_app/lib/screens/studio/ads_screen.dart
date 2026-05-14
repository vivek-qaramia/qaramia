import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ad.dart';
import '../../models/product_info.dart';
import '../../providers/providers.dart';
import '../../providers/ad_providers.dart';
import '../../theme/brand.dart';

class AdsScreen extends ConsumerWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in to manage ads.')));
    }
    final adsAsync = ref.watch(myAdsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _CreateAdScreen(),
            )),
          ),
        ],
      ),
      body: adsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: QBrand.primary)),
        error: (e, _) => Center(child: Text('Failed to load ads: $e')),
        data: (ads) => ads.isEmpty
            ? _EmptyState(onCreate: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _CreateAdScreen(),
                )))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ads.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _AdRow(ad: ads[i]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📢', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No ads yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Create an ad to appear when matching products are spotted in live streams.',
              textAlign: TextAlign.center,
              style: TextStyle(color: QBrand.fgMute),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create your first ad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdRow extends ConsumerWidget {
  final Ad ad;
  const _AdRow({required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrPct = ad.impressions > 0
        ? '${(ad.ctr * 100).toStringAsFixed(1)}%'
        : '—';
    final isActive = ad.status == AdStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: QBrand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ad.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(ad.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            )
          else
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: QBrand.cardAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign, color: QBrand.fgDim),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.headline,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(ad.ctaUrl,
                    style: const TextStyle(color: QBrand.fgMute, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    for (final k in ad.keywords)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: QBrand.cardAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(k, style: const TextStyle(fontSize: 10, color: QBrand.fgMute)),
                      ),
                    for (final c in ad.categories)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: QBrand.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 10, color: QBrand.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('👁 ${ad.impressions}', style: const TextStyle(fontSize: 11, color: QBrand.fgMute)),
                    const SizedBox(width: 12),
                    Text('🖱 ${ad.clicks}', style: const TextStyle(fontSize: 11, color: QBrand.fgMute)),
                    const SizedBox(width: 12),
                    Text('CTR $ctrPct', style: const TextStyle(fontSize: 11, color: QBrand.fgMute)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () => ref.read(adServiceProvider).updateAdStatus(
                      ad.id, isActive ? AdStatus.paused : AdStatus.active,
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Paused',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isActive ? Colors.greenAccent : QBrand.fgMute,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete ad?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(adServiceProvider).deleteAd(ad.id);
                  }
                },
                child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateAdScreen extends ConsumerStatefulWidget {
  const _CreateAdScreen();

  @override
  ConsumerState<_CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends ConsumerState<_CreateAdScreen> {
  final _headline = TextEditingController();
  final _ctaText = TextEditingController(text: 'Shop Now');
  final _ctaUrl = TextEditingController();
  final _imageUrl = TextEditingController();
  final _keywords = TextEditingController();
  final Set<String> _categories = {};
  bool _saving = false;

  @override
  void dispose() {
    _headline.dispose();
    _ctaText.dispose();
    _ctaUrl.dispose();
    _imageUrl.dispose();
    _keywords.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (_headline.text.trim().isEmpty || _ctaUrl.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(adServiceProvider).createAd(
            advertiserId: user.uid,
            advertiserName: user.displayName,
            headline: _headline.text.trim(),
            ctaText: _ctaText.text.trim().isEmpty ? 'Shop Now' : _ctaText.text.trim(),
            ctaUrl: _ctaUrl.text.trim(),
            imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
            keywords: _keywords.text.split(RegExp(r'[\s,]+')).where((k) => k.isNotEmpty).toList(),
            categories: _categories.toList(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Ad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _headline, decoration: const InputDecoration(labelText: 'Headline *')),
          const SizedBox(height: 12),
          TextField(controller: _ctaText, decoration: const InputDecoration(labelText: 'CTA button text')),
          const SizedBox(height: 12),
          TextField(controller: _ctaUrl, decoration: const InputDecoration(labelText: 'Destination URL *')),
          const SizedBox(height: 12),
          TextField(controller: _imageUrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
          const SizedBox(height: 12),
          TextField(
            controller: _keywords,
            decoration: const InputDecoration(
              labelText: 'Keywords',
              helperText: 'Comma-separated. e.g. nike, air max, sneaker',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Categories', style: TextStyle(color: QBrand.fgMute, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (final cat in productCategories)
                GestureDetector(
                  onTap: () => setState(() {
                    _categories.contains(cat) ? _categories.remove(cat) : _categories.add(cat);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _categories.contains(cat) ? QBrand.primary : Colors.white12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _categories.contains(cat) ? Colors.white : QBrand.fgMute,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Ad'),
          ),
        ],
      ),
    );
  }
}
