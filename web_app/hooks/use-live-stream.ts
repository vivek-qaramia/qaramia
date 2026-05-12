'use client';
import { useEffect, useState } from 'react';
import { collection, query, where, orderBy, limit, onSnapshot, doc } from 'firebase/firestore';
import { ref as rtdbRef, onChildAdded, limitToLast, query as rtdbQuery, orderByChild } from 'firebase/database';
import { db, rtdb } from '@/lib/firebase';
import { LiveStream, ChatMessage } from '@/lib/types';

export function useLiveStreams() {
  const [streams, setStreams] = useState<LiveStream[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, 'streams'),
      where('status', '==', 'live'),
      orderBy('viewerCount', 'desc'),
      limit(50)
    );
    const unsub = onSnapshot(q, (snap) => {
      setStreams(snap.docs.map((d) => ({
        ...d.data(),
        id: d.id,
        startedAt: d.data().startedAt?.toDate(),
        endedAt: d.data().endedAt?.toDate(),
      })) as LiveStream[]);
      setLoading(false);
    });
    return unsub;
  }, []);

  return { streams, loading };
}

export function useSingleStream(streamId: string | null) {
  const [stream, setStream] = useState<LiveStream | null>(null);

  useEffect(() => {
    if (!streamId) return;
    const unsub = onSnapshot(doc(db, 'streams', streamId), (snap) => {
      if (snap.exists()) {
        setStream({ ...snap.data(), id: snap.id, startedAt: snap.data().startedAt?.toDate() } as LiveStream);
      }
    });
    return unsub;
  }, [streamId]);

  return stream;
}

export function useDanmaku(streamId: string, maxMessages = 100) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);

  useEffect(() => {
    if (!streamId) return;
    const messagesRef = rtdbQuery(
      rtdbRef(rtdb, `danmaku/${streamId}`),
      orderByChild('sentAt'),
      limitToLast(maxMessages)
    );
    const unsub = onChildAdded(messagesRef, (snapshot) => {
      const data = snapshot.val() as ChatMessage;
      setMessages((prev) => [...prev.slice(-99), { ...data, id: snapshot.key ?? '' }]);
    });
    return () => unsub();
  }, [streamId, maxMessages]);

  return messages;
}
