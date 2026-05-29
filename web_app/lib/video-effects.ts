// Playback-time effects mirroring flutter_app's composeVideo helper.
// Used by the post-stream feed video player to apply per-video filter,
// zoom-at-point, blur, vignette, text overlays, and emoji stickers.

import type { ZoomMarker } from '@/lib/types';

/// Maps Flutter's filter IDs (persisted on videos/{id}.filterId) to the
/// closest CSS `filter` string equivalent. Approximates the Flutter
/// ColorMatrix presets — not pixel-perfect, but visually consistent.
export function filterCssFor(filterId: string | undefined): string {
  switch (filterId) {
    case 'warm':
      return 'sepia(0.25) brightness(1.08) saturate(1.20)';
    case 'cool':
      return 'hue-rotate(20deg) saturate(1.20) brightness(1.04)';
    case 'noir':
      return 'grayscale(1) contrast(1.25) brightness(0.96)';
    case 'cinema':
      return 'contrast(1.10) saturate(0.85) brightness(0.95)';
    case 'beauty':
      // Beauty has no colour matrix on Flutter (it uses Agora native skin
      // smoothing during the broadcast, which can't be replayed). Render
      // as Normal here — same behaviour as the Flutter playback path.
      return 'none';
    case 'none':
    case undefined:
    case null as unknown as string:
      return 'none';
    default:
      return 'none';
  }
}

/// Piecewise-linear zoom curve evaluated against a list of zoom markers.
/// Returns the scale from the FIRST marker whose window contains the
/// current position. Returns 1.0 if no marker covers the position. Markers
/// are expected to be sorted by timeMs (matches Flutter's persisted order).
export function scaleAtPosition(
  positionMs: number,
  zooms: ZoomMarker[] | undefined,
): number {
  if (!zooms || zooms.length === 0) return 1.0;
  for (const z of zooms) {
    if (z.scale <= 1.0) continue;
    const delta = positionMs - z.timeMs;
    if (delta < 0 || delta > z.durationMs) continue;
    const t = delta / z.durationMs;
    if (t < 0.3) return 1.0 + (z.scale - 1.0) * (t / 0.3);
    if (t > 0.7) return 1.0 + (z.scale - 1.0) * ((1.0 - t) / 0.3);
    return z.scale;
  }
  return 1.0;
}
