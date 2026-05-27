'use client';
import { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { GIFT_CATALOG, GiftType, GiftTier } from '@/lib/types';

/**
 * Live gift catalog. Streams from Firestore `giftCatalog/{giftId}` so that
 * pricing / yields / new gifts can be changed without redeploying the
 * web app. Falls back to the static [GIFT_CATALOG] when the collection is
 * empty or the snapshot hasn't arrived yet, so consumers never see an
 * empty array. Mirrors the Flutter `giftCatalogProvider`.
 */
export function useGiftCatalog(): GiftType[] {
  const [remote, setRemote] = useState<GiftType[] | null>(null);

  useEffect(() => {
    const q = query(collection(db, 'giftCatalog'), orderBy('coinCost'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const next: GiftType[] = snap.docs.map((doc) => {
          const data = doc.data();
          return {
            id: doc.id,
            name: data.name as string,
            emoji: data.emoji as string,
            coinCost: Number(data.coinCost ?? 0),
            diamondYield: Number(data.diamondYield ?? 0),
            tier: (data.tier as GiftTier) ?? 'standard',
          };
        });
        setRemote(next);
      },
      // On error (offline, permission, etc.) keep returning the fallback.
      () => setRemote(null),
    );
    return unsub;
  }, []);

  if (remote === null || remote.length === 0) return GIFT_CATALOG;
  return remote;
}
