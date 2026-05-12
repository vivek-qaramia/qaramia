export interface RoomBackground {
  id: string;
  name: string;
  cssPreview: string;
  draw: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

// ─── Studio Black ─────────────────────────────────────────────────────────────
// Clean broadcast studio dark — Netflix / late-night TV style
function drawStudioBlack(ctx: CanvasRenderingContext2D, w: number, h: number) {
  // Base: near-black radial gradient with subtle center lift
  const base = ctx.createRadialGradient(w * 0.5, h * 0.42, 0, w * 0.5, h * 0.5, w * 0.75);
  base.addColorStop(0, '#1c1c1e');
  base.addColorStop(0.6, '#111113');
  base.addColorStop(1, '#09090b');
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, w, h);

  // Subtle warm key-light bloom top-left (as if a softbox is just off-frame)
  const key = ctx.createRadialGradient(w * 0.18, 0, 0, w * 0.18, 0, w * 0.65);
  key.addColorStop(0, 'rgba(255,230,190,0.07)');
  key.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = key;
  ctx.fillRect(0, 0, w, h);

  // Floor: dark glossy surface with very subtle reflection gradient
  const floor = h * 0.74;
  const floorGrad = ctx.createLinearGradient(0, floor, 0, h);
  floorGrad.addColorStop(0, '#141416');
  floorGrad.addColorStop(1, '#0a0a0b');
  ctx.fillStyle = floorGrad;
  ctx.fillRect(0, floor, w, h - floor);

  // Floor/wall seam: faint warm glow strip
  const seam = ctx.createLinearGradient(0, floor - 1, w, floor - 1);
  seam.addColorStop(0, 'rgba(255,200,120,0)');
  seam.addColorStop(0.25, 'rgba(255,200,120,0.18)');
  seam.addColorStop(0.75, 'rgba(255,200,120,0.18)');
  seam.addColorStop(1, 'rgba(255,200,120,0)');
  ctx.fillStyle = seam;
  ctx.fillRect(0, floor - 1, w, 2);

  // Floor reflection: faint vertical glow under the seam
  const refl = ctx.createLinearGradient(0, floor, 0, floor + 100);
  refl.addColorStop(0, 'rgba(255,200,120,0.06)');
  refl.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = refl;
  ctx.fillRect(0, floor, w, 100);
}

// ─── Deep Ocean ───────────────────────────────────────────────────────────────
// Rich midnight blue — broadcast news / corporate professional
function drawDeepOcean(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const base = ctx.createLinearGradient(0, 0, w * 0.6, h);
  base.addColorStop(0, '#0d1b3e');
  base.addColorStop(0.5, '#0a1628');
  base.addColorStop(1, '#060e1c');
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, w, h);

  // Radial glow behind subject position
  const glow = ctx.createRadialGradient(w * 0.5, h * 0.45, 0, w * 0.5, h * 0.45, w * 0.5);
  glow.addColorStop(0, 'rgba(40,90,210,0.22)');
  glow.addColorStop(0.5, 'rgba(20,55,150,0.10)');
  glow.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, w, h);

  // Top cyan accent bar
  const bar = ctx.createLinearGradient(0, 0, w, 0);
  bar.addColorStop(0, 'rgba(0,200,255,0)');
  bar.addColorStop(0.15, 'rgba(0,200,255,0.7)');
  bar.addColorStop(0.85, 'rgba(0,200,255,0.7)');
  bar.addColorStop(1, 'rgba(0,200,255,0)');
  ctx.fillStyle = bar;
  ctx.fillRect(0, 0, w, 3);

  // Floor
  const floor = h * 0.74;
  const floorGrad = ctx.createLinearGradient(0, floor, 0, h);
  floorGrad.addColorStop(0, '#0c1830');
  floorGrad.addColorStop(1, '#050c18');
  ctx.fillStyle = floorGrad;
  ctx.fillRect(0, floor, w, h - floor);

  // Floor edge glow (cyan)
  const edgeGrad = ctx.createLinearGradient(0, floor, w, floor);
  edgeGrad.addColorStop(0, 'rgba(0,200,255,0)');
  edgeGrad.addColorStop(0.2, 'rgba(0,200,255,0.4)');
  edgeGrad.addColorStop(0.8, 'rgba(0,200,255,0.4)');
  edgeGrad.addColorStop(1, 'rgba(0,200,255,0)');
  ctx.fillStyle = edgeGrad;
  ctx.fillRect(0, floor - 1, w, 2);

  const refl = ctx.createLinearGradient(0, floor, 0, floor + 90);
  refl.addColorStop(0, 'rgba(0,150,220,0.12)');
  refl.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = refl;
  ctx.fillRect(0, floor, w, 90);
}

