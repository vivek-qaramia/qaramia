import type { StreamerStats } from '@/lib/streamer-stats';

// LitRPG "System" status card — web port of the Flutter SystemStatusCard.
// Pure/presentational: takes computed stats + a name.

const ACCENT = '#5BE1FF';

function SegBar({ fill }: { fill: number }) {
  const lit = Math.round(Math.max(0, Math.min(1, fill)) * 10);
  return (
    <div className="flex gap-[3px] flex-1">
      {Array.from({ length: 10 }, (_, i) => (
        <div
          key={i}
          className="h-[9px] flex-1 rounded-[2px]"
          style={{ backgroundColor: i < lit ? ACCENT : 'rgba(91,225,255,0.14)' }}
        />
      ))}
    </div>
  );
}

export function SystemStatusCard({ stats, name }: { stats: StreamerStats; name: string }) {
  const pct = Math.round(stats.expProgress * 100);
  return (
    <div
      className="rounded-2xl p-4 font-mono"
      style={{
        backgroundColor: 'rgba(10,20,48,0.95)',
        border: '1px solid rgba(91,225,255,0.55)',
        boxShadow: '0 0 24px rgba(91,225,255,0.2)',
      }}
    >
      <div className="flex items-center justify-between">
        <span className="text-[13px] font-bold tracking-[4px]" style={{ color: ACCENT }}>⚡ STATUS</span>
        <span className="text-[11px] tracking-wider text-[#6E86B0] truncate max-w-[55%] text-right">
          {name.toUpperCase()}
        </span>
      </div>
      <div className="my-3 h-px" style={{ backgroundColor: 'rgba(91,225,255,0.25)' }} />
      <div className="flex items-baseline gap-3">
        <span className="text-2xl font-extrabold text-[#CFE8FF]">Lv. {stats.level}</span>
        <span className="text-[13px] font-bold" style={{ color: ACCENT }}>{stats.title} ★</span>
      </div>
      <div className="mt-2 flex items-center gap-2">
        <span className="text-[10px] tracking-wider text-[#6E86B0]">EXP</span>
        <div className="flex-1 h-1.5 rounded-full overflow-hidden" style={{ backgroundColor: 'rgba(91,225,255,0.14)' }}>
          <div className="h-full" style={{ width: `${pct}%`, backgroundColor: ACCENT }} />
        </div>
        <span className="text-[10px] text-[#6E86B0]">{pct}%</span>
      </div>
      <div className="mt-4 space-y-2.5">
        {stats.stats.map((s) => (
          <div key={s.code} className="flex items-center gap-2">
            <span className="w-9 text-xs font-bold" style={{ color: ACCENT }}>{s.code}</span>
            <span className="w-16 text-[10px] text-[#6E86B0]">{s.label}</span>
            <SegBar fill={s.fill} />
            <span className="w-10 text-right text-[11px] font-bold text-[#CFE8FF]">{s.display}</span>
          </div>
        ))}
      </div>
      <div className="mt-3 text-[9px] text-[#6E86B0]">// stats derived from live activity</div>
    </div>
  );
}
