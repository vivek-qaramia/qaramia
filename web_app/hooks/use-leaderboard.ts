'use client';
import { useEffect, useState } from 'react';
import { collection, query, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import type { AppUser } from '@/lib/types';

// All-time System-level leaderboard: users ranked by the denormalized systemXp
// scalar (written by the updateSystemXp Cloud Function). Users without a
// systemXp field are simply absent from an orderBy query — i.e. unranked until
// they earn, which is correct for a leaderboard.
export function useLeaderboard(max = 50): { entries: AppUser[]; loading: boolean } {
  const [entries, setEntries] = useState<AppUser[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const q = query(collection(db, 'users'), orderBy('systemXp', 'desc'), limit(max));
    return onSnapshot(
      q,
      (snap) => {
        setEntries(snap.docs.map((d) => ({ ...d.data(), uid: d.id }) as AppUser));
        setLoading(false);
      },
      () => setLoading(false)
    );
  }, [max]);
  return { entries, loading };
}
