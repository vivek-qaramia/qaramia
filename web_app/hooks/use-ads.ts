'use client';
import { useEffect, useState } from 'react';
import {
  collection, query, where, onSnapshot, addDoc, updateDoc,
  deleteDoc, doc, increment, serverTimestamp, getDocs,
} from 'firebase/firestore';
import { db } from '@/lib/firebase';
import type { Ad, ProductInfo } from '@/lib/types';
import { useAuthStore } from '@/store/auth-store';

function tokenize(text: string): string[] {
  return text.toLowerCase().split(/[\s,]+/).filter(t => t.length > 1);
}

export function keywordsFromProducts(products: ProductInfo[]): string[] {
  const tokens = products.flatMap(p => [
    ...tokenize(p.brand ?? ''),
    ...tokenize(p.name ?? ''),
  ]);
  return [...new Set(tokens)].slice(0, 10);
}

export async function matchAd(products: ProductInfo[]): Promise<Ad | null> {
  const tokens = keywordsFromProducts(products);
  const category = products[0]?.category ?? null;

  // Run keyword and category queries in parallel; at least one must be possible
  const fetches: ReturnType<typeof getDocs>[] = [];
  if (tokens.length) {
    fetches.push(getDocs(query(collection(db, 'ads'),
      where('status', '==', 'active'),
      where('keywords', 'array-contains-any', tokens),
    )));
  }
  if (category) {
    fetches.push(getDocs(query(collection(db, 'ads'),
      where('status', '==', 'active'),
      where('categories', 'array-contains', category),
    )));
  }
  if (!fetches.length) return null;

  const snaps = await Promise.all(fetches);

  // Merge and deduplicate results by document id
  const adMap = new Map<string, Ad>();
  for (const snap of snaps) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    snap.docs.forEach((d: any) => {
      if (!adMap.has(d.id)) {
        const raw = d.data() as Record<string, unknown>;
        adMap.set(d.id, { ...raw, id: d.id, createdAt: (raw.createdAt as { toDate?: () => Date })?.toDate?.() } as Ad);
      }
    });
  }
  if (!adMap.size) return null;

  // Score by keyword overlap; bonus 0.5 for category match
  const tokenSet = new Set(tokens);
  let best: Ad | null = null;
  let bestScore = 0;
  adMap.forEach(ad => {
    let score = (ad.keywords ?? []).filter((k: string) => tokenSet.has(k)).length;
    if (category && (ad.categories ?? []).includes(category)) score += 0.5;
    if (score > bestScore) { best = ad; bestScore = score; }
  });
  return best;
}

export async function trackImpression(adId: string): Promise<void> {
  await updateDoc(doc(db, 'ads', adId), { impressions: increment(1) });
}

export async function trackClick(adId: string): Promise<void> {
  await updateDoc(doc(db, 'ads', adId), { clicks: increment(1) });
}

export function useMyAds() {
  const { user } = useAuthStore();
  const [ads, setAds] = useState<Ad[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, 'ads'), where('advertiserId', '==', user.uid));
    const unsub = onSnapshot(q, snap => {
      setAds(snap.docs.map(d => ({
        ...d.data(), id: d.id,
        createdAt: d.data().createdAt?.toDate(),
      }) as Ad));
      setLoading(false);
    });
    return unsub;
  }, [user?.uid]);

  return { ads, loading };
}

export async function createAd(
  data: Omit<Ad, 'id' | 'impressions' | 'clicks' | 'createdAt'>
): Promise<void> {
  await addDoc(collection(db, 'ads'), {
    ...data,
    impressions: 0,
    clicks: 0,
    createdAt: serverTimestamp(),
  });
}

export async function updateAdStatus(adId: string, status: 'active' | 'paused'): Promise<void> {
  await updateDoc(doc(db, 'ads', adId), { status });
}

export async function deleteAd(adId: string): Promise<void> {
  await deleteDoc(doc(db, 'ads', adId));
}
