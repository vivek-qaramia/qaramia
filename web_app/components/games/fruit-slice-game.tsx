'use client';
import { useEffect, useRef, useState } from 'react';
import type { Game, GameResult } from '@/lib/games';
import { GameHud } from './game-hud';

interface Fruit { id: number; fx: number; fy: number; emoji: string }

const FRUITS = ['🍉', '🍊', '🍎', '🍓', '🍇', '🍌', '🥝', '🍑'];

// Web port of the Flutter FruitSliceGame: fruit falls from the top; swipe
// (pointer drag) across it to slice. Time-bound; success = score >= threshold.
export function FruitSliceGame({ game, onFinish }: { game: Game; onFinish: (r: GameResult) => void }) {
  const [fruits, setFruits] = useState<Fruit[]>([]);
  const [score, setScore] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(game.timeLimitSec);
  const fruitsRef = useRef<Fruit[]>([]);
  const scoreRef = useRef(0);
  const finished = useRef(false);
  const nextId = useRef(0);
  const spawnTick = useRef(0);
  const down = useRef(false);

  const commit = (fs: Fruit[]) => { fruitsRef.current = fs; setFruits(fs); };

  const fallSpeed = game.difficulty === 'Hard' ? 0.022 : game.difficulty === 'Medium' ? 0.016 : 0.012;
  const spawnEvery = game.difficulty === 'Hard' ? 6 : game.difficulty === 'Medium' ? 9 : 12;

  const finish = () => {
    if (finished.current) return;
    finished.current = true;
    onFinish({ score: scoreRef.current, success: scoreRef.current >= game.successScore });
  };

  const sliceAt = (px: number, py: number) => {
    if (finished.current) return;
    const fs = fruitsRef.current;
    const hitIdx = fs.findIndex((f) => Math.hypot(px - f.fx, py - f.fy) < 0.08);
    if (hitIdx === -1) return;
    scoreRef.current += 1;
    setScore(scoreRef.current);
    commit(fs.filter((_, i) => i !== hitIdx));
  };

  const onPointer = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!down.current) return;
    const rect = e.currentTarget.getBoundingClientRect();
    sliceAt((e.clientX - rect.left) / rect.width, (e.clientY - rect.top) / rect.height);
  };

  useEffect(() => {
    const loop = setInterval(() => {
      const moved = fruitsRef.current.map((f) => ({ ...f, fy: f.fy + fallSpeed })).filter((f) => f.fy < 1.1);
      if (++spawnTick.current >= spawnEvery) {
        spawnTick.current = 0;
        moved.push({ id: nextId.current++, fx: 0.04 + Math.random() * 0.9, fy: -0.06, emoji: FRUITS[Math.floor(Math.random() * FRUITS.length)] });
      }
      commit(moved);
    }, 60);
    const clock = setInterval(() => setSecondsLeft((s) => s - 1), 1000);
    return () => { clearInterval(loop); clearInterval(clock); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (secondsLeft <= 0) finish();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [secondsLeft]);

  return (
    <div className="flex flex-col h-full" style={{ backgroundColor: '#0A1430' }}>
      <GameHud score={score} successScore={game.successScore} secondsLeft={secondsLeft} timeLimitSec={game.timeLimitSec} />
      <div
        className="relative flex-1 overflow-hidden touch-none"
        onPointerDown={(e) => { down.current = true; onPointer(e); }}
        onPointerMove={onPointer}
        onPointerUp={() => { down.current = false; }}
        onPointerLeave={() => { down.current = false; }}
      >
        {fruits.map((f) => (
          <div
            key={f.id}
            className="absolute pointer-events-none select-none"
            style={{ left: `${f.fx * 100}%`, top: `${f.fy * 100}%`, transform: 'translate(-50%,-50%)', fontSize: 42 }}
          >
            {f.emoji}
          </div>
        ))}
      </div>
    </div>
  );
}
