'use client';
import { useEffect, useState } from 'react';
import {
  collection, onSnapshot, query, orderBy, limit,
  doc, getDoc, getCountFromServer, where,
} from 'firebase/firestore';
import { db } from '@/lib/firebase';

export interface TopGifter {
  senderUid: string;
  username: string;
  avatarUrl: string | null;
  totalCoins: number;
}

export interface MyRank {
  rank: number;       // 1-based
  totalCoins: number;
}

/**
 * Live top-gifter leaderboard for a stream (streams/{id}/gifters), ranked by
 * coins spent, plus the signed-in viewer's own rank. Mirrors the Flutter
 * topGiftersProvider + StreamService.myGifterRank. If the viewer is already
 * inside the returned top rows we read their rank from the list; otherwise a
 * single count() aggregation resolves it.
 */
export function useTopGifters(
  streamId: string,
  uid: string | undefined,
  topN = 10,
): { top: TopGifter[]; myRank: MyRank | null } {
  const [top, setTop] = useState<TopGifter[]>([]);
  const [myRank, setMyRank] = useState<MyRank | null>(null);

  useEffect(() => {
    if (!streamId) return;
    const q = query(
      collection(db, 'streams', streamId, 'gifters'),
      orderBy('totalCoins', 'desc'),
      limit(topN),
    );
    const unsub = onSnapshot(q, (snap) => {
      setTop(snap.docs.map((d) => {
        const data = d.data();
        return {
          senderUid: (data.senderUid as string) ?? d.id,
          username: (data.username as string) ?? 'viewer',
          avatarUrl: (data.avatarUrl as string) ?? null,
          totalCoins: Number(data.totalCoins ?? 0),
        };
      }));
    }, () => setTop([]));
    return unsub;
  }, [streamId, topN]);

  // Resolve the viewer's rank. If they're in the visible top rows, derive it
  // for free; otherwise count how many gifters outrank them.
  useEffect(() => {
    if (!streamId || !uid) { setMyRank(null); return; }
    const inTop = top.findIndex((g) => g.senderUid === uid);
    if (inTop >= 0) {
      setMyRank({ rank: inTop + 1, totalCoins: top[inTop].totalCoins });
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const col = collection(db, 'streams', streamId, 'gifters');
        const mine = await getDoc(doc(col, uid));
        if (!mine.exists()) { if (!cancelled) setMyRank(null); return; }
        const myTotal = Number(mine.data().totalCoins ?? 0);
        const higher = await getCountFromServer(
          query(col, where('totalCoins', '>', myTotal)),
        );
        if (!cancelled) setMyRank({ rank: higher.data().count + 1, totalCoins: myTotal });
      } catch {
        if (!cancelled) setMyRank(null);
      }
    })();
    return () => { cancelled = true; };
    // Re-run when the leaderboard changes (top[0] total + length is a cheap
    // signature) so the viewer's rank stays current as gifts arrive.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [streamId, uid, top.length, top[0]?.totalCoins, top.find((g) => g.senderUid === uid)?.totalCoins]);

  return { top, myRank };
}
