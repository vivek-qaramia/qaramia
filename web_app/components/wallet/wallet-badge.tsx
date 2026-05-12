'use client';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth-store';
import { useWallet } from '@/hooks/use-wallet';

export function WalletBadge() {
  const { user } = useAuthStore();
  const { wallet } = useWallet(user?.uid);

  if (!user) return null;

  return (
    <Link
      href="/wallet"
      className="flex items-center gap-1.5 px-3 py-1.5 bg-white/10 hover:bg-white/15 rounded-full text-xs font-semibold text-white/90 transition"
      title="Wallet"
    >
      <span>🪙</span>
      <span>{wallet.coins.toLocaleString()}</span>
    </Link>
  );
}
