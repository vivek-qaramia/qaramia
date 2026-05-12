'use client';
import { ROOM_BACKGROUNDS, RoomBackground } from '@/lib/compositing/room-backgrounds';

interface Props {
  selected: string;
  onSelect: (bg: RoomBackground) => void;
}

export function RoomPicker({ selected, onSelect }: Props) {
  return (
    <div>
      <p className="text-xs text-white/40 uppercase tracking-wider mb-2 font-semibold">Room Background</p>
      <div className="grid grid-cols-2 gap-2">
        {ROOM_BACKGROUNDS.map((bg) => (
          <button
            key={bg.id}
            onClick={() => onSelect(bg)}
            className={`relative rounded-xl overflow-hidden h-16 transition ring-2 ${
              selected === bg.id ? 'ring-[#FF7043]' : 'ring-transparent hover:ring-white/30'
            }`}
          >
            <div className="absolute inset-0" style={{ background: bg.cssPreview }} />
            <div className="absolute inset-0 bg-black/30 flex items-end p-1.5">
              <span className="text-white text-[11px] font-semibold leading-tight">{bg.name}</span>
            </div>
            {selected === bg.id && (
              <div className="absolute top-1.5 right-1.5 w-4 h-4 bg-[#FF7043] rounded-full flex items-center justify-center">
                <svg className="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}