// ─── Neon Noir ────────────────────────────────────────────────────────────────
// Gaming / streaming aesthetic — dark with controlled neon accents
function drawNeonNoir(ctx: CanvasRenderingContext2D, w: number, h: number) {
  // Base: very dark, almost black purple-black
  ctx.fillStyle = '#08060f';
  ctx.fillRect(0, 0, w, h);

  // Left: deep violet bloom
  const left = ctx.createRadialGradient(0, h * 0.5, 0, 0, h * 0.5, w * 0.55);
  left.addColorStop(0, 'rgba(110,30,200,0.18)');
  left.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = left;
  ctx.fillRect(0, 0, w, h);

  // Right: teal/cyan bloom
  const right = ctx.createRadialGradient(w, h * 0.5, 0, w, h * 0.5, w * 0.55);
  right.addColorStop(0, 'rgba(0,180,180,0.15)');
  right.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = right;
  ctx.fillRect(0, 0, w, h);

  // Floor
  const floor = h * 0.72;
  ctx.fillStyle = '#070510';
  ctx.fillRect(0, floor, w, h - floor);

  // RGB underglow strip on floor line
  const strip = ctx.createLinearGradient(0, floor, w, floor);
  strip.addColorStop(0, 'rgba(180,0,255,0.8)');
  strip.addColorStop(0.5, 'rgba(0,220,220,0.8)');
  strip.addColorStop(1, 'rgba(255,0,150,0.8)');
  ctx.fillStyle = strip;
  ctx.fillRect(0, floor, w, 2);

  // Bloom from strip onto floor
  const bloom = ctx.createLinearGradient(0, floor, 0, floor + 80);
  bloom.addColorStop(0, 'rgba(100,0,200,0.18)');
  bloom.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = bloom;
  ctx.fillRect(0, floor, w, 80);
}

// ─── Warm Amber ───────────────────────────────────────────────────────────────
// Cozy, premium podcast / interview aesthetic
function drawWarmAmber(ctx: CanvasRenderingContext2D, w: number, h: number) {
  // Rich deep brown base
  const base = ctx.createRadialGradient(w * 0.5, h * 0.3, 0, w * 0.5, h * 0.5, w * 0.8);
  base.addColorStop(0, '#1e1408');
  base.addColorStop(0.5, '#140e06');
  base.addColorStop(1, '#0c0904');
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, w, h);

  // Warm amber key-light bloom (as if a warm practical lamp is top-right)
  const lamp = ctx.createRadialGradient(w * 0.78, 0, 0, w * 0.78, 0, w * 0.7);
  lamp.addColorStop(0, 'rgba(255,180,60,0.14)');
  lamp.addColorStop(0.4, 'rgba(220,130,30,0.06)');
  lamp.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = lamp;
  ctx.fillRect(0, 0, w, h);

  // Secondary fill light left (cooler, subtle)
  const fill = ctx.createRadialGradient(w * 0.08, h * 0.3, 0, w * 0.08, h * 0.3, w * 0.45);
  fill.addColorStop(0, 'rgba(200,160,80,0.07)');
  fill.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = fill;
  ctx.fillRect(0, 0, w, h);

  // Floor
  const floor = h * 0.74;
  const floorGrad = ctx.createLinearGradient(0, floor, 0, h);
  floorGrad.addColorStop(0, '#1a1008');
  floorGrad.addColorStop(1, '#0a0804');
  ctx.fillStyle = floorGrad;
  ctx.fillRect(0, floor, w, h - floor);

  // Warm seam
  const seam = ctx.createLinearGradient(0, floor, w, floor);
  seam.addColorStop(0, 'rgba(255,180,60,0)');
  seam.addColorStop(0.3, 'rgba(255,180,60,0.22)');
  seam.addColorStop(0.7, 'rgba(255,180,60,0.22)');
  seam.addColorStop(1, 'rgba(255,180,60,0)');
  ctx.fillStyle = seam;
  ctx.fillRect(0, floor - 1, w, 2);

  const refl = ctx.createLinearGradient(0, floor, 0, floor + 80);
  refl.addColorStop(0, 'rgba(180,100,20,0.10)');
  refl.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = refl;
  ctx.fillRect(0, floor, w, 80);
}

// ─── Exports ──────────────────────────────────────────────────────────────────
export const ROOM_BACKGROUNDS: RoomBackground[] = [
  {
    id: 'studio_black',
    name: 'Studio',
    cssPreview: 'radial-gradient(ellipse at 20% 0%, #2a2420 0%, #111113 50%, #09090b 100%)',
    draw: drawStudioBlack,
  },
  {
    id: 'deep_ocean',
    name: 'Ocean',
    cssPreview: 'linear-gradient(135deg, #0d1b3e 0%, #0a1628 50%, #060e1c 100%)',
    draw: drawDeepOcean,
  },
  {
    id: 'neon_noir',
    name: 'Neon',
    cssPreview: 'radial-gradient(ellipse at 0% 50%, #1a0a2e 0%, #08060f 50%, #001a18 100%)',
    draw: drawNeonNoir,
  },
  {
    id: 'warm_amber',
    name: 'Amber',
    cssPreview: 'radial-gradient(ellipse at 75% 0%, #2a1a08 0%, #140e06 50%, #0c0904 100%)',
    draw: drawWarmAmber,
  },
];
