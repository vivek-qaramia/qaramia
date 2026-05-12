const THUMB = 32; // 32×32 thumbnail — fast to compute and compare

export function captureFingerprint(videoEl: HTMLVideoElement): Uint8ClampedArray | null {
  if (!videoEl.videoWidth) return null;
  const canvas = document.createElement('canvas');
  canvas.width = THUMB;
  canvas.height = THUMB;
  canvas.getContext('2d')!.drawImage(videoEl, 0, 0, THUMB, THUMB);
  return canvas.getContext('2d')!.getImageData(0, 0, THUMB, THUMB).data;
}

/** Returns average per-channel pixel difference (0–255). Values below ~15 mean "same scene". */
export function fingerprintDiff(a: Uint8ClampedArray, b: Uint8ClampedArray): number {
  let total = 0;
  for (let i = 0; i < a.length; i += 4) {
    total += Math.abs(a[i] - b[i]);         // R
    total += Math.abs(a[i + 1] - b[i + 1]); // G
    total += Math.abs(a[i + 2] - b[i + 2]); // B
  }
  return total / (a.length / 4 * 3); // avg channel diff per pixel
}

export const SCENE_CHANGE_THRESHOLD = 15; // out of 255
