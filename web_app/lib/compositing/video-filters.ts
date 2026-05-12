export interface VideoFilter {
  id: string;
  name: string;
  css: string;
  postProcess?: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

function addGrain(ctx: CanvasRenderingContext2D, w: number, h: number, amount = 18) {
  const imageData = ctx.getImageData(0, 0, w, h);
  const d = imageData.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (Math.random() - 0.5) * amount;
    d[i] += n; d[i + 1] += n; d[i + 2] += n;
  }
  ctx.putImageData(imageData, 0, 0);
}

function addVignette(ctx: CanvasRenderingContext2D, w: number, h: number, strength = 0.55) {
  const grad = ctx.createRadialGradient(w / 2, h / 2, h * 0.25, w / 2, h / 2, h * 0.85);
  grad.addColorStop(0, 'rgba(0,0,0,0)');
  grad.addColorStop(1, `rgba(0,0,0,${strength})`);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, h);
}

function addColorOverlay(ctx: CanvasRenderingContext2D, w: number, h: number, color: string) {
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, w, h);
}

export const VIDEO_FILTERS: VideoFilter[] = [
  // ── Natural ──────────────────────────────────────────────────────────────────
  { id: 'none', name: 'Normal', css: 'none' },

  // ── Beauty / Portrait ─────────────────────────────────────────────────────
  {
    id: 'bright_light',
    name: 'Bright',
    css: 'brightness(1.35) contrast(1.05) saturate(1.05)',
  },
  {
    id: 'beauty',
    name: 'Beauty',
    css: 'brightness(1.15) contrast(0.88) saturate(0.92) blur(0.4px)',
  },
  {
    id: 'glam',
    name: 'Glam',
    css: 'brightness(1.2) saturate(1.15) sepia(0.12) contrast(1.05)',
    postProcess: (ctx, w, h) => addColorOverlay(ctx, w, h, 'rgba(255,180,200,0.05)'),
  },
  {
    id: 'skin',
    name: 'Skin',
    css: 'brightness(1.12) saturate(1.1) sepia(0.08) blur(0.3px)',
    postProcess: (ctx, w, h) => addColorOverlay(ctx, w, h, 'rgba(255,210,180,0.06)'),
  },

  // ── Cinematic / Mood ──────────────────────────────────────────────────────
  {
    id: 'cinematic',
    name: 'Cinema',
    css: 'contrast(1.12) saturate(0.82) brightness(0.95)',
    postProcess: (ctx, w, h) => {
      // Teal shadows, orange highlights colour grade
      addColorOverlay(ctx, w, h, 'rgba(0,60,80,0.08)');
      addVignette(ctx, w, h, 0.5);
    },
  },
  {
    id: 'noir',
    name: 'Noir',
    css: 'grayscale(1) contrast(1.3) brightness(0.95)',
    postProcess: (ctx, w, h) => addVignette(ctx, w, h, 0.65),
  },
  {
    id: 'moody',
    name: 'Moody',
    css: 'brightness(0.82) contrast(1.12) saturate(0.55) sepia(0.08)',
    postProcess: (ctx, w, h) => {
      addColorOverlay(ctx, w, h, 'rgba(20,10,40,0.10)');
      addVignette(ctx, w, h, 0.5);
    },
  },
  {
    id: 'film',
    name: 'Film',
    css: 'sepia(0.28) contrast(0.92) brightness(0.94) saturate(0.85)',
    postProcess: (ctx, w, h) => {
      addColorOverlay(ctx, w, h, 'rgba(255,220,180,0.05)');
      addGrain(ctx, w, h, 14);
      addVignette(ctx, w, h, 0.45);
    },
  },
  {
    id: 'tokyo',
    name: 'Tokyo',
    css: 'hue-rotate(195deg) saturate(1.3) brightness(1.05) contrast(1.08)',
    postProcess: (ctx, w, h) => addVignette(ctx, w, h, 0.4),
  },

  // ── Colour ────────────────────────────────────────────────────────────────
  {
    id: 'vivid',
    name: 'Vivid',
    css: 'saturate(1.7) contrast(1.1) brightness(1.05)',
  },
  {
    id: 'cool',
    name: 'Cool',
    css: 'hue-rotate(18deg) saturate(1.25) brightness(1.05)',
  },
  {
    id: 'warm',
    name: 'Warm',
    css: 'sepia(0.28) brightness(1.12) saturate(1.35)',
  },
  {
    id: 'forest',
    name: 'Forest',
    css: 'hue-rotate(55deg) saturate(1.4) brightness(0.95) contrast(1.05)',
    postProcess: (ctx, w, h) => addColorOverlay(ctx, w, h, 'rgba(0,40,10,0.06)'),
  },
  {
    id: 'golden',
    name: 'Golden',
    css: 'sepia(0.42) brightness(1.18) saturate(1.4) contrast(1.05)',
    postProcess: (ctx, w, h) => addColorOverlay(ctx, w, h, 'rgba(255,200,80,0.06)'),
  },
];
