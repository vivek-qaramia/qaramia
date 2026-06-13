// In-browser video compression + hard-trim, the web counterpart of the Flutter
// VideoTrimService. Uses ffmpeg.wasm with the SAME libx264 flags as mobile so
// web and mobile feed clips look identical, and so the recorded clip is shrunk
// to a small mp4 BEFORE upload instead of sending the raw webm and leaning on
// the server transcode.
//
// We deliberately use the single-threaded @ffmpeg/core build: the multi-thread
// build needs SharedArrayBuffer, which requires cross-origin isolation
// (COOP/COEP) headers — and enabling those would break Agora's virtual-
// background extension and Firebase, which load cross-origin resources. Single
// thread is slower but needs no headers and is fine for short clips.

import { FFmpeg } from '@ffmpeg/ffmpeg';
import { fetchFile, toBlobURL } from '@ffmpeg/util';

// Core is self-hosted under /public/ffmpeg (copied from node_modules by
// scripts/copy-ffmpeg-core.mjs on install/build) — no runtime CDN dependency.
// Still wrapped via toBlobURL so the ffmpeg worker can load it same-origin.
const CORE_BASE = '/ffmpeg';

let _ffmpeg: FFmpeg | null = null;
let _loadPromise: Promise<FFmpeg> | null = null;

/** Lazily create + load ffmpeg.wasm once, reusing it across publishes. */
async function getFfmpeg(): Promise<FFmpeg> {
  if (_ffmpeg) return _ffmpeg;
  if (!_loadPromise) {
    _loadPromise = (async () => {
      const ff = new FFmpeg();
      await ff.load({
        coreURL: await toBlobURL(`${CORE_BASE}/ffmpeg-core.js`, 'text/javascript'),
        wasmURL: await toBlobURL(`${CORE_BASE}/ffmpeg-core.wasm`, 'application/wasm'),
      });
      _ffmpeg = ff;
      return ff;
    })();
  }
  return _loadPromise;
}

function blobFromFileData(data: Uint8Array | string, type: string): Blob {
  // readFile returns a Uint8Array for binary; copy into a fresh, non-shared
  // ArrayBuffer-backed view so it's a valid BlobPart regardless of byte offset.
  const copy = new Uint8Array(data as Uint8Array);
  return new Blob([copy], { type });
}

export interface TranscodeOpts {
  /** Trim window start, ms. */
  startMs?: number;
  /** Trim window end, ms. */
  endMs?: number;
  /** Full clip duration, ms — used to decide whether the window actually narrows. */
  durationMs?: number;
  /** 0–1 encode progress for the video pass. */
  onProgress?: (ratio: number) => void;
}

export interface TranscodeResult {
  /** Compressed (and optionally trimmed) mp4. */
  video: Blob;
  /** First-frame JPEG, or null if extraction failed. */
  thumbnail: Blob | null;
}

/**
 * Compress + optionally hard-trim a recorded clip to a small mp4 and extract a
 * thumbnail, all in the browser. Mirrors VideoTrimService.trim / .compress and
 * .generateThumbnail. The trim is only applied when the window actually narrows
 * the clip (matching the Flutter `isTrimmed` check).
 */
export async function transcodeForUpload(
  input: Blob,
  opts: TranscodeOpts = {},
): Promise<TranscodeResult> {
  const { startMs, endMs, durationMs, onProgress } = opts;
  const ff = await getFfmpeg();

  const inName = 'input';
  const outName = 'out.mp4';
  const thumbName = 'thumb.jpg';
  await ff.writeFile(inName, await fetchFile(input));

  const trimmed =
    startMs != null &&
    endMs != null &&
    (startMs > 50 || (durationMs != null && endMs < durationMs - 50));

  // -ss/-to AFTER -i = frame-accurate cut (matches the Flutter trim). Same
  // encode settings as mobile: veryfast/crf 26, faststart, AAC 128k.
  const args: string[] = ['-i', inName];
  if (trimmed) {
    args.push('-ss', (startMs! / 1000).toFixed(3), '-to', (endMs! / 1000).toFixed(3));
  }
  args.push(
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '26',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    '-c:a', 'aac', '-b:a', '128k',
    outName,
  );

  const onProg = onProgress
    ? ({ progress }: { progress: number }) => onProgress(Math.max(0, Math.min(1, progress)))
    : null;
  if (onProg) ff.on('progress', onProg);
  try {
    await ff.exec(args);
  } finally {
    if (onProg) ff.off('progress', onProg);
  }

  const video = blobFromFileData(await ff.readFile(outName) as Uint8Array, 'video/mp4');

  // Best-effort thumbnail from the encoded mp4 (more reliable than a browser
  // canvas, which a tainted Room Mode source can block). 0.5s skips a possibly
  // black first frame, same as mobile.
  let thumbnail: Blob | null = null;
  try {
    await ff.exec(['-ss', '0.5', '-i', outName, '-frames:v', '1', '-q:v', '3', thumbName]);
    thumbnail = blobFromFileData(await ff.readFile(thumbName) as Uint8Array, 'image/jpeg');
  } catch {
    /* leave thumbnail null — the feed falls back to a placeholder */
  }

  for (const f of [inName, outName, thumbName]) {
    try { await ff.deleteFile(f); } catch { /* not written */ }
  }
  return { video, thumbnail };
}
