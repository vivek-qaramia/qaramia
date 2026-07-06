'use client';
import { useEffect, useRef, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useAuthStore } from '@/store/auth-store';
import { gamesForDay, dayKey, ATTRIBUTE_LABELS, type Game, type GameResult } from '@/lib/games';
import { completeGameTask } from '@/lib/game-progress';
import { useGamesCatalog } from '@/hooks/use-games-catalog';
import { GamePlayer } from '@/components/games/game-player';

interface Progress {
  attributes: Record<string, number>;
  gameTasksDate?: string;
  gameTasksDone: string[];
}

export default function GamesPage() {
  const { user } = useAuthStore();
  const catalog = useGamesCatalog();
  const [progress, setProgress] = useState<Progress>({ attributes: {}, gameTasksDone: [] });
  const progressRef = useRef(progress);
  progressRef.current = progress;
  const [playing, setPlaying] = useState<Game | null>(null);
  const [resultMsg, setResultMsg] = useState<string | null>(null);

  useEffect(() => {
    if (!user?.uid) return;
    return onSnapshot(doc(db, 'users', user.uid), (snap) => {
      const d = snap.data() ?? {};
      setProgress({
        attributes: (d.attributes as Record<string, number>) ?? {},
        gameTasksDate: d.gameTasksDate as string | undefined,
        gameTasksDone: (d.gameTasksDone as string[]) ?? [],
      });
    });
  }, [user?.uid]);

  if (!user) {
    return <div className="text-center py-24 text-white/40">Sign in to play the Game Zone.</div>;
  }

  const today = dayKey(new Date());
  const games = catalog.filter((g) => g.enabled !== false);
  const dailyIds = new Set(gamesForDay(catalog, new Date()).map((g) => g.id));
  const doneToday = progress.gameTasksDate === today ? progress.gameTasksDone : [];
  const earned = Object.entries(progress.attributes).filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]);

  const onFinish = async (game: Game, r: GameResult) => {
    setPlaying(null);
    if (r.success) {
      const p = progressRef.current;
      const done = p.gameTasksDate === today ? p.gameTasksDone : [];
      try {
        await completeGameTask({ uid: user.uid, game, doneToday: done });
      } catch { /* the play still happened */ }
      setResultMsg(`⚡ Cleared! +${game.rewardPoints} ${ATTRIBUTE_LABELS[game.attribute] ?? game.attribute}`);
    } else {
      setResultMsg(`So close — score ${r.score}, needed ${game.successScore}.`);
    }
  };

  return (
    <div className="max-w-2xl mx-auto px-4 py-8" style={{ color: '#CFE8FF' }}>
      <h1 className="text-xl font-extrabold mb-4">⚡ Game Zone</h1>

      {/* Attribute strip */}
      <div className="rounded-2xl p-4 mb-6" style={{ border: '1px solid rgba(91,225,255,0.4)', backgroundColor: 'rgba(255,255,255,0.03)' }}>
        <p className="text-[11px] font-extrabold tracking-[2px]" style={{ color: '#5BE1FF' }}>YOUR ATTRIBUTES</p>
        <div className="mt-2 flex flex-wrap gap-2">
          {earned.length === 0 ? (
            <span className="text-xs text-[#6E86B0]">Play a task to earn your first points.</span>
          ) : (
            earned.map(([code, v]) => (
              <span key={code} className="px-2.5 py-1.5 rounded-full text-xs font-bold" style={{ backgroundColor: 'rgba(91,225,255,0.12)' }}>
                {(ATTRIBUTE_LABELS[code] ?? code).toUpperCase()} {v}
              </span>
            ))
          )}
        </div>
      </div>

      <p className="text-[12px] font-extrabold tracking-[1.5px] text-[#6E86B0] mb-3">GAMES</p>
      <div className="space-y-3">
        {games.map((g) => {
          const done = doneToday.includes(g.id);
          return (
            <div key={g.id} className="flex items-center gap-3 rounded-2xl p-3.5"
              style={{ border: `1px solid rgba(91,225,255,${done ? 0.25 : 0.5})`, backgroundColor: 'rgba(255,255,255,0.04)' }}>
              <span className="text-3xl">{g.emoji}</span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="font-extrabold truncate">{g.name}</span>
                  {dailyIds.has(g.id) && (
                    <span className="px-1.5 py-0.5 rounded-full text-[9px] font-extrabold tracking-wider" style={{ backgroundColor: 'rgba(91,225,255,0.18)', color: '#5BE1FF' }}>DAILY ⭐</span>
                  )}
                </div>
                <p className="text-[11px] text-[#6E86B0]">{g.difficulty} · ⏱ {g.timeLimitSec}s · +{g.rewardPoints} {ATTRIBUTE_LABELS[g.attribute] ?? g.attribute}</p>
              </div>
              {done ? (
                <span className="font-extrabold text-sm" style={{ color: '#5BE1FF' }}>Done ✓</span>
              ) : (
                <button onClick={() => setPlaying(g)} className="px-5 py-2 rounded-full font-black text-sm" style={{ backgroundColor: '#5BE1FF', color: '#0A1430' }}>Play</button>
              )}
            </div>
          );
        })}
      </div>

      {/* Full-screen play overlay */}
      {playing && (
        <div className="fixed inset-0 z-50" style={{ backgroundColor: '#0A1430' }}>
          <GamePlayer game={playing} onFinish={(r) => onFinish(playing, r)} />
        </div>
      )}

      {/* Result dialog */}
      {resultMsg && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/60" onClick={() => setResultMsg(null)}>
          <div className="rounded-2xl p-6 max-w-xs text-center" style={{ backgroundColor: '#0A1430', border: '1px solid rgba(91,225,255,0.55)' }}>
            <p className="mb-4">{resultMsg}</p>
            <button onClick={() => setResultMsg(null)} className="px-6 py-2 rounded-full font-bold" style={{ backgroundColor: '#5BE1FF', color: '#0A1430' }}>OK</button>
          </div>
        </div>
      )}
    </div>
  );
}
