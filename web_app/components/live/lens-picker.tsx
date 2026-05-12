'use client';
import type { LensInfo } from '@/lib/snap/snap-lens-pipeline';

interface Props {
  lenses: LensInfo[];
  selected: string | null;
  onSelect: (id: string | null) => void;
  loading?: boolean;
}

const PLACEHOLDER_COLORS = [
  'from-violet-500 to-purple-700',
  'from-pink-400 to-rose-600',
  'from-cyan-400 to-blue-600',
  'from-amber-400 to-orange-600',
  'from-emerald-400 to-teal-600',
  'from-fuchsia-400 to-pink-600',
  'from-sky-400 to-indigo-600',
  'from-lime-400 to-green-600',
];

export function LensPicker({ lenses, selected, onSelect, loading }: Props) {
  return (
    <div>
      <p className="text-xs text-white/40 uppercase tracking-wider mb-2 font-semibold">AR Lens</p>

      {loading ? (
        <div className="flex items-center gap-2 text-white/40 text-xs py-2">
          <div className="w-4 h-4 border-2 border-[#FFFC00] border-t-transparent rounded-full animate-spin" />
          Loading lenses…
        </div>
      ) : (
        <div className="flex gap-2 overflow-x-auto pb-1">
          {/* None / off */}
          <button
            onClick={() => onSelect(null)}
            className="flex flex-col items-center gap-1 shrink-0"
          >
            <div
              className={`w-14 h-14 rounded-xl bg-zinc-800 flex items-center justify-center text-xl transition ring-2 ${
                selected === null ? 'ring-[#FFFC00]' : 'ring-transparent hover:ring-white/30'
              }`}
            >
              ✕
            </div>
            <span className={`text-[10px] font-medium ${selected === null ? 'text-[#FFFC00]' : 'text-white/50'}`}>
              None
            </span>
          </button>

          {lenses.map((lens, i) => (
            <button
              key={lens.id}
              onClick={() => onSelect(lens.id)}
              className="flex flex-col items-center gap-1 shrink-0"
            >
              <div
                className={`w-14 h-14 rounded-xl overflow-hidden transition ring-2 ${
                  selected === lens.id ? 'ring-[#FFFC00]' : 'ring-transparent hover:ring-white/30'
                }`}
              >
                {lens.thumbnailUrl ? (
                  <img src={lens.thumbnailUrl} alt={lens.name} className="w-full h-full object-cover" />
                ) : (
                  <div className={`w-full h-full bg-gradient-to-br ${PLACEHOLDER_COLORS[i % PLACEHOLDER_COLORS.length]}`} />
                )}
              </div>
              <span className={`text-[10px] font-medium max-w-[56px] truncate ${selected === lens.id ? 'text-[#FFFC00]' : 'text-white/50'}`}>
                {lens.name}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
