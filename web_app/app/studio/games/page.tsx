'use client';
import { useState } from 'react';
import Link from 'next/link';
import { doc, setDoc, deleteDoc, writeBatch } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useAuthStore } from '@/store/auth-store';
import { useIsAdmin } from '@/hooks/use-is-admin';
import { useGamesCatalog } from '@/hooks/use-games-catalog';
import { GAMES, ATTRIBUTE_LABELS, type Game, type GameType } from '@/lib/games';

const GAME_TYPES: GameType[] = ['tapTargets', 'fruitSlice', 'findObject'];
const DIFFICULTIES: Game['difficulty'][] = ['Easy', 'Medium', 'Hard'];

const blank: Game = {
  id: '', name: '', type: 'tapTargets', emoji: '🎮', description: '',
  timeLimitSec: 30, difficulty: 'Medium', attribute: 'pwr',
  rewardPoints: 10, successScore: 10, challengeCost: 100, enabled: true,
};

function gameToDoc(g: Game) {
  return {
    name: g.name, type: g.type, emoji: g.emoji, description: g.description,
    timeLimitSec: g.timeLimitSec, difficulty: g.difficulty, attribute: g.attribute,
    rewardPoints: g.rewardPoints, successScore: g.successScore,
    challengeCost: g.challengeCost, enabled: g.enabled !== false,
  };
}

