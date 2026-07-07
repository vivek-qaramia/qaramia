'use client';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth-store';
import { useLeaderboard } from '@/hooks/use-leaderboard';
import { streamerStats } from '@/lib/streamer-stats';
import type { AppUser } from '@/lib/types';

const short = (v: number) =>
  v >= 1_000_000 ? `${(v / 1_000_000).toFixed(1)}M` : v >= 1_000 ? `${(v / 1_000).toFixed(1)}K` : `${v}`;

const medal = (rank: number) => (rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : null);

function Row({ user, rank, isMe }: { user: AppUser; rank: number; isMe: boolean }) {
  const { level, title } = streamerStats(user);
  const xp = user.systemXp ?? 0;
  return (
    <Link
      href={`/profile/${user.uid}`}
      className="flex items-center gap-3 rounded-2xl p-3.5 transition hover:bg-white/[0.06]"
      style={{
        border: `1px solid ${isMe ? 'rgba(91,225,255,0.6)' : 'rgba(255,255,255,0.08)'}`,
        backgroundColor: isMe ? 'rgba(91,225,255,0.08)' : 'rgba(255,255,255,0.03)',
      }}
    >
      <div className="w-9 text-center shrink-0 text-lg font-black">
        {medal(rank) ?? <span className="text-white/40 text-base">{rank}</span>}
      </div>
      <div className="w-11 h-11 rounded-full bg-zinc-700 overflow-hidden shrink-0">
        {user.avatarUrl && <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />}
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-bold truncate text-white">@{user.username}{isMe && <span className="text-[#5BE1FF]"> · you</span>}</p>
        <p className="text-[11px] text-[#6E86B0]">Lv {level} · {title}</p>
      </div>
      <div className="text-right shrink-0">
        <p className="font-black" style={{ color: '#5BE1FF' }}>Lv {level}</p>
        <p className="text-[10px] text-white/40">{short(xp)} XP</p>
      </div>
    </Link>
  );
}

export default function LeaderboardPage() {
  const { user } = useAuthStore();
  const { entries, loading } = useLeaderboard(50);

  return (
    <div className="max-w-2xl mx-auto px-4 py-8" style={{ color: '#CFE8FF' }}>
      <h1 className="text-xl font-extrabold mb-1">🏆 System Leaderboard</h1>
      <p className="text-[12px] text-[#6E86B0] mb-5">Top streamers ranked by System level — earned from followers, likes, and Game Zone play.</p>

      {loading ? (
        <div className="space-y-3">
          {[...Array(8)].map((_, i) => (
            <div key={i} className="h-[68px] rounded-2xl animate-pulse" style={{ backgroundColor: 'rgba(255,255,255,0.05)' }} />
          ))}
        </div>
      ) : entries.length === 0 ? (
        <div className="text-center py-16 text-white/40">
          <p className="text-4xl mb-3">🏆</p>
          <p className="font-semibold">No ranked streamers yet</p>
          <p className="text-sm mt-1">Gain followers, likes, or play Game Zone tasks to climb the board.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {entries.map((u, i) => (
            <Row key={u.uid} user={u} rank={i + 1} isMe={!!user && user.uid === u.uid} />
          ))}
        </div>
      )}
    </div>
  );
}
