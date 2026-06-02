'use client';
import { useTopGifters } from '@/hooks/use-top-gifters';
import { useAuthStore } from '@/store/auth-store';

/**
 * Compact live leaderboard of a stream's top gifters (by coins spent), with a
 * "You: #N" footer for the signed-in viewer. Mirrors the Flutter
 * TopGiftersBoard widget.
 */
export function TopGiftersBoard({ streamId }: { streamId: string }) {
  const { user } = useAuthStore();
  const { top, myRank } = useTopGifters(streamId, user?.uid);

  if (top.length === 0) return null;

  const visible = top.slice(0, 3);
  const meInTop = user ? top.slice(0, 3).some((g) => g.senderUid === user.uid) : false;
  const medal = (rank: number) => (rank === 1 ? '👑' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : `${rank}.`);

  return (
    <div className="max-w-[220px] rounded-xl border border-white/10 bg-black/45 backdrop-blur px-2.5 py-2">
      <div className="flex items-center gap-1 mb-1">
        <span className="text-[11px]">🏆</span>
        <span className="text-[10px] font-extrabold tracking-wider text-[#FFD166]">TOP GIFTERS</span>
      </div>
      <div className="space-y-0.5">
        {visible.map((g, i) => {
          const isMe = user?.uid === g.senderUid;
          return (
            <div key={g.senderUid} className="flex items-center gap-1 text-[11px]">
              <span className="w-[18px] shrink-0 text-white/70">{medal(i + 1)}</span>
              <span className={`flex-1 truncate ${isMe ? 'font-extrabold text-[#FFD166]' : 'font-semibold text-white'}`}>
                @{g.username}
              </span>
              <span className="font-bold text-[#FFD166]">{g.totalCoins.toLocaleString()}</span>
              <span className="text-[8px]">🪙</span>
            </div>
          );
        })}
      </div>
      {user && !meInTop && myRank && (
        <>
          <div className="my-1.5 h-px bg-white/10" />
          <div className="flex items-center text-[11px]">
            <span className="font-extrabold text-[#FFD166]">You: #{myRank.rank}</span>
            <span className="flex-1" />
            <span className="font-bold text-[#FFD166]">{myRank.totalCoins.toLocaleString()}</span>
            <span className="ml-0.5 text-[8px]">🪙</span>
          </div>
        </>
      )}
    </div>
  );
}
