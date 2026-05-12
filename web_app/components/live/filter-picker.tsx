'use client';
import { VIDEO_FILTERS } from '@/lib/compositing/video-filters';

interface Props {
  selected: string;
  onSelect: (id: string) => void;
}

const FILTER_BG: Record<string, string> = {
  none:        'bg-gradient-to-br from-zinc-300 to-zinc-500',
  bright_light:'bg-gradient-to-br from-yellow-100 to-amber-300',
  beauty:      'bg-gradient-to-br from-pink-100 to-rose-300',
  glam:        'bg-gradient-to-br from-pink-300 to-fuchsia-500',
  skin:        'bg-gradient-to-br from-orange-100 to-amber-300',
  cinematic:   'bg-gradient-to-br from-teal-900 to-orange-900',
  noir:        'bg-gradient-to-br from-zinc-900 to-zinc-600',
  moody:       'bg-gradient-to-br from-slate-800 to-purple-950',
  film:        'bg-gradient-to-br from-amber-900 to-stone-700',
  tokyo:       'bg-gradient-to-br from-blue-800 to-cyan-600',
  vivid:       'bg-gradient-to-br from-purple-400 to-pink-500',
  cool:        'bg-gradient-to-br from-cyan-400 to-blue-600',
  warm:        'bg-gradient-to-br from-orange-300 to-amber-600',
  forest:      'bg-gradient-to-br from-green-700 to-emerald-900',
  golden:      'bg-gradient-to-br from-yellow-400 to-amber-700',
};

export function FilterPicker({ selected, onSelect }: Props) {
  return (
    <div>
      <p className="text-xs text-white/40 uppercase tracking-wider mb-2 font-semibold">Filter</p>
      <div className="flex gap-2 overflow-x-auto pb-1">
        {VIDEO_FILTERS.map((f) => (
          <button
            key={f.id}
            onClick={() => onSelect(f.id)}
            className="flex flex-col items-center gap-1 shrink-0"
          >
            <div
              className={`w-14 h-14 rounded-xl ${FILTER_BG[f.id] ?? 'bg-zinc-700'} transition ring-2 ${
                selected === f.id ? 'ring-[#FF7043]' : 'ring-transparent hover:ring-white/30'
              }`}
            />
            <span className={`text-[10px] font-medium ${selected === f.id ? 'text-[#FF7043]' : 'text-white/50'}`}>
              {f.name}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
