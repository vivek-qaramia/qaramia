import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../providers/wallet_providers.dart';
import '../../theme/brand.dart';
import '../../widgets/coin_pack_picker.dart';
import 'payouts_screen.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your wallet.')),
      );
    }

    final walletAsync = ref.watch(walletProvider(user.uid));
    final balance = ref.watch(creatorBalanceProvider(user.uid)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            tooltip: 'Creator payouts',
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PayoutsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance cards: viewer coins + creator diamonds
            Row(
              children: [
                Expanded(child: _BalanceCard(
                  emoji: '🪙', label: 'Coins (viewer)',
                  value: '${walletAsync.valueOrNull?.coins ?? 0}',
                  caption: 'Lifetime purchased: ${walletAsync.valueOrNull?.lifetimeCoinsPurchased ?? 0}',
                )),
                const SizedBox(width: 12),
                Expanded(child: _BalanceCard(
                  emoji: '💎', label: 'Diamonds (creator)',
                  value: '${balance?.diamonds ?? 0}',
                  caption: '≈ \$${(balance?.estimatedCashoutUsd ?? 0).toStringAsFixed(2)} cash-out value',
                )),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QBrand.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const CoinPackPicker(),
            ),

            const SizedBox(height: 16),
            const Text(
              'Coins are platform credit, not currency. They are non-refundable once spent, non-transferable, and expire after 24 months of account inactivity.',
              style: TextStyle(color: QBrand.fgDim, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Creators redeem Diamonds for cash via Stripe Connect; minimum 5,000 Diamonds (\$50) per payout.',
              style: TextStyle(color: QBrand.fgDim, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final String caption;

  const _BalanceCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QBrand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(color: QBrand.fgDim, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text(value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: QBrand.fg)),
            ],
          ),
          const SizedBox(height: 4),
          Text(caption,
              style: const TextStyle(color: QBrand.fgMute, fontSize: 10)),
        ],
      ),
    );
  }
}
