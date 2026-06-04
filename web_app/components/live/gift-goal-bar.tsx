'use client';
import { LiveStream } from '@/lib/types';

/**
 * Gift-goal progress bar — fills as totalGifts approaches the host's coin
 * target. Renders nothing when no goal is set. Mirrors the Flutter
 * GiftGoalBar.
 */
export function GiftGoalBar({ stream }: { stream: LiveStream }) {
  const target = stream.giftGoalTarget ?? 0;
  if (target <= 0) return null;
  const total = stream.totalGifts;
  const pct = Math.min(1, total / target);
  const reached = total >= target;
  const remaining = Math.max(0, target - total);

  return (
    <div className="w-[260px] max-w-full rounded-xl border border-white/10 bg-black/50 backdrop-blur px-3 py-2">
      <div className="flex items-center justify-between gap-2 mb-1">
        <span className="text-xs font-bold text-white truncate">🎯 {stream.giftGoalLabel ?? 'Gift goal'}</span>
        <span className="text-[11px] font-bold text-[#FFD166] whitespace-nowrap">
          {total.toLocaleString()} / {target.toLocaleString()} 🪙
        </span>
      </div>
      <div className="h-1.5 rounded-full bg-white/[0.12] overflow-hidden">
        <div className="h-full bg-[#FFD166] transition-all" style={{ width: `${pct * 100}%` }} />
      </div>
      <p className="mt-1 text-[10px] text-white/50">
        {reached ? 'Goal reached! 🎉' : `${Math.round(pct * 100)}% · ${remaining.toLocaleString()} 🪙 to go`}
      </p>
    </div>
  );
}