function GameForm({ initial, isNew, onDone }: { initial: Game; isNew: boolean; onDone: () => void }) {
  const [g, setG] = useState<Game>(initial);
  const [saving, setSaving] = useState(false);
  const set = <K extends keyof Game>(k: K, v: Game[K]) => setG((p) => ({ ...p, [k]: v }));

  const save = async () => {
    const id = g.id.trim();
    if (!id || !g.name.trim()) return;
    setSaving(true);
    try {
      await setDoc(doc(db, 'games', id), gameToDoc(g), { merge: true });
      onDone();
    } catch {
      setSaving(false);
    }
  };

  const field = 'w-full bg-zinc-900 border border-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#5BE1FF] transition';
  const label = 'text-[11px] text-white/40 uppercase tracking-wider';

  return (
    <div className="bg-zinc-900 border border-[#5BE1FF]/30 rounded-xl p-5 space-y-3">
      <h3 className="font-semibold text-white">{isNew ? 'New Game' : `Edit ${initial.name}`}</h3>
      <div className="grid grid-cols-2 gap-3">
        <div>
          <p className={label}>ID {isNew && '*'}</p>
          <input className={field} placeholder="tap_easy" value={g.id} disabled={!isNew}
            onChange={(e) => set('id', e.target.value.replace(/\s+/g, '_'))} />
        </div>
        <div>
          <p className={label}>Emoji</p>
          <input className={field} value={g.emoji} onChange={(e) => set('emoji', e.target.value)} />
        </div>
      </div>
      <div>
        <p className={label}>Name *</p>
        <input className={field} value={g.name} onChange={(e) => set('name', e.target.value)} />
      </div>
      <div>
        <p className={label}>Description</p>
        <input className={field} value={g.description} onChange={(e) => set('description', e.target.value)} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div>
          <p className={label}>Type</p>
          <select className={field} value={g.type} onChange={(e) => set('type', e.target.value as GameType)}>
            {GAME_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>
        <div>
          <p className={label}>Difficulty</p>
          <select className={field} value={g.difficulty} onChange={(e) => set('difficulty', e.target.value as Game['difficulty'])}>
            {DIFFICULTIES.map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </div>
        <div>
          <p className={label}>Attribute</p>
          <select className={field} value={g.attribute} onChange={(e) => set('attribute', e.target.value)}>
            {Object.entries(ATTRIBUTE_LABELS).map(([code, name]) => <option key={code} value={code}>{name}</option>)}
          </select>
        </div>
        <div>
          <p className={label}>Time limit (s)</p>
          <input type="number" className={field} value={g.timeLimitSec} onChange={(e) => set('timeLimitSec', Number(e.target.value))} />
        </div>
        <div>
          <p className={label}>Reward points</p>
          <input type="number" className={field} value={g.rewardPoints} onChange={(e) => set('rewardPoints', Number(e.target.value))} />
        </div>
        <div>
          <p className={label}>Success score</p>
          <input type="number" className={field} value={g.successScore} onChange={(e) => set('successScore', Number(e.target.value))} />
        </div>
        <div>
          <p className={label}>Challenge cost (coins)</p>
          <input type="number" className={field} value={g.challengeCost} onChange={(e) => set('challengeCost', Number(e.target.value))} />
        </div>
        <label className="flex items-center gap-2 self-end pb-2 text-sm text-white/70">
          <input type="checkbox" checked={g.enabled !== false} onChange={(e) => set('enabled', e.target.checked)} />
          Enabled
        </label>
      </div>
      <div className="flex gap-2 pt-1">
        <button onClick={save} disabled={saving}
          className="px-4 py-2 bg-[#5BE1FF] text-[#0A1430] text-sm font-bold rounded-lg hover:opacity-90 transition disabled:opacity-50">
          {saving ? 'Saving…' : 'Save'}
        </button>
        <button onClick={onDone} className="px-4 py-2 text-sm text-white/50 hover:text-white transition">Cancel</button>
      </div>
    </div>
  );
}

export default function StudioGamesPage() {
  const { user } = useAuthStore();
  const isAdmin = useIsAdmin();
  const games = useGamesCatalog();
  const [editing, setEditing] = useState<Game | null>(null);
  const [creating, setCreating] = useState(false);
  const [seeding, setSeeding] = useState(false);

  if (!user) {
    return <div className="text-center py-24 text-white/40">Sign in to manage games.</div>;
  }
  if (!isAdmin) {
    return <div className="text-center py-24 text-white/40">This area is for administrators only.</div>;
  }

  const seedDefaults = async () => {
    if (!confirm('Write the built-in default games into Firestore? Existing games with the same ID are overwritten.')) return;
    setSeeding(true);
    try {
      const batch = writeBatch(db);
      GAMES.forEach((g) => batch.set(doc(db, 'games', g.id), gameToDoc(g), { merge: true }));
      await batch.commit();
    } finally {
      setSeeding(false);
    }
  };

  const remove = async (g: Game) => {
    if (!confirm(`Delete "${g.name}"? Streamers will fall back to the built-in catalog if none remain.`)) return;
    await deleteDoc(doc(db, 'games', g.id));
  };

  return (
    <div className="max-w-2xl mx-auto px-4 py-8" style={{ color: '#CFE8FF' }}>
      <div className="flex items-center gap-4 mb-6">
        <Link href="/studio" className="text-white/40 hover:text-white transition text-sm">← Studio</Link>
        <h1 className="text-xl font-bold text-white">Game Catalog</h1>
        <div className="ml-auto flex gap-2">
          <button onClick={seedDefaults} disabled={seeding}
            className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white/70 hover:text-white text-sm font-semibold rounded-lg transition disabled:opacity-50">
            {seeding ? 'Seeding…' : '↓ Load defaults'}
          </button>
          <button onClick={() => { setCreating(true); setEditing(null); }}
            className="px-4 py-2 bg-[#5BE1FF] text-[#0A1430] text-sm font-bold rounded-lg hover:opacity-90 transition">
            + New Game
          </button>
        </div>
      </div>

      <p className="text-[11px] text-white/30 mb-4">
        Games authored here replace the built-in catalog on both apps. If you delete them all, both apps fall back to the built-in set.
      </p>

      {creating && <div className="mb-4"><GameForm initial={blank} isNew onDone={() => setCreating(false)} /></div>}
      {editing && <div className="mb-4"><GameForm initial={editing} isNew={false} onDone={() => setEditing(null)} /></div>}

      <div className="space-y-3">
        {games.map((g) => (
          <div key={g.id} className="flex items-center gap-3 rounded-2xl p-3.5"
            style={{ border: `1px solid rgba(91,225,255,${g.enabled === false ? 0.2 : 0.45})`, backgroundColor: 'rgba(255,255,255,0.04)' }}>
            <span className="text-3xl">{g.emoji}</span>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-extrabold truncate">{g.name}</span>
                <span className="text-[10px] text-white/30">{g.id}</span>
                {g.enabled === false && <span className="text-[9px] px-1.5 py-0.5 rounded-full bg-white/10 text-white/40">HIDDEN</span>}
              </div>
              <p className="text-[11px] text-[#6E86B0]">
                {g.type} · {g.difficulty} · ⏱ {g.timeLimitSec}s · +{g.rewardPoints} {ATTRIBUTE_LABELS[g.attribute] ?? g.attribute} · 💰 {g.challengeCost}
              </p>
            </div>
            <button onClick={() => { setEditing(g); setCreating(false); }} className="text-xs font-bold text-[#5BE1FF] hover:opacity-80">Edit</button>
            <button onClick={() => remove(g)} className="text-xs font-bold text-red-400 hover:opacity-80">Delete</button>
          </div>
        ))}
      </div>
    </div>
  );
}
