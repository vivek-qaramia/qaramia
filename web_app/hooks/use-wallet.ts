'use client';
import { useEffect, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import type { Wallet, CreatorBalance } from '@/lib/types';

export function useWallet(uid: string | undefined) {
  const [wallet, setWallet] = useState<Wallet>({ coins: 0, lifetimeCoinsPurchased: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    const ref = doc(db, 'users', uid, 'wallet', 'default');
    const unsub = onSnapshot(ref, snap => {
      if (snap.exists()) {
        const data = snap.data();
        setWallet({
          coins: data.coins ?? 0,
          lifetimeCoinsPurchased: data.lifetimeCoinsPurchased ?? 0,
          updatedAt: data.updatedAt?.toDate(),
        });
      } else {
        setWallet({ coins: 0, lifetimeCoinsPurchased: 0 });
      }
      setLoading(false);
    }, () => setLoading(false));
    return unsub;
  }, [uid]);

  return { wallet, loading };
}

export function useCreatorBalance(uid: string | undefined) {
  const [balance, setBalance] = useState<CreatorBalance>({ diamonds: 0, lifetimeDiamonds: 0 });

  useEffect(() => {
    if (!uid) return;
    const ref = doc(db, 'users', uid, 'creatorBalance', 'default');
    const unsub = onSnapshot(ref, snap => {
      if (snap.exists()) {
        const data = snap.data();
        setBalance({
          diamonds: data.diamonds ?? 0,
          lifetimeDiamonds: data.lifetimeDiamonds ?? 0,
          updatedAt: data.updatedAt?.toDate(),
        });
      }
    }, () => {});
    return unsub;
  }, [uid]);

  return balance;
}

export async function buyCoinPack(packId: string, uid: string): Promise<void> {
  const res = await fetch('/api/checkout/coin-pack', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ packId, uid }),
  });
  const data = await res.json() as { url?: string; error?: string };
  if (data.url) {
    window.location.href = data.url;
  } else {
    throw new Error(data.error ?? 'Checkout failed');
  }
}
