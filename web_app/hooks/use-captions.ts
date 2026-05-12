'use client';
import { useEffect, useState } from 'react';
import { ref as rtdbRef, onValue, off } from 'firebase/database';
import { rtdb } from '@/lib/firebase';

export interface CaptionState {
  text: string;
  t: number; // ms epoch
  isFinal: boolean;
}

const STALE_AFTER_MS = 5000;

export function useCaptions(streamId: string | undefined) {
  const [caption, setCaption] = useState<CaptionState | null>(null);
  const [stale, setStale] = useState(false);

  useEffect(() => {
    if (!streamId) return;
    const r = rtdbRef(rtdb, `captions/${streamId}/current`);
    const handler = onValue(r, snap => {
      const data = snap.val() as CaptionState | null;
      if (!data?.text) { setCaption(null); return; }
      setCaption(data);
      setStale(false);
    });
    return () => off(r, 'value', handler);
  }, [streamId]);

  // Mark caption stale after a period of silence so we can fade it out
  useEffect(() => {
    if (!caption) return;
    const elapsed = Date.now() - caption.t;
    const remaining = Math.max(0, STALE_AFTER_MS - elapsed);
    const t = setTimeout(() => setStale(true), remaining);
    return () => clearTimeout(t);
  }, [caption]);

  return { caption, stale };
}
