'use client';
import { useState, useEffect } from 'react';
import { useAuthStore } from '@/store/auth-store';
import { useMyAds, createAd, updateAdStatus, deleteAd } from '@/hooks/use-ads';
import type { Ad } from '@/lib/types';
import { PRODUCT_CATEGORIES } from '@/lib/types';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import Link from 'next/link';

function LiveReach() {
  const [byCat, setByCat] = useState<Record<string, number>>({});
  const [total, setTotal] = useState(0);

  useEffect(() => {
    getDocs(query(collection(db, 'streams'), where('status', '==', 'live'))).then(snap => {
      const map: Record<string, number> = {};
      let sum = 0;
      snap.docs.forEach(d => {
        const cat = (d.data().category as string) ?? 'General';
        const viewers = (d.data().viewerCount as number) ?? 0;
        map[cat] = (map[cat] ?? 0) + viewers;
        sum += viewers;
      });
      setByCat(map);
      setTotal(sum);
    }).catch(() => {});
  }, []);

  const entries = Object.entries(byCat).sort((a, b) => b[1] - a[1]);

  return (
    <div className="bg-zinc-900 border border-white/10 rounded-xl p-4 mb-6">
      <div className="flex items-center justify-between mb-3">
        <p className="text-xs font-semibold text-white/40 uppercase tracking-wider">Live Audience Now</p>
        <span className="text-sm font-bold text-white">{total.toLocaleString()} viewers</span>
      </div>
      {entries.length === 0 ? (
        <p className="text-xs text-white/30">No streams live right now.</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {entries.map(([cat, count]) => (
            <div key={cat} className="flex items-center gap-1.5 bg-white/5 rounded-lg px-2.5 py-1.5">
              <span className="text-xs text-white/60">{cat}</span>
              <span className="text-xs font-semibold text-white">{count.toLocaleString()}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function AdRow({ ad }: { ad: Ad }) {
  const ctr = ad.impressions > 0 ? ((ad.clicks / ad.impressions) * 100).toFixed(1) : '—';
  return (
    <div className="bg-zinc-900 border border-white/10 rounded-xl p-4 flex gap-4 items-start">
      {ad.imageUrl && (
        <img src={ad.imageUrl} alt="" className="w-16 h-16 rounded-lg object-cover shrink-0" />
      )}
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-white truncate">{ad.headline}</p>
        <p className="text-xs text-white/40 mt-0.5 truncate">{ad.ctaUrl}</p>
        <div className="flex flex-wrap gap-1 mt-2">
          {ad.keywords.map(k => (
            <span key={k} className="text-[10px] bg-white/10 text-white/60 px-1.5 py-0.5 rounded">{k}</span>
          ))}
          {(ad.categories ?? []).map(c => (
            <span key={c} className="text-[10px] bg-[#FF7043]/20 text-[#FF7043] px-1.5 py-0.5 rounded capitalize">{c}</span>
          ))}
        </div>
        <div className="flex gap-4 mt-2 text-xs text-white/40">
          <span>👁 {ad.impressions.toLocaleString()} impressions</span>
          <span>🖱 {ad.clicks.toLocaleString()} clicks</span>
          <span>CTR {ctr}%</span>
        </div>
      </div>
      <div className="flex flex-col gap-2 shrink-0">
        <button
          onClick={() => updateAdStatus(ad.id, ad.status === 'active' ? 'paused' : 'active')}
          className={`px-3 py-1.5 rounded-full text-xs font-semibold transition ${
            ad.status === 'active'
              ? 'bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30'
              : 'bg-zinc-700 text-white/40 hover:bg-zinc-600'
          }`}
        >
          {ad.status === 'active' ? 'Active' : 'Paused'}
        </button>
        <button
          onClick={() => { if (confirm('Delete this ad?')) deleteAd(ad.id); }}
          className="px-3 py-1.5 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 hover:bg-red-500/20 transition"
        >
          Delete
        </button>
      </div>
    </div>
  );
}

function CreateAdForm({ onDone }: { onDone: () => void }) {
  const { user } = useAuthStore();
  const [headline, setHeadline] = useState('');
  const [ctaText, setCtaText] = useState('Shop Now');
  const [ctaUrl, setCtaUrl] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [keywordsRaw, setKeywordsRaw] = useState('');
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  const toggleCategory = (cat: string) =>
    setSelectedCategories(prev => prev.includes(cat) ? prev.filter(c => c !== cat) : [...prev, cat]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !headline || !ctaUrl) return;
    setSaving(true);
    const keywords = keywordsRaw.toLowerCase().split(/[\s,]+/).filter(k => k.length > 1);
    await createAd({
      advertiserId: user.uid,
      advertiserName: user.displayName,
      headline,
      ctaText,
      ctaUrl,
      imageUrl: imageUrl || undefined,
      keywords,
      categories: selectedCategories.length ? selectedCategories : undefined,
      status: 'active',
    });
    onDone();
  };

  const field = 'w-full bg-zinc-900 border border-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#FF7043] transition';

  return (
    <form onSubmit={handleSubmit} className="bg-zinc-900 border border-white/10 rounded-xl p-5 space-y-3">
      <h3 className="font-semibold text-white">New Ad</h3>
      <input className={field} placeholder="Headline *" value={headline} onChange={e => setHeadline(e.target.value)} required />
      <input className={field} placeholder="CTA button text (e.g. Shop Now)" value={ctaText} onChange={e => setCtaText(e.target.value)} />
      <input className={field} placeholder="Destination URL *" value={ctaUrl} onChange={e => setCtaUrl(e.target.value)} required />
      <input className={field} placeholder="Image URL (optional)" value={imageUrl} onChange={e => setImageUrl(e.target.value)} />
      <div>
        <input
          className={field}
          placeholder="Keywords — brand names & product words, comma-separated"
          value={keywordsRaw}
          onChange={e => setKeywordsRaw(e.target.value)}
        />
        <p className="text-[10px] text-white/30 mt-1 ml-1">Match when these words appear in a detected product's name or brand.</p>
      </div>
      <div>
        <p className="text-xs text-white/40 mb-2">Categories — match by product type (optional)</p>
        <div className="flex flex-wrap gap-1.5">
          {PRODUCT_CATEGORIES.map(cat => (
            <button
              key={cat}
              type="button"
              onClick={() => toggleCategory(cat)}
              className={`px-3 py-1 rounded-full text-xs font-semibold transition capitalize ${
                selectedCategories.includes(cat)
                  ? 'bg-[#FF7043] text-white'
                  : 'bg-white/10 text-white/50 hover:bg-white/20'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>
      <div className="flex gap-2 pt-1">
        <button type="submit" disabled={saving}
          className="px-4 py-2 bg-[#FF7043] text-white text-sm font-semibold rounded-lg hover:bg-[#e55a2b] transition disabled:opacity-50">
          {saving ? 'Saving…' : 'Create Ad'}
        </button>
        <button type="button" onClick={onDone} className="px-4 py-2 text-sm text-white/50 hover:text-white transition">
          Cancel
        </button>
      </div>
    </form>
  );
}

function downloadIO() {
  const today = new Date().toISOString().slice(0, 10);
  const lines = [
    'QARAMIA PLATFORM — INSERTION ORDER',
    '====================================',
    '',
    `Date: ${today}`,
    'Advertiser name:  ___________________________________',
    'Contact name:     ___________________________________',
    'Contact email:    ___________________________________',
    '',
    'CAMPAIGN DETAILS',
    '----------------',
    'Campaign name:    ___________________________________',
    'Headline:         ___________________________________',
    'Destination URL:  ___________________________________',
    'CTA button text:  ___________________________________',
    'Keywords / categories targeted: ____________________',
    '',
    'BUDGET & FLIGHT',
    '---------------',
    'Pricing model:    [ ] CPM   [ ] CPC',
    'Rate:             $________ per 1,000 impressions / per click',
    'Daily budget cap: $________',
    'Total budget cap: $________',
    'Flight start:     ___________',
    'Flight end:       ___________',
    '',
    'TERMS',
    '-----',
    '1. Advertiser grants Qaramia a non-exclusive licence to display the ad creative.',
    '2. Campaigns may be paused at any time via the self-serve console.',
    '3. Qaramia may reject creatives that violate platform policies.',
    '4. Cancellation: either party may cancel with 5 business days written notice.',
    '5. Billing: invoiced monthly NET 30 from end of billing period.',
    '6. Impressions counted per Qaramia spec: drawer open ≥ 1 s, one per session per ad.',
    '',
    'SIGNATURES',
    '----------',
    'Advertiser: _________________________  Date: __________',
    '',
    'Qaramia:    _________________________  Date: __________',
  ];
  const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `Qaramia-IO-${today}.txt`;
  a.click();
  URL.revokeObjectURL(url);
}

export default function AdsPage() {
  const { user } = useAuthStore();
  const { ads, loading } = useMyAds();
  const [creating, setCreating] = useState(false);

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-3.5rem)]">
        <p className="text-white/40">Sign in to manage ads.</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-8">
      <div className="flex items-center gap-4 mb-6">
        <Link href="/studio" className="text-white/40 hover:text-white transition text-sm">← Studio</Link>
        <h1 className="text-xl font-bold text-white">My Ads</h1>
        <div className="ml-auto flex gap-2">
          <button
            onClick={downloadIO}
            className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white/60 hover:text-white text-sm font-semibold rounded-lg transition"
          >
            ↓ IO Template
          </button>
          <button
            onClick={() => setCreating(true)}
            className="px-4 py-2 bg-[#FF7043] text-white text-sm font-semibold rounded-lg hover:bg-[#e55a2b] transition"
          >
            + New Ad
          </button>
        </div>
      </div>

      <LiveReach />

      {creating && <div className="mb-4"><CreateAdForm onDone={() => setCreating(false)} /></div>}

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-[#FF7043] border-t-transparent rounded-full animate-spin" />
        </div>
      ) : ads.length === 0 && !creating ? (
        <div className="text-center py-16 text-white/30">
          <p className="text-4xl mb-3">📢</p>
          <p className="font-semibold">No ads yet</p>
          <p className="text-sm mt-1">Create an ad to appear when matching products are spotted in streams.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {ads.map(ad => <AdRow key={ad.id} ad={ad} />)}
        </div>
      )}
    </div>
  );
}
