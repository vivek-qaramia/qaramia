'use client';
import { useEffect, useState } from 'react';
import {
  collection, onSnapshot, doc, setDoc, updateDoc,
  serverTimestamp, query, where, getDocs,
} from 'firebase/firestore';
import { db } from '@/lib/firebase';

export type CoHostStatus = 'invited' | 'accepted' | 'active' | 'declined';

export interface CoHost {
  uid: string;
  username: string;
  avatarUrl?: string;
  status: CoHostStatus;
}

export function useCohosts(streamId: string) {
  const [cohosts, setCohosts] = useState<CoHost[]>([]);

  useEffect(() => {
    if (!streamId) return;
    const unsub = onSnapshot(
      collection(db, 'streams', streamId, 'cohosts'),
      (snap) => setCohosts(snap.docs.map((d) => ({ ...d.data(), uid: d.id } as CoHost))),
    );
    return unsub;
  }, [streamId]);

  return cohosts;
}

export async function inviteCoHost(
  streamId: string,
  targetUid: string,
  username: string,
  avatarUrl?: string,
) {
  await setDoc(doc(db, 'streams', streamId, 'cohosts', targetUid), {
    uid: targetUid,
    username,
    avatarUrl: avatarUrl ?? null,
    status: 'invited',
    invitedAt: serverTimestamp(),
  });
}

export async function acceptCoHostInvite(streamId: string, uid: string) {
  await updateDoc(doc(db, 'streams', streamId, 'cohosts', uid), {
    status: 'accepted',
    acceptedAt: serverTimestamp(),
  });
}

export async function setCoHostActive(streamId: string, uid: string) {
  await updateDoc(doc(db, 'streams', streamId, 'cohosts', uid), {
    status: 'active',
    joinedAt: serverTimestamp(),
  });
}

// Check if the current user has a pending invite for any live stream
export function usePendingCoHostInvite(uid: string) {
  const [invite, setInvite] = useState<{ streamId: string; hostUsername: string } | null>(null);

  useEffect(() => {
    if (!uid) return;
    // Listen across all streams where this user is invited
    // We do this by watching the user's own invite subcollection (denormalised)
    const unsub = onSnapshot(
      doc(db, 'users', uid, 'cohost_invites', 'latest'),
      (snap) => {
        if (snap.exists() && snap.data().status === 'invited') {
          setInvite({ streamId: snap.data().streamId, hostUsername: snap.data().hostUsername });
        } else {
          setInvite(null);
        }
      },
    );
    return unsub;
  }, [uid]);

  return invite;
}

// Host calls this — writes invite to both the stream subcollection AND the user's invite doc
export async function sendCoHostInvite(
  streamId: string,
  hostUsername: string,
  targetUid: string,
  targetUsername: string,
  targetAvatarUrl?: string,
) {
  // Write to stream's cohost list
  await inviteCoHost(streamId, targetUid, targetUsername, targetAvatarUrl);
  // Write a denormalised invite to the user's profile so they can detect it easily
  await setDoc(doc(db, 'users', targetUid, 'cohost_invites', 'latest'), {
    streamId,
    hostUsername,
    status: 'invited',
    invitedAt: serverTimestamp(),
  });
}

export async function declineCoHostInvite(streamId: string, uid: string) {
  await updateDoc(doc(db, 'streams', streamId, 'cohosts', uid), { status: 'declined' });
  await updateDoc(doc(db, 'users', uid, 'cohost_invites', 'latest'), { status: 'declined' });
}
