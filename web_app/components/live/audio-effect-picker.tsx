'use client';
import { AUDIO_EFFECTS } from '@/lib/audio/audio-effects';

interface Props {
  selected: string;
  onSelect: (id: string) => void;
}

export function AudioEffectPicker({ selected, onSelect }: Props) {
  return (
    <div>
      <p className="text-xs text-white/40 uppercase tracking-wider mb-2 font-semibold">Voice Effect</p>
      <div className="flex gap-2 overflow-x-auto pb-1">
        {AUDIO_EFFECTS.map((e) => (
          <button
            key={e.id}
            onClick={() => onSelect(e.id)}
            className={`flex flex-col items-center gap-1 shrink-0 px-3 py-2 rounded-xl transition border ${
              selected === e.id
                ? 'border-[#FFD166] bg-[#FFD166]/10'
                : 'border-white/10 bg-white/5 hover:bg-white/10'
            }`}
          >
            <span className="text-xl">{e.emoji}</span>
            <span className={`text-[10px] font-medium ${selected === e.id ? 'text-[#FFD166]' : 'text-white/50'}`}>
              {e.name}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
