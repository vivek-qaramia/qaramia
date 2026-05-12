import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../providers/wallet_providers.dart';
import '../screens/wallet/wallet_screen.dart';
import '../theme/brand.dart';

/// Small pill showing the viewer's current coin balance. Tapping opens the
/// wallet screen for top-up.
class WalletBadge extends ConsumerWidget {
  const WalletBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final walletAsync = ref.watch(walletProvider(user.uid));
    final coins = walletAsync.valueOrNull?.coins ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              _formatCoins(coins),
              style: const TextStyle(
                color: QBrand.fg, fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoins(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
