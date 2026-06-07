'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { ZoomMarker, TextOverlay, StickerOverlay } from '@/lib/types';
import { filterCssFor, scaleAtPosition } from '@/lib/video-effects';
import { publishClip, type ClipAuthor } from '@/lib/publish-clip';

// Playback filter IDs the feed renderer (filterCssFor) understands — mirrors
// the Flutter post-stream editor's filter set.
const FILTERS = [
  { id: 'none', name: 'Normal' },
  { id: 'warm', name: 'Warm' },
  { id: 'cool', name: 'Cool' },
  { id: 'noir', name: 'Noir' },
  { id: 'cinema', name: 'Cinema' },
];
const STICKER_CHOICES = ['🔥', '❤️', '😂', '😮', '🎉', '👑', '💎', '⭐'];
const ZOOM_MS = 2000;
const OVERLAY_MS = 3000;

const fmt = (ms: number) => {
  const s = Math.max(0, Math.round(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

/**
 * Web post-stream editor — mirrors the Flutter PostStreamEditorScreen.
 * Edits the just-recorded clip with trim + colour filter + zoom + blur +
 * vignette + text overlays + emoji stickers + caption, all stored as metadata
 * (ComposedVideo applies them at playback), then publishes to the feed.
 */
export function PostStreamEditor({
  blob,
  author,
  defaultCaption,
  onClose,
}: {
  blob: Blob;
  author: ClipAuthor;
  defaultCaption: string;
  onClose: (published: boolean) => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const url = useMemo(() => URL.createObjectURL(blob), [blob]);

  const [duration, setDuration] = useState(0);
  const [pos, setPos] = useState(0);
  const [filterId, setFilterId] = useState('none');
  const [blur, setBlur] = useState(0);
  const [vignette, setVignette] = useState(0);
  const [zooms, setZooms] = useState<ZoomMarker[]>([]);
  const [texts, setTexts] = useState<TextOverlay[]>([]);
  const [stickers, setStickers] = useState<StickerOverlay[]>([]);
  const [textInput, setTextInput] = useState('');
  const [caption, setCaption] = useState(defaultCaption);
  const [trimStart, setTrimStart] = useState(0);
  const [trimEnd, setTrimEnd] = useState(0);
  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => () => URL.revokeObjectURL(url), [url]);

  // MediaRecorder .webm files report duration: Infinity until the browser is
  // forced to scan to the end. Detect the real duration once, then trim works.
  const [durationReady, setDurationReady] = useState(false);
  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;
    const applyDuration = () => {
      if (isFinite(el.duration) && el.duration > 0) {
        const ms = el.duration * 1000;
        setDuration(ms);
        setTrimEnd(ms);
        setDurationReady(true);
        return true;
      }
      return false;
    };
    const onMeta = () => {
      if (applyDuration()) return;
      // Force the browser to compute the real duration, then reset.
      const onDur = () => {
        if (applyDuration()) {
          el.removeEventListener('durationchange', onDur);
          el.currentTime = 0;
        }
      };
      el.addEventListener('durationchange', onDur);
      el.currentTime = 1e7;
    };
    if (el.readyState >= 1) onMeta();
    el.addEventListener('loadedmetadata', onMeta);
    return () => el.removeEventListener('loadedmetadata', onMeta);
  }, []);

  // Track playhead + enforce the trim window during playback.
  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;
    const onTime = () => {
      if (durationReady && trimEnd > 0 && el.currentTime * 1000 >= trimEnd) {
        el.currentTime = trimStart / 1000;
      }
      setPos(el.currentTime * 1000);
    };
    el.addEventListener('timeupdate', onTime);
    el.addEventListener('seeked', onTime);
    return () => {
      el.removeEventListener('timeupdate', onTime);
      el.removeEventListener('seeked', onTime);
    };
  }, [trimStart, trimEnd, durationReady]);

  const scale = scaleAtPosition(pos, zooms);
  const filterCss = filterCssFor(filterId);
  const combinedFilter = [filterCss === 'none' ? '' : filterCss, blur > 0 ? `blur(${blur}px)` : '']
    .filter(Boolean).join(' ') || 'none';
  const visTexts = texts.filter((t) => pos >= t.startMs && pos <= t.endMs);
  const visStickers = stickers.filter((s) => pos >= s.startMs && pos <= s.endMs);

  const addZoom = () =>
    setZooms((z) => [...z, { timeMs: pos, scale: 1.6, durationMs: ZOOM_MS }].sort((a, b) => a.timeMs - b.timeMs));
  const addText = () => {
    if (!textInput.trim()) return;
    setTexts((t) => [...t, { text: textInput.trim(), startMs: pos, endMs: pos + OVERLAY_MS }].sort((a, b) => a.startMs - b.startMs));
    setTextInput('');
  };
  const addSticker = (emoji: string) =>
    setStickers((s) => [...s, { emoji, startMs: pos, endMs: pos + OVERLAY_MS }].sort((a, b) => a.startMs - b.startMs));

  const publish = async () => {
    setPublishing(true);
    setError(null);
    try {
      // Thumbnail is best-effort — never block publishing. toBlob throws a
      // SecurityError if the canvas is "tainted" (the recorded frames can
      // originate from a captureStream/WebGL source the browser flags as
      // cross-origin-unclean, e.g. the Room Mode compositor). Fall back to no
      // thumbnail in that case; the feed shows a placeholder, same as Flutter.
      let thumbBlob: Blob | null = null;
      try {
        const el = videoRef.current;
        if (el && el.videoWidth) {
          const c = document.createElement('canvas');
          c.width = el.videoWidth;
          c.height = el.videoHeight;
          c.getContext('2d')?.drawImage(el, 0, 0);
          thumbBlob = await new Promise<Blob | null>((r) => c.toBlob(r, 'image/jpeg', 0.8));
        }
      } catch (thumbErr) {
        console.warn('Thumbnail capture skipped (tainted canvas)', thumbErr);
      }
      await publishClip({
        videoBlob: blob,
        thumbBlob,
        author,
        caption: caption.trim() || 'Live clip',
        effects: {
          filterId,
          zooms,
          blurAmount: blur,
          vignetteIntensity: vignette,
          textOverlays: texts,
          stickers,
          trimStartMs: Math.round(trimStart),
          trimEndMs: Math.round(trimEnd),
        },
      });
      onClose(true);
    } catch (e) {
      console.error('Publish failed', e);
      setError('Failed to publish. Please try again.');
      setPublishing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black/95 flex flex-col md:flex-row overflow-auto">
      {/* Preview */}
      <div className="md:flex-1 flex items-center justify-center p-4 min-h-[40vh]">
        <div className="relative w-full max-w-sm aspect-[9/16] bg-black rounded-xl overflow-hidden">
          <div className="absolute inset-0" style={{ transform: `scale(${scale})`, transition: 'transform 50ms linear' }}>
            <video
              ref={videoRef}
              src={url}
              controls
              playsInline
              className="w-full h-full object-contain"
              style={{ filter: combinedFilter }}
            />
            {vignette > 0 && (
              <div className="absolute inset-0 pointer-events-none"
                style={{ background: `radial-gradient(circle at center, transparent 55%, rgba(0,0,0,${vignette}) 100%)` }} />
            )}
          </div>
          {visTexts.map((t, i) => (
            <div key={`t${i}`} className="absolute inset-0 flex items-center justify-center pointer-events-none px-6">
              <p className="text-white text-2xl font-extrabold text-center" style={{ textShadow: '0 1.5px 4px rgba(0,0,0,0.85)' }}>{t.text}</p>
            </div>
          ))}
          {visStickers.map((s, i) => (
            <div key={`s${i}`} className="absolute inset-0 flex items-center justify-center pointer-events-none">
              <span className="text-7xl">{s.emoji}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Controls */}
      <div className="md:w-96 shrink-0 bg-zinc-900 md:h-screen md:overflow-y-auto p-5 space-y-5">
        <h2 className="text-lg font-bold text-white">Edit clip</h2>

        {/* Trim */}
        <div className="space-y-1">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Trim · {fmt(trimStart)}–{fmt(trimEnd)}</label>
          <input type="range" min={0} max={duration || 1} value={trimStart}
            onChange={(e) => setTrimStart(Math.min(Number(e.target.value), trimEnd - 500))}
            className="w-full accent-[#FF7043]" />
          <input type="range" min={0} max={duration || 1} value={trimEnd}
            onChange={(e) => setTrimEnd(Math.max(Number(e.target.value), trimStart + 500))}
            className="w-full accent-[#FF7043]" />
          <p className="text-[11px] text-white/30">Playhead: {fmt(pos)} · scrub the video to position effects</p>
        </div>

        {/* Filter */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Filter</label>
          <div className="flex flex-wrap gap-2">
            {FILTERS.map((f) => (
              <button key={f.id} onClick={() => setFilterId(f.id)}
                className={`px-3 py-1.5 rounded-full text-xs font-semibold transition ${filterId === f.id ? 'bg-[#FF7043] text-white' : 'bg-white/10 text-white/60 hover:bg-white/20'}`}>
                {f.name}
              </button>
            ))}
          </div>
        </div>

        {/* Blur + Vignette */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Blur · {blur}px</label>
          <input type="range" min={0} max={8} step={0.5} value={blur} onChange={(e) => setBlur(Number(e.target.value))} className="w-full accent-[#FF7043]" />
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Vignette · {Math.round(vignette * 100)}%</label>
          <input type="range" min={0} max={0.8} step={0.05} value={vignette} onChange={(e) => setVignette(Number(e.target.value))} className="w-full accent-[#FF7043]" />
        </div>

        {/* Zoom */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Zoom · {zooms.length}</label>
            <button onClick={addZoom} className="text-xs font-semibold text-[#FFD166] hover:text-white">+ Add at {fmt(pos)}</button>
          </div>
          {zooms.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {zooms.map((z, i) => (
                <button key={i} onClick={() => setZooms((arr) => arr.filter((_, j) => j !== i))}
                  className="px-2 py-1 rounded bg-white/10 text-[11px] text-white/70 hover:bg-red-500/30">{fmt(z.timeMs)} ✕</button>
              ))}
            </div>
          )}
        </div>

        {/* Text */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Text · {texts.length}</label>
          <div className="flex gap-2">
            <input value={textInput} onChange={(e) => setTextInput(e.target.value)} placeholder="Overlay text…"
              className="flex-1 bg-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder-white/30 focus:outline-none" />
            <button onClick={addText} className="px-3 rounded-lg bg-white/10 text-white/70 text-sm hover:bg-white/20">Add</button>
          </div>
          {texts.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {texts.map((t, i) => (
                <button key={i} onClick={() => setTexts((arr) => arr.filter((_, j) => j !== i))}
                  className="px-2 py-1 rounded bg-white/10 text-[11px] text-white/70 hover:bg-red-500/30">“{t.text}” ✕</button>
              ))}
            </div>
          )}
        </div>

        {/* Stickers */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Stickers · {stickers.length}</label>
          <div className="flex flex-wrap gap-1.5">
            {STICKER_CHOICES.map((e) => (
              <button key={e} onClick={() => addSticker(e)} className="text-xl hover:scale-110 transition">{e}</button>
            ))}
          </div>
          {stickers.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {stickers.map((s, i) => (
                <button key={i} onClick={() => setStickers((arr) => arr.filter((_, j) => j !== i))}
                  className="px-2 py-1 rounded bg-white/10 text-[11px] text-white/70 hover:bg-red-500/30">{s.emoji} {fmt(s.startMs)} ✕</button>
              ))}
            </div>
          )}
        </div>

        {/* Caption */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-white/50 uppercase tracking-wider">Caption</label>
          <input value={caption} onChange={(e) => setCaption(e.target.value)} maxLength={150}
            className="w-full bg-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder-white/30 focus:outline-none" />
        </div>

        {error && <p className="text-xs text-red-400">{error}</p>}

        <div className="flex gap-3 pt-2">
          <button onClick={() => onClose(false)} disabled={publishing}
            className="flex-1 py-3 rounded-xl border border-white/15 text-white/70 hover:text-white text-sm font-semibold disabled:opacity-50">
            Discard
          </button>
          <button onClick={publish} disabled={publishing}
            className="flex-1 py-3 rounded-xl bg-[#FF7043] hover:bg-[#e55a2b] text-white text-sm font-bold disabled:opacity-50">
            {publishing ? 'Publishing…' : 'Publish'}
          </button>
        </div>
      </div>
    </div>
  );
}
