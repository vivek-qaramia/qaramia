'use client';
import { useCaptions } from '@/hooks/use-captions';

export function CaptionOverlay({ streamId, enabled }: { streamId: string; enabled: boolean }) {
  const { caption, stale } = useCaptions(streamId);

  if (!enabled || !caption?.text) return null;

  return (
    <div className="pointer-events-none absolute bottom-20 inset-x-0 flex justify-center z-10 px-4">
      <div
        className={`max-w-3xl px-4 py-2 rounded-lg bg-black/75 backdrop-blur-sm text-center transition-opacity duration-500 ${
          stale ? 'opacity-30' : 'opacity-100'
        }`}
      >
        <p className="text-white text-base sm:text-lg leading-snug font-medium drop-shadow">
          {caption.text}
        </p>
      </div>
    </div>
  );
}
