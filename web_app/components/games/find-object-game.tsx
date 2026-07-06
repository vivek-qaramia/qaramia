'use client';
import { useEffect, useRef, useState } from 'react';
import type { Game, GameResult } from '@/lib/games';
import { GameHud } from './game-hud';

interface Item { key: number; emoji: string; fx: number; fy: number; isTarget: boolean }

const POOL = ['🐱', '🐶', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐸', '🐵', '🐰', '🐹', '🐮', '🐷'];

// Web port of the Flutter FindObjectGame: a target emoji is shown; tap the
// single matching one among decoys. Each correct tap reshuffles a new round.
export function FindObjectGame({ game, onFinish }: { game: Game; onFinish: (r: GameResult) => void }) {
  const [items, setItems] = useState<Item[]>([]);
  const [target, setTarget] = useState('🐱');
  const [score, setScore] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(game.timeLimitSec);
  const scoreRef = useRef(0);
  const finished = useRef(false);
  const keyRef = useRef(0);

  const count = game.difficulty === 'Hard' ? 26 : game.difficulty === 'Medium' ? 18 : 12;
  const rnd = () => Math.random();

  const finish = () => {
    if (finished.current) return;
    finished.current = true;
    onFinish({ score: scoreRef.current, success: scoreRef.current >= game.successScore });
  };

  const newRound = () => {
    const t = POOL[Math.floor(Math.random() * POOL.length)];
    const decoys = POOL.filter((e) => e !== t);
    const next: Item[] = [{ key: keyRef.current++, emoji: t, fx: rnd(), fy: rnd(), isTarget: true }];
    for (let i = 0; i < count - 1; i++) {
      next.push({ key: keyRef.current++, emoji: decoys[Math.floor(Math.random() * decoys.length)], fx: rnd(), fy: rnd(), isTarget: false });
    }
    next.sort(() => Math.random() - 0.5);
    setTarget(t);
    setItems(next);
  };

  const tap = (it: Item) => {
    if (finished.current || !it.isTarget) return;
    scoreRef.current += 1;
    setScore(scoreRef.current);
    newRound();
  };

  useEffect(() => {
    newRound();
    const clock = setInterval(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearInterval(clock);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (secondsLeft <= 0) finish();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [secondsLeft]);

  return (
    <div className="flex flex-col h-full" style={{ backgroundColor: '#0A1430' }}>
      <GameHud score={score} successScore={game.successScore} secondsLeft={secondsLeft} timeLimitSec={game.timeLimitSec} />
      <div className="flex items-center justify-center gap-2 py-2">
        <span className="font-extrabold" style={{ color: '#5BE1FF' }}>Find:</span>
        <span className="text-3xl">{target}</span>
      </div>
      <div className="relative flex-1 overflow-hidden">
        {items.map((it) => (
          <button
            key={it.key}
            onClick={() => tap(it)}
            className="absolute select-none"
            style={{ left: `${it.fx * 88 + 6}%`, top: `${it.fy * 88 + 6}%`, transform: 'translate(-50%,-50%)', fontSize: 30 }}
          >
            {it.emoji}
          </button>
        ))}
      </div>
    </div>
  );
}
