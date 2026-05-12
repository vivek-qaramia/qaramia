'use client';
import type { ProductInfo } from '@/lib/product-scanner/types';

interface Props {
  products: ProductInfo[];
  onDismiss: () => void;
}

function ProductCard({ product }: { product: ProductInfo }) {
  const searchQuery = [product.brand, product.name].filter(Boolean).join(' ');
  const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery + ' buy')}`;

  return (
    <div className="flex gap-3">
      {product.imageUrl ? (
        <img
          src={product.imageUrl}
          alt={product.name}
          className="w-14 h-14 rounded-xl object-cover shrink-0 bg-white/15"
        />
      ) : (
        <div className="w-14 h-14 rounded-xl bg-white/15 flex items-center justify-center shrink-0 text-xl">
          {product.source === 'barcode' ? '📦' : product.source === 'speech' ? '🎙' : '🔍'}
        </div>
      )}

      <div className="flex-1 min-w-0">
        {product.brand && (
          <p className="text-xs text-white/50 truncate">{product.brand}</p>
        )}
        <p className="text-sm font-semibold text-white leading-tight truncate">
          {product.name ?? 'Unknown product'}
        </p>
        {product.description && (
          <p className="text-xs text-white/50 mt-0.5 line-clamp-1">{product.description}</p>
        )}
        <div className="flex items-center gap-2 mt-1.5">
          <span className={`text-[10px] px-1.5 py-0.5 rounded font-semibold ${
            product.source === 'barcode'
              ? 'bg-emerald-500/20 text-emerald-400'
              : product.source === 'speech'
              ? 'bg-sky-500/20 text-sky-400'
              : 'bg-violet-500/20 text-violet-400'
          }`}>
            {product.source === 'barcode' ? '📷 Barcode' : product.source === 'speech' ? '🎙 Spoken' : '🤖 AI Vision'}
          </span>
          {product.barcode && (
            <span className="text-[10px] text-white/30 font-mono">{product.barcode}</span>
          )}
          {searchQuery && (
            <a
              href={searchUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-[10px] text-[#FFD166] hover:underline ml-auto"
            >
              Search ↗
            </a>
          )}
        </div>
      </div>
    </div>
  );
}

export function ProductOverlay({ products, onDismiss }: Props) {
  if (!products.length) return null;

  return (
    <div className="bg-white/10 backdrop-blur-md border border-white/15 rounded-2xl shadow-2xl overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-3 pt-3 pb-2">
        <span className="text-xs font-semibold text-white/40 uppercase tracking-wider">
          {products.length === 1 ? '1 product detected' : `${products.length} products detected`}
        </span>
        <button
          onClick={onDismiss}
          className="text-white/40 hover:text-white/80 transition p-0.5 text-sm"
        >
          ✕
        </button>
      </div>

      {/* Product list — dividers between cards */}
      <div className="px-3 pb-3 flex flex-col gap-0">
        {products.map((product, i) => (
          <div key={i}>
            {i > 0 && <div className="border-t border-white/8 my-2.5" />}
            <ProductCard product={product} />
          </div>
        ))}
      </div>
    </div>
  );
}
