'use client';
import { useEffect, useRef, useState } from 'react';
import type { Game, GameResult } from '@/lib/games';
import { GameHud } from './game-hud';

interface Target { id: number; fx: number; fy: number }

// Web port of the Flutter TapTargetsGame: targets drift to new spots each tick;
// tap one to score. Time-bound; success = score >= threshold.
export function TapTargetsGame({ game, onFinish }: { game: Game; onFinish: (r: GameResult) => void }) {
  const [targets, setTargets] = useState<Target[]>([]);
  const [score, setScore] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(game.timeLimitSec);
  const scoreRef = useRef(0);
  const finished = useRef(false);
  const nextId = useRef(0);

  const count = game.difficulty === 'Hard' ? 5 : 4;
  const intervalMs = game.difficulty === 'Hard' ? 450 : game.difficulty === 'Medium' ? 650 : 900;
  const rnd = () => 0.06 + Math.random() * 0.88;

  const finish = () => {
    if (finished.current) return;
    finished.current = true;
    onFinish({ score: scoreRef.current, success: scoreRef.current >= game.successScore });
  };

  const hit = (t: Target) => {
    if (finished.current) return;
    scoreRef.current += 1;
    setScore(scoreRef.current);
    setTargets((ts) => ts.map((x) => (x.id === t.id ? { ...x, fx: rnd(), fy: rnd() } : x)));
  };

  useEffect(() => {
    setTargets(Array.from({ length: count }, () => ({ id: nextId.current++, fx: rnd(), fy: rnd() })));
    const loop = setInterval(() => setTargets((ts) => ts.map((t) => ({ ...t, fx: rnd(), fy: rnd() }))), intervalMs);
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
      <div className="relative flex-1 overflow-hidden">
        {targets.map((t) => (
          <button
            key={t.id}
            onClick={() => hit(t)}
            className="absolute w-14 h-14 rounded-full flex items-center justify-center"
            style={{
              left: `${t.fx * 100}%`,
              top: `${t.fy * 100}%`,
              transform: 'translate(-50%,-50%)',
              transition: `all ${intervalMs}ms ease-in-out`,
              backgroundColor: 'rgba(91,225,255,0.15)',
              border: '2px solid #5BE1FF',
              boxShadow: '0 0 12px rgba(91,225,255,0.3)',
            }}
          >
            <span className="text-2xl">{game.emoji}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
