import { db } from '@/lib/firebase';
import {
  collection,
  doc,
  setDoc,
  updateDoc,
  runTransaction,
  serverTimestamp,
  increment,
} from 'firebase/firestore';
import type { ChallengeGame } from '@/lib/games';

// Web port of the Flutter GameChallengeService (Game Zone 3c). Coins move only
// on accept, settled by the viewer's own client (the wallet owner) — the host
// can't spend someone else's coins under the Firestore rules. Diamonds to the
// streamer at coins/2, matching gifts and the mobile side.

export interface GameChallenge {
  id: string;
  fromUid: string;
  fromUsername: string;
  gameId: string;
  gameName: string;
  coins: number;
  status: string; // pending | accepted | declined | paid | failed
}

export function challengeFromDoc(id: string, d: Record<string, unknown>): GameChallenge {
  return {
    id,
    fromUid: (d.fromUid as string) ?? '',
    fromUsername: (d.fromUsername as string) ?? 'viewer',
    gameId: (d.gameId as string) ?? '',
    gameName: (d.gameName as string) ?? 'a game',
    coins: (d.coins as number) ?? 0,
    status: (d.status as string) ?? 'pending',
  };
}

/// Viewer sends a challenge. No coins move yet — charged only if accepted.
export async function sendChallenge(opts: {
  streamId: string;
  fromUid: string;
  fromUsername: string;
  game: ChallengeGame;
}): Promise<void> {
  const ref = doc(collection(db, 'streams', opts.streamId, 'gameChallenges'));
  await setDoc(ref, {
    fromUid: opts.fromUid,
    fromUsername: opts.fromUsername,
    gameId: opts.game.id,
    gameName: opts.game.name,
    coins: opts.game.challengeCost,
    status: 'pending',
    createdAt: serverTimestamp(),
  });
}

/// Viewer-side settlement once the host accepts: deduct the viewer's coins,
/// credit the host's diamonds (coins/2), mark paid. Marks 'failed' if the
/// viewer can no longer afford it. No-op unless the challenge is 'accepted'.
export async function payAcceptedChallenge(opts: {
  streamId: string;
  challenge: GameChallenge;
  hostUid: string;
}): Promise<void> {
  const { streamId, challenge: ch, hostUid } = opts;
  const walletRef = doc(db, 'users', ch.fromUid, 'wallet', 'default');
  const creatorBalRef = doc(db, 'users', hostUid, 'creatorBalance', 'default');
  const chRef = doc(db, 'streams', streamId, 'gameChallenges', ch.id);
  const diamonds = Math.floor(ch.coins / 2);

  await runTransaction(db, async (tx) => {
    const chSnap = await tx.get(chRef);
    if (chSnap.data()?.status !== 'accepted') return; // already settled
    const coins = (await tx.get(walletRef)).data()?.coins ?? 0;
    if (coins < ch.coins) {
      tx.update(chRef, { status: 'failed' });
      return;
    }
    tx.set(walletRef, { coins: increment(-ch.coins), updatedAt: serverTimestamp() }, { merge: true });
    tx.set(creatorBalRef, {
      diamonds: increment(diamonds),
      lifetimeDiamonds: increment(diamonds),
      updatedAt: serverTimestamp(),
    }, { merge: true });
    tx.update(chRef, { status: 'paid' });
  });
}
