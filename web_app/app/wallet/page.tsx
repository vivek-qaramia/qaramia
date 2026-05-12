'use client';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth-store';
import { useWallet, useCreatorBalance } from '@/hooks/use-wallet';
import { CoinPackPicker } from '@/components/wallet/coin-pack-picker';

export default function WalletPage() {
  const { user } = useAuthStore();
  const { wallet, loading } = useWallet(user?.uid);
  const balance = useCreatorBalance(user?.uid);
  const params = useSearchParams();
  const status = params.get('status');

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-3.5rem)]">
        <div className="text-center space-y-4">
          <p className="text-white/40">Sign in to view your wallet.</p>
          <Link href="/login" className="inline-block px-4 py-2 bg-[#FF7043] text-white rounded-lg text-sm font-semibold">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-8 space-y-6">
      <div className="flex items-center gap-4">
        <h1 className="text-2xl font-bold text-white">Wallet</h1>
      </div>

      {status === 'success' && (
        <div className="bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-sm rounded-xl p-3">
          ✓ Payment received. Coins will appear shortly.
        </div>
      )}
      {status === 'cancel' && (
        <div className="bg-amber-500/10 border border-amber-500/30 text-amber-400 text-sm rounded-xl p-3">
          Purchase cancelled.
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-zinc-900 border border-white/10 rounded-xl p-5">
          <p className="text-[10px] font-semibold text-white/40 uppercase tracking-wider mb-1">Coins (viewer)</p>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl">🪙</span>
            <span className="text-3xl font-bold text-white">
              {loading ? '—' : wallet.coins.toLocaleString()}
            </span>
          </div>
          <p className="text-xs text-white/40 mt-2">
            Lifetime purchased: {wallet.lifetimeCoinsPurchased.toLocaleString()}
          </p>
        </div>

        <div className="bg-zinc-900 border border-white/10 rounded-xl p-5">
          <p className="text-[10px] font-semibold text-white/40 uppercase tracking-wider mb-1">Diamonds (creator)</p>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl">💎</span>
            <span className="text-3xl font-bold text-white">{balance.diamonds.toLocaleString()}</span>
          </div>
          <p className="text-xs text-white/40 mt-2">
            Lifetime earned: {balance.lifetimeDiamonds.toLocaleString()} · ≈ ${(balance.diamonds * 0.01).toFixed(2)} cashout value
          </p>
        </div>
      </div>

      <div className="bg-zinc-900 border border-white/10 rounded-xl p-5">
        <CoinPackPicker />
      </div>

      <div className="text-[11px] text-white/30 space-y-1">
        <p>Coins are platform credit, not currency. They are non-refundable once spent, non-transferable, and expire after 24 months of account inactivity.</p>
        <p>Creators redeem Diamonds for cash via Stripe Connect; minimum 5,000 Diamonds ($50) per payout.</p>
      </div>
    </div>
  );
}
