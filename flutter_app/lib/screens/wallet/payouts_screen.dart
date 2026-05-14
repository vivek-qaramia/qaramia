import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/providers.dart';
import '../../providers/wallet_providers.dart';
import '../../theme/brand.dart';

/// Creator-facing payouts setup. Walks the user through Stripe Connect
/// Express onboarding so they can later cash out diamonds to fiat.
///
/// The actual onboarding form is Stripe-hosted; we just create the account
/// (Cloud Function `createConnectAccount`) and open the resulting URL in
/// the system browser. On return to the app, this screen re-fetches the
/// user doc and surfaces the current account status.
class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _startOnboarding({required bool refresh}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final fnName = refresh ? 'refreshConnectOnboardingLink' : 'createConnectAccount';
      final res = await FirebaseFunctions.instance.httpsCallable(fnName).call({});
      final url = (res.data as Map)['onboardingUrl'] as String?;
      if (url == null) throw 'No onboarding URL returned';
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in to set up payouts.')));
    }
    final balance = ref.watch(creatorBalanceProvider(user.uid)).valueOrNull;
    final status = user.stripeAccountStatus ?? 'not_started';

    return Scaffold(
      appBar: AppBar(title: const Text('Creator Payouts')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current diamond balance / cashout estimate
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QBrand.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: QBrand.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AVAILABLE DIAMONDS',
                      style: TextStyle(color: QBrand.fgDim, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text('${balance?.diamonds ?? 0}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: QBrand.fg)),
                      const SizedBox(width: 12),
                      Text('≈ \$${(balance?.estimatedCashoutUsd ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(color: QBrand.fgMute, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Standard creator tier: 1 Diamond = \$0.01 USD. Minimum payout 5,000 Diamonds (\$50).',
                    style: TextStyle(color: QBrand.fgMute, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _StatusCard(status: status),

            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : () => _startOnboarding(refresh: status != 'not_started'),
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_ctaLabelFor(status), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Payouts are processed by Stripe Connect. You\'ll be redirected to Stripe to provide KYC details and a bank account. After approval, you can redeem accumulated Diamonds for cash.',
              style: TextStyle(color: QBrand.fgDim, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabelFor(String status) {
    return switch (status) {
      'active' => 'Update payout details',
      'restricted' => 'Resolve payout issues',
      'pending' => 'Continue Stripe onboarding',
      _ => 'Set up payouts',
    };
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, detail) = switch (status) {
      'active' => ('Active', Colors.greenAccent, 'Your account is ready to receive payouts.'),
      'pending' => ('Pending', QBrand.gold, 'Finish the Stripe onboarding to start receiving payouts.'),
      'restricted' => ('Restricted', Colors.redAccent, 'Stripe needs additional information before you can be paid.'),
      _ => ('Not set up', QBrand.fgMute, 'Set up Stripe Connect to receive Diamond → USD payouts.'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QBrand.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: QBrand.hairline),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payout status: $label',
                    style: const TextStyle(color: QBrand.fg, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: QBrand.fgMute, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
