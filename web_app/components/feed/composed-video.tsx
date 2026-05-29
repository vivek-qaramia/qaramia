'use client';
import { useEffect, useRef, useState } from 'react';
import type { Video } from '@/lib/types';
import { filterCssFor, scaleAtPosition } from '@/lib/video-effects';

/// Full-screen-friendly video player that applies every post-stream editor
/// effect at playback time — colour filter, zoom-at-point, blur, vignette,
/// text overlays, emoji stickers — mirroring flutter_app's composeVideo
/// path so videos published from either client look identical.
///
/// Effects are stacked the same way they are on Flutter (innermost out):
///   <video>
///     → vignette (radial-gradient overlay over the frame)
///     → blur (CSS filter blur)
///     → colour filter (CSS filter string)
///     → zoom (CSS transform scale, position-driven)
///     → text + sticker overlays on top (kept crisp, never zoomed/blurred)
export function ComposedVideo({ video, className = '' }: { video: Video; className?: string }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [positionMs, setPositionMs] = useState(0);

  // Listen to the video element's timeupdate so position-dependent effects
  // (zoom-at-point, text/sticker visibility) re-render as playback advances.
  // timeupdate fires roughly 4Hz which is plenty for these layered effects.
  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;
    const tick = () => setPositionMs(el.currentTime * 1000);
    el.addEventListener('timeupdate', tick);
    return () => el.removeEventListener('timeupdate', tick);
  }, []);

  const scale = scaleAtPosition(positionMs, video.zooms);
  const filterCss = filterCssFor(video.filterId);
  const blurPx = video.blurAmount ?? 0;
  const vignette = video.vignetteIntensity ?? 0;

  // Combine the CSS-filter string with the blur. Order matters visually:
  // blur is applied AFTER the colour grade so the colour grade lands on
  // sharp pixels, then the whole thing gets softened. Matches Flutter's
  // ImageFiltered-around-ColorFiltered ordering.
  const combinedFilter = [
    filterCss === 'none' ? '' : filterCss,
    blurPx > 0 ? `blur(${blurPx}px)` : '',
  ]
    .filter(Boolean)
    .join(' ') || 'none';

  const visibleTexts = (video.textOverlays ?? []).filter(
    (t) => positionMs >= t.startMs && positionMs <= t.endMs,
  );
  const visibleStickers = (video.stickers ?? []).filter(
    (s) => positionMs >= s.startMs && positionMs <= s.endMs,
  );

  return (
    <div className={`relative w-full h-full overflow-hidden bg-black ${className}`}>
      {/* Effects scope: only the video + vignette + colour-filter + zoom
          rotate together. Text/stickers sit OUTSIDE this so they stay crisp. */}
      <div
        className="absolute inset-0"
        style={{ transform: `scale(${scale})`, transition: 'transform 50ms linear' }}
      >
        <video
          ref={videoRef}
          src={video.videoUrl}
          autoPlay
          loop
          playsInline
          controls
          className="w-full h-full object-contain"
          style={{ filter: combinedFilter }}
        />
        {vignette > 0 && (
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              background: `radial-gradient(circle at center, transparent 55%, rgba(0,0,0,${vignette}) 100%)`,
            }}
          />
        )}
      </div>

      {/* Crisp overlays — outside the zoom/blur scope. */}
      {visibleTexts.map((t, i) => (
        <div
          key={`t-${i}`}
          className="absolute inset-0 flex items-center justify-center pointer-events-none px-6"
        >
          <p
            className="text-white text-2xl md:text-3xl font-extrabold text-center"
            style={{ textShadow: '0 1.5px 4px rgba(0,0,0,0.85)' }}
          >
            {t.text}
          </p>
        </div>
      ))}
      {visibleStickers.map((s, i) => (
        <div
          key={`s-${i}`}
          className="absolute inset-0 flex items-center justify-center pointer-events-none"
        >
          <span className="text-7xl md:text-8xl">{s.emoji}</span>
        </div>
      ))}
    </div>
  );
}
