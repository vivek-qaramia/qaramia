'use client';
import { GiftType, GiftTier, Sponsorship, viewerCoinCost } from '@/lib/types';

/**
 * Tiered gift picker. Mirrors the Flutter GiftPanel: a SPONSORED row at the
 * top (brand-styled, discounted/free pricing) when any sponsorship applies to
 * this stream, then the standard catalogue grouped Standard / Premium / Whale.
 * Unaffordable gifts dim but stay clickable — the caller surfaces the top-up
 * prompt.
 */
const TIERS: { tier: GiftTier; label: string; color: string }[] = [
  { tier: 'standard', label: 'Standard', color: 'text-white/70' },
  { tier: 'premium', label: 'Premium', color: 'text-[#FF7043]' },
  { tier: 'whale', label: 'Whale', color: 'text-[#FF4D6D]' },
];

export function GiftPanel({
  catalog,
  sponsorships,
  coins,
  onSelect,
}: {
  catalog: GiftType[];
  sponsorships: Sponsorship[];
  coins: number;
  onSelect: (gift: GiftType, sponsorship?: Sponsorship) => void;
}) {
  // Pair each applicable sponsorship with its catalogue gift.
  const sponsoredPairs = sponsorships
    .map((s) => {
      const gift = catalog.find((g) => g.id === s.giftTypeId);
      return gift ? { gift, sponsorship: s } : null;
    })
    .filter((p): p is { gift: GiftType; sponsorship: Sponsorship } => p !== null);

  return (
    <div className="max-h-72 overflow-y-auto space-y-3">
      {sponsoredPairs.length > 0 && (
        <div>
          <p className="flex items-center gap-1 px-1 mb-1.5 text-[10px] font-extrabold tracking-wider text-[#FFD166]">
            ⚡ SPONSORED
          </p>
          <div className="flex flex-wrap gap-2">
            {sponsoredPairs.map(({ gift, sponsorship }) => (
              <GiftTile
                key={`${sponsorship.id}-${gift.id}`}
                gift={gift}
                coins={coins}
                sponsorship={sponsorship}
                onClick={() => onSelect(gift, sponsorship)}
              />
            ))}
          </div>
          <div className="mt-2 h-px bg-white/10" />
        </div>
      )}

      {TIERS.map(({ tier, label, color }) => {
        const gifts = catalog.filter((g) => g.tier === tier);
        if (gifts.length === 0) return null;
        return (
          <div key={tier}>
            <p className={`px-1 mb-1.5 text-[10px] font-extrabold tracking-wider ${color}`}>
              {label.toUpperCase()}
            </p>
            <div className="flex flex-wrap gap-2">
              {gifts.map((gift) => (
                <GiftTile key={gift.id} gift={gift} coins={coins} onClick={() => onSelect(gift)} />
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function GiftTile({
  gift,
  coins,
  sponsorship,
  onClick,
}: {
  gift: GiftType;
  coins: number;
  sponsorship?: Sponsorship;
  onClick: () => void;
}) {
  const price = sponsorship ? viewerCoinCost(sponsorship, gift.coinCost) : gift.coinCost;
  const free = price === 0;
  const discounted = !!sponsorship && sponsorship.pricingModel === 'discounted' && price < gift.coinCost;
  const affordable = coins >= price;

  return (
    <button
      onClick={onClick}
      title={affordable ? gift.name : `Need ${(price - coins).toLocaleString()} more coins`}
      className={`flex flex-col items-center justify-center p-2 rounded-xl w-16 transition border ${
        sponsorship
          ? 'bg-[#FFD166]/10 border-[#FFD166]/40 hover:bg-[#FFD166]/20'
          : 'bg-white/10 border-white/10 hover:bg-white/20'
      } ${affordable ? '' : 'opacity-45'}`}
    >
      <span className="text-2xl leading-none">{gift.emoji}</span>
      <span className="mt-1 text-[10px] text-white/60 truncate max-w-full">{gift.name}</span>
      {free ? (
        <span className="text-[10px] font-extrabold text-[#FFD166]">FREE</span>
      ) : discounted ? (
        <span className="flex items-center gap-1">
          <span className="text-[10px] font-bold text-[#FFD166]">🪙{price}</span>
          <span className="text-[9px] text-white/40 line-through">{gift.coinCost}</span>
        </span>
      ) : (
        <span className="text-[10px] text-yellow-400">🪙{price}</span>
      )}
      {sponsorship && (
        <span className="text-[8px] font-semibold text-[#FFD166] truncate max-w-full">
          {sponsorship.brandName}
        </span>
      )}
    </button>
  );
}
