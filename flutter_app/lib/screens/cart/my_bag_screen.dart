import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/cart_provider.dart';
import '../../theme/brand.dart';

/// Viewer-side bag screen — matches the third panel of the reference template.
///
/// Items are local to the device (Riverpod cartProvider). The "Checkout now"
/// pill launches a single aggregated Amazon affiliate search covering every
/// item in the bag; this app does not run its own payment rail.
class MyBagScreen extends ConsumerWidget {
  static const sizeOptions = ['S', 'M', 'L', 'XL', '38', '40', '42', '44'];

  const MyBagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final count = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Bag'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.chat_bubble_outline, size: 22),
                ),
                if (count > 0)
                  Positioned(
                    top: 2, right: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: QBrand.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Voucher banner (light indigo tint)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: QBrand.primaryDim,
            child: const Text(
              'Select a voucher to save your money  💰',
              textAlign: TextAlign.center,
              style: TextStyle(color: QBrand.primaryDeep, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? const _EmptyBag()
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: QBrand.hairline, height: 1),
                    ),
                    itemBuilder: (_, i) => _BagRow(item: items[i]),
                  ),
          ),

          // Voucher input row
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: QBrand.hairline)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: QBrand.primaryDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.confirmation_number_outlined, color: QBrand.primary, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Voucher HackLife',
                      style: TextStyle(color: QBrand.fg, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text('input your code',
                          style: TextStyle(color: QBrand.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: QBrand.primary, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Black checkout pill
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: items.isEmpty ? null : () => _checkout(items),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Checkout now',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        items.isEmpty ? '—' : 'Total \$${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(List<CartItem> items) async {
    final url = cartAffiliateUrl(items);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _EmptyBag extends StatelessWidget {
  const _EmptyBag();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛍', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('Your bag is empty',
                style: TextStyle(color: QBrand.fg, fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Tap "Add to bag" on a product to start.',
                style: TextStyle(color: QBrand.fgMute, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BagRow extends ConsumerWidget {
  final CartItem item;
  const _BagRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item.imageUrl != null
              ? Image.network(item.imageUrl!, width: 64, height: 64, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _thumbPlaceholder())
              : _thumbPlaceholder(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name.toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: QBrand.fg),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              _SizeChip(item: item, onChange: (s) => cart.setSize(item.id, s)),
              const SizedBox(height: 6),
              if (item.price != null)
                Text('\$ ${item.price!.toStringAsFixed(item.price! == item.price!.roundToDouble() ? 0 : 2)}',
                    style: const TextStyle(
                        color: QBrand.primary, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        _Stepper(
          quantity: item.quantity,
          onDecrement: () => cart.setQuantity(item.id, item.quantity - 1),
          onIncrement: () => cart.setQuantity(item.id, item.quantity + 1),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: QBrand.cardAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text('🛍', style: TextStyle(fontSize: 24)),
      );
}

class _SizeChip extends StatelessWidget {
  final CartItem item;
  final ValueChanged<String> onChange;

  const _SizeChip({required this.item, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: QBrand.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select size',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: QBrand.fg)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (final s in MyBagScreen.sizeOptions)
                        GestureDetector(
                          onTap: () => Navigator.pop(sheetCtx, s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: item.size == s ? QBrand.primary : QBrand.cardAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                  color: item.size == s ? Colors.white : QBrand.fg,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChange(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: QBrand.cardAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Size ${item.size ?? '—'}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: QBrand.fg)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: QBrand.fgMute),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _Stepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleBtn(icon: Icons.remove, onTap: onDecrement, faded: quantity <= 1),
        SizedBox(
          width: 32,
          child: Text('$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: QBrand.fg)),
        ),
        _CircleBtn(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool faded;

  const _CircleBtn({required this.icon, required this.onTap, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: QBrand.cardAlt,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: faded ? QBrand.fgDim : QBrand.fg),
      ),
    );
  }
}
