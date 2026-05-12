'use client';
import { useState, useEffect, useRef } from 'react';
import type { ProductInfo, Ad } from '@/lib/types';
import { trackImpression, trackClick } from '@/hooks/use-ads';
import { affiliateUrl } from '@/lib/affiliate';

function ProductRow({ product, onBuyClick }: { product: ProductInfo; onBuyClick?: () => void }) {
  const searchQuery = [product.brand, product.name].filter(Boolean).join(' ');
  const buyUrl = searchQuery ? affiliateUrl(searchQuery) : null;

  return (
    <div className="flex items-center gap-3">
      {product.imageUrl ? (
        <img src={product.imageUrl} alt={product.name} className="w-10 h-10 rounded-lg object-cover shrink-0 bg-white/15" />
      ) : (
        <div className="w-10 h-10 rounded-lg bg-white/15 flex items-center justify-center shrink-0 text-lg">
          {product.source === 'barcode' ? '📦' : product.source === 'speech' ? '🎙' : '🔍'}
        </div>
      )}
      <div className="flex-1 min-w-0">
        {product.brand && <p className="text-[10px] text-white/50 truncate">{product.brand}</p>}
        <p className="text-sm font-semibold text-white truncate">{product.name ?? 'Unknown product'}</p>
      </div>
      {buyUrl && (
        <a
          href={buyUrl}
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => onBuyClick?.()}
          className="shrink-0 px-3 py-1.5 bg-[#FFD166]/20 text-[#FFD166] text-xs font-semibold rounded-full hover:bg-[#FFD166]/30 transition"
        >
          Buy ↗
        </a>
      )}
    </div>
  );
}

function AffiliateCard({ products, onAffiliateClick }: { products: ProductInfo[]; onAffiliateClick?: () => void }) {
  const first = products[0];
  const query = [first.brand, first.name].filter(Boolean).join(' ');
  if (!query) return null;
  const label = products.length === 1
    ? `Find "${first.name ?? first.brand}" on Amazon`
    : `Shop ${products.length} products on Amazon`;

  return (
    <a
      href={affiliateUrl(query)}
      target="_blank"
      rel="noopener noreferrer"
      onClick={() => onAffiliateClick?.()}
      className="flex items-center justify-between gap-3 rounded-xl bg-[#FF9900]/10 border border-[#FF9900]/20 px-3 py-2.5 hover:bg-[#FF9900]/15 transition group"
    >
      <div className="min-w-0">
        <p className="text-[9px] text-[#FF9900]/60 uppercase tracking-wider mb-0.5">Affiliate</p>
        <p className="text-sm font-semibold text-white truncate">{label}</p>
      </div>
      <span className="shrink-0 text-[#FF9900] text-lg group-hover:translate-x-0.5 transition-transform">→</span>
    </a>
  );
}

function SponsoredCard({ ad }: { ad: Ad }) {
  const handleClick = () => {
    trackClick(ad.id).catch(() => {});
    window.open(ad.ctaUrl, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="rounded-xl bg-white/10 border border-white/10 overflow-hidden">
      {ad.imageUrl && (
        <img src={ad.imageUrl} alt={ad.headline} className="w-full h-24 object-cover" />
      )}
      <div className="px-3 py-2.5 flex items-center gap-3">
        <div className="flex-1 min-w-0">
          <p className="text-[9px] text-white/30 uppercase tracking-wider mb-0.5">Sponsored</p>
          <p className="text-sm font-semibold text-white leading-tight truncate">{ad.headline}</p>
        </div>
        <button
          onClick={handleClick}
          className="shrink-0 px-3 py-1.5 bg-[#FF7043] text-white text-xs font-bold rounded-full hover:bg-[#e55a2b] transition"
        >
          {ad.ctaText}
        </button>
      </div>
    </div>
  );
}

interface Props {
  products: ProductInfo[];
  featuredAd?: Ad | null;
  onClose?: () => void;
  onAffiliateClick?: () => void;
}

export function ProductDrawer({ products, featuredAd, onClose, onAffiliateClick }: Props) {
  const [open, setOpen] = useState(false);
  const [pulse, setPulse] = useState(false);
  const impressionTrackedRef = useRef<string | null>(null);

  useEffect(() => {
    if (!products.length) { setOpen(false); return; }
    setPulse(true);
    const t = setTimeout(() => setPulse(false), 2000);
    return () => clearTimeout(t);
  }, [products]);

  // Track one impression per unique ad after the drawer has been open for ≥ 1 s (MRC dwell requirement)
  useEffect(() => {
    if (!open || !featuredAd || impressionTrackedRef.current === featuredAd.id) return;
    const adId = featuredAd.id;
    const t = setTimeout(() => {
      impressionTrackedRef.current = adId;
      trackImpression(adId).catch(() => {});
    }, 1000);
    return () => clearTimeout(t);
  }, [open, featuredAd]);

  if (!products.length) return null;

  return (
    <>
      {/* Floating button */}
      <button
        onClick={() => setOpen(o => !o)}
        className={`absolute bottom-20 right-4 z-20 w-12 h-12 rounded-full bg-white/15 backdrop-blur-md border border-white/20 flex items-center justify-center text-xl shadow-lg transition-transform duration-200 ${pulse ? 'scale-125' : 'scale-100'}`}
      >
        🛍
        <span className="absolute -top-1 -right-1 w-5 h-5 bg-[#FF7043] rounded-full text-[10px] text-white font-bold flex items-center justify-center">
          {products.length}
        </span>
      </button>

      {/* Slide-up drawer */}
      <div
        className={`absolute bottom-0 left-0 right-0 z-20 transition-transform duration-300 ease-out ${open ? 'translate-y-0' : 'translate-y-full'}`}
      >
        <div className="bg-white/10 backdrop-blur-md border-t border-white/15 rounded-t-2xl shadow-2xl">
          <div className="flex justify-center pt-2 pb-1">
            <div className="w-8 h-1 bg-white/30 rounded-full" />
          </div>
          <div className="flex items-center justify-between px-4 pb-2">
            <span className="text-xs font-semibold text-white/60 uppercase tracking-wider">
              {products.length === 1 ? '1 product spotted' : `${products.length} products spotted`}
            </span>
            <button onClick={() => { setOpen(false); onClose?.(); }} className="text-white/40 hover:text-white/80 p-1 text-sm transition">✕</button>
          </div>
          <div className="px-4 pb-5 space-y-3 max-h-64 overflow-y-auto">
            {featuredAd ? <SponsoredCard ad={featuredAd} /> : <AffiliateCard products={products} onAffiliateClick={onAffiliateClick} />}
            {products.map((product, i) => (
              <ProductRow key={i} product={product} onBuyClick={onAffiliateClick} />
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
