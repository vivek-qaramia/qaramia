'use client';
import { useState } from 'react';
import { collection, query, where, getDocs, limit } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { AppUser } from '@/lib/types';
import { CoHost, sendCoHostInvite } from '@/hooks/use-cohosts';

interface Props {
  streamId: string;
  hostUsername: string;
  cohosts: CoHost[];
}

export function CohostInvite({ streamId, hostUsername, cohosts }: Props) {
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<AppUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [inviting, setInviting] = useState<string | null>(null);

  const handleSearch = async (q: string) => {
    setSearch(q);
    if (q.length < 2) { setResults([]); return; }
    setSearching(true);
    const snap = await getDocs(
      query(
        collection(db, 'users'),
        where('username', '>=', q),
        where('username', '<', q + 'z'),
        limit(5),
      ),
    );
    setResults(snap.docs.map((d) => ({ ...d.data(), uid: d.id, createdAt: d.data().createdAt?.toDate() }) as AppUser));
    setSearching(false);
  };

  const invite = async (user: AppUser) => {
    setInviting(user.uid);
    await sendCoHostInvite(streamId, hostUsername, user.uid, user.username, user.avatarUrl);
    setInviting(null);
    setSearch('');
    setResults([]);
  };

  const statusBadge = (status: CoHost['status']) => {
    const map = {
      invited: 'bg-yellow-500/20 text-yellow-400',
      accepted: 'bg-blue-500/20 text-blue-400',
      active: 'bg-green-500/20 text-green-400',
      declined: 'bg-red-500/20 text-red-400',
    };
    return map[status] ?? '';
  };

  return (
    <div className="space-y-3">
      <p className="text-xs text-white/40 uppercase tracking-wider font-semibold">Co-hosts</p>

      {/* Current co-hosts */}
      {cohosts.length > 0 && (
        <div className="space-y-1.5">
          {cohosts.map((c) => (
            <div key={c.uid} className="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2">
              <div className="w-7 h-7 rounded-full bg-zinc-700 flex-shrink-0 overflow-hidden">
                {c.avatarUrl && <img src={c.avatarUrl} alt="" className="w-full h-full object-cover" />}
              </div>
              <span className="text-sm flex-1">@{c.username}</span>
              <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold ${statusBadge(c.status)}`}>
                {c.status}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* Search to invite */}
      <div className="relative">
        <input
          value={search}
          onChange={(e) => handleSearch(e.target.value)}
          placeholder="Invite by username..."
          className="w-full bg-white/10 border border-white/10 rounded-xl px-3 py-2 text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#FF7043] transition"
        />
        {searching && (
          <div className="absolute right-3 top-2.5 w-4 h-4 border-2 border-white/30 border-t-transparent rounded-full animate-spin" />
        )}
      </div>

      {results.length > 0 && (
        <div className="bg-zinc-900 rounded-xl border border-white/10 overflow-hidden">
          {results.map((user) => {
            const alreadyInvited = cohosts.some((c) => c.uid === user.uid);
            return (
              <div key={user.uid} className="flex items-center gap-2 px-3 py-2 hover:bg-white/5 transition">
                <div className="w-7 h-7 rounded-full bg-zinc-700 flex-shrink-0 overflow-hidden">
                  {user.avatarUrl && <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium">@{user.username}</p>
                  <p className="text-xs text-white/40">{user.displayName}</p>
                </div>
                <button
                  disabled={alreadyInvited || inviting === user.uid}
                  onClick={() => invite(user)}
                  className="px-3 py-1 bg-[#FF7043] hover:bg-[#e55a2b] disabled:opacity-40 rounded-lg text-xs font-semibold transition"
                >
                  {alreadyInvited ? 'Invited' : inviting === user.uid ? '...' : 'Invite'}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
