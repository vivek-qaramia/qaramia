'use client';
import { useEffect, useState } from 'react';
import { collection, query, orderBy, limit, onSnapshot, where, Timestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase';

interface ActiveGift {
  id: string;
  emoji: string;
  name: string;
  sender: string;
}

const GIFT_LIFETIME_MS = 3500;

export function GiftAnimationOverlay({ streamId }: { streamId: string }) {
  const [active, setActive] = useState<ActiveGift[]>([]);

  useEffect(() => {
    if (!streamId) return;
    // Only animate gifts created in the last 30 seconds so a viewer joining late
    // doesn't get bombarded by historical gifts.
    const since = Timestamp.fromMillis(Date.now() - 30_000);
    const q = query(
      collection(db, 'streams', streamId, 'gifts'),
      where('sentAt', '>=', since),
      orderBy('sentAt', 'desc'),
      limit(20),
    );
    const unsub = onSnapshot(q, snap => {
      snap.docChanges().forEach(change => {
        if (change.type !== 'added') return;
        const data = change.doc.data();
        const gift: ActiveGift = {
          id: change.doc.id,
          emoji: data.giftEmoji ?? '🎁',
          name: data.giftName ?? 'Gift',
          sender: data.senderUsername ?? '',
        };
        setActive(prev => [...prev, gift]);
        setTimeout(() => {
          setActive(prev => prev.filter(g => g.id !== gift.id));
        }, GIFT_LIFETIME_MS);
      });
    });
    return unsub;
  }, [streamId]);

  if (!active.length) return null;

  return (
    <div className="pointer-events-none absolute inset-0 z-20 overflow-hidden">
      {active.map((g, i) => (
        <div
          key={g.id}
          className="absolute animate-gift-float"
          style={{
            left: `${15 + ((i * 23) % 70)}%`,
            bottom: '8%',
            animationDuration: `${GIFT_LIFETIME_MS}ms`,
          }}
        >
          <div className="flex flex-col items-center">
            <span className="text-5xl drop-shadow-lg">{g.emoji}</span>
            {g.sender && (
              <span className="mt-1 text-[10px] font-semibold text-white bg-black/60 px-2 py-0.5 rounded-full drop-shadow">
                @{g.sender}
              </span>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
