'use client';
import { useState } from 'react';
import { COIN_PACKS } from '@/lib/types';
import { useAuthStore } from '@/store/auth-store';
import { buyCoinPack } from '@/hooks/use-wallet';

export function CoinPackPicker({ onCancel }: { onCancel?: () => void }) {
  const { user } = useAuthStore();
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleBuy = async (packId: string) => {
    if (!user) return;
    setError(null);
    setPending(packId);
    try {
      await buyCoinPack(packId, user.uid);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Purchase failed');
      setPending(null);
    }
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-white">Top up coins</h2>
        {onCancel && (
          <button onClick={onCancel} className="text-white/40 hover:text-white text-sm">✕</button>
        )}
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-400 text-xs rounded-lg p-2.5">
          {error}
        </div>
      )}

      <div className="space-y-2">
        {COIN_PACKS.map(pack => {
          const total = pack.coins + pack.bonusCoins;
          const ratePer1k = ((pack.priceUsd / total) * 1000).toFixed(2);
          return (
            <button
              key={pack.id}
              onClick={() => handleBuy(pack.id)}
              disabled={!!pending}
              className="w-full flex items-center gap-3 p-3 bg-zinc-900 hover:bg-zinc-800 disabled:opacity-50 border border-white/10 rounded-xl text-left transition"
            >
              <div className="w-12 h-12 rounded-lg bg-[#FF7043]/20 flex items-center justify-center text-2xl shrink-0">
                🪙
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <p className="font-semibold text-white">{pack.label}</p>
                  {pack.bonusCoins > 0 && (
                    <span className="text-[10px] bg-[#FFD166]/20 text-[#FFD166] px-1.5 py-0.5 rounded-full font-semibold">
                      +{Math.round((pack.bonusCoins / pack.coins) * 100)}% bonus
                    </span>
                  )}
                </div>
                <p className="text-xs text-white/50 mt-0.5">
                  {total.toLocaleString()} coins
                  {pack.bonusCoins > 0 && (
                    <span className="text-white/30"> ({pack.coins.toLocaleString()} + {pack.bonusCoins.toLocaleString()} bonus)</span>
                  )}
                </p>
                <p className="text-[10px] text-white/30 mt-0.5">${ratePer1k} per 1,000 coins · {pack.target}</p>
              </div>
              <div className="text-right shrink-0">
                <p className="text-lg font-bold text-[#FF7043]">${pack.priceUsd.toFixed(2)}</p>
                {pending === pack.id && (
                  <div className="w-4 h-4 mx-auto mt-1 border-2 border-[#FF7043] border-t-transparent rounded-full animate-spin" />
                )}
              </div>
            </button>
          );
        })}
      </div>

      <p className="text-[10px] text-white/30 text-center pt-1">
        Coins have no cash value, are non-refundable once spent, and cannot be transferred.
      </p>
    </div>
  );
}
