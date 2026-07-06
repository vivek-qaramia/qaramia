'use client';
import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { GAMES, type Game, type GameType } from '@/lib/games';

function gameFromDoc(id: string, d: Record<string, unknown>): Game {
  return {
    id,
    name: (d.name as string) ?? id,
    type: ((d.type as string) ?? 'tapTargets') as GameType,
    emoji: (d.emoji as string) ?? '🎮',
    description: (d.description as string) ?? '',
    timeLimitSec: (d.timeLimitSec as number) ?? 30,
    difficulty: ((d.difficulty as string) ?? 'Medium') as Game['difficulty'],
    attribute: (d.attribute as string) ?? 'pwr',
    rewardPoints: (d.rewardPoints as number) ?? 10,
    successScore: (d.successScore as number) ?? 10,
    challengeCost: (d.challengeCost as number) ?? 100,
    enabled: (d.enabled as boolean) ?? true,
  };
}

// Live game catalog — Firestore-authored games (3d) when the collection is
// non-empty, else the in-code GAMES fallback. Mirrors the Flutter
// gamesCatalogProvider.
export function useGamesCatalog(): Game[] {
  const [games, setGames] = useState<Game[]>(GAMES);
  useEffect(() => {
    return onSnapshot(collection(db, 'games'), (snap) => {
      setGames(snap.empty ? GAMES : snap.docs.map((d) => gameFromDoc(d.id, d.data())));
    });
  }, []);
  return games;
}
