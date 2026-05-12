import { RoomBackground } from './room-backgrounds';
import { SegmentationPipeline } from './segmentation-pipeline';

export interface Participant {
  id: string;           // uid or 'local'
  pipeline: SegmentationPipeline;
  // Manual overrides (0.5–2.0)
  scaleOverride?: number;
  brightnessOverride?: number;
}

// Layout slot for each participant on the canvas
interface Slot {
  x: number;
  y: number;
  w: number;
  h: number;
}

// TARGET_LUMINANCE: all participants are normalized toward this value
const TARGET_LUMINANCE = 145;
const FLOOR_RATIO = 0.72; // y position of floor as fraction of canvas height

export class RoomCompositor {
  readonly outputCanvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private participants: Participant[] = [];
  private background: RoomBackground | null = null;
  private rafId = 0;
  private running = false;

  constructor(width = 1280, height = 720) {
    this.outputCanvas = document.createElement('canvas');
    this.outputCanvas.width = width;
    this.outputCanvas.height = height;
    this.ctx = this.outputCanvas.getContext('2d', { alpha: false })!;
  }

  setBackground(bg: RoomBackground) {
    this.background = bg;
  }

  addParticipant(p: Participant) {
    if (!this.participants.find((x) => x.id === p.id)) {
      this.participants.push(p);
    }
  }

  removeParticipant(id: string) {
    this.participants = this.participants.filter((p) => p.id !== id);
  }

  setManualScale(id: string, scale: number) {
    const p = this.participants.find((x) => x.id === id);
    if (p) p.scaleOverride = scale;
  }

  setManualBrightness(id: string, brightness: number) {
    const p = this.participants.find((x) => x.id === id);
    if (p) p.brightnessOverride = brightness;
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.render();
  }

  stop() {
    this.running = false;
    cancelAnimationFrame(this.rafId);
  }

  // Returns a MediaStream that can be published to Agora as a custom video track
  captureStream(fps = 30): MediaStream {
    return (this.outputCanvas as any).captureStream(fps) as MediaStream;
  }

  private render() {
    if (!this.running) return;

    const { width: W, height: H } = this.outputCanvas;

    // 1. Draw room background
    this.ctx.clearRect(0, 0, W, H);
    if (this.background) {
      this.background.draw(this.ctx, W, H);
    } else {
      this.ctx.fillStyle = '#111';
      this.ctx.fillRect(0, 0, W, H);
    }

    // 2. Compute layout slots
    const slots = this.computeSlots(this.participants.length, W, H);

    // 3. Draw each participant
    this.participants.forEach((p, i) => {
      const slot = slots[i];
      if (!slot) return;
      this.drawParticipant(p, slot, W, H);
    });

    this.rafId = requestAnimationFrame(() => this.render());
  }

  private drawParticipant(p: Participant, slot: Slot, W: number, H: number) {
    const { outputCanvas: personCanvas, stats } = p.pipeline;
    const floorY = H * FLOOR_RATIO;

    // ── Auto scale: normalize person height so everyone looks same distance ──
    const personHeightRatio = stats.bottom - stats.top; // fraction of their source canvas
    const personHeightPx = personHeightRatio * personCanvas.height;
    const targetHeightPx = slot.h * 0.88; // fill 88% of the slot height
    let autoScale = personHeightPx > 0 ? targetHeightPx / personHeightPx : 1;
    autoScale = Math.max(0.3, Math.min(2.5, autoScale));

    const scale = p.scaleOverride ?? autoScale;

    // ── Derived dimensions ────────────────────────────────────────────────────
    const srcW = personCanvas.width;
    const srcH = personCanvas.height;
    const dstW = srcW * scale * (slot.w / srcW);
    const dstH = srcH * scale * (slot.h / srcH);

    // Anchor person's feet to the floor line
    const feetSrcY = stats.bottom * srcH;
    const feetDstY = feetSrcY * (dstH / srcH);
    const dstX = slot.x + (slot.w - dstW) / 2;
    const dstY = floorY - feetDstY + (dstH * (1 - stats.bottom));

    // ── Luminance correction ──────────────────────────────────────────────────
    const lum = stats.avgLuminance || TARGET_LUMINANCE;
    const autoCorrection = TARGET_LUMINANCE / lum;
    const correction = p.brightnessOverride ?? Math.max(0.5, Math.min(2.0, autoCorrection));

    // ── Drop shadow under feet ────────────────────────────────────────────────
    const shadowW = dstW * 0.55;
    const shadowH = shadowW * 0.22;
    const shadowGrad = this.ctx.createRadialGradient(
      dstX + dstW / 2, floorY, 0,
      dstX + dstW / 2, floorY, shadowW / 2,
    );
    shadowGrad.addColorStop(0, 'rgba(0,0,0,0.45)');
    shadowGrad.addColorStop(1, 'rgba(0,0,0,0)');
    this.ctx.save();
    this.ctx.scale(1, 0.35);
    this.ctx.fillStyle = shadowGrad;
    this.ctx.beginPath();
    this.ctx.ellipse(
      dstX + dstW / 2,
      floorY / 0.35,
      shadowW / 2,
      shadowH / 0.35,
      0, 0, Math.PI * 2,
    );
    this.ctx.fill();
    this.ctx.restore();

    // ── Draw the segmented person with luminance correction ───────────────────
    this.ctx.save();
    this.ctx.filter = `brightness(${correction.toFixed(2)})`;
    this.ctx.drawImage(personCanvas, dstX, dstY, dstW, dstH);
    this.ctx.restore();
  }

  // ── Layout: slots for 1–4 participants ─────────────────────────────────────
  private computeSlots(count: number, W: number, H: number): Slot[] {
    const floorY = H * FLOOR_RATIO;
    const padding = W * 0.03;

    if (count === 0) return [];

    if (count === 1) {
      return [{ x: padding, y: 0, w: W - padding * 2, h: floorY }];
    }

    if (count === 2) {
      const half = (W - padding * 3) / 2;
      return [
        { x: padding, y: 0, w: half, h: floorY },
        { x: padding * 2 + half, y: 0, w: half, h: floorY },
      ];
    }

    if (count === 3) {
      const third = (W - padding * 4) / 3;
      return [
        { x: padding, y: 0, w: third, h: floorY },
        { x: padding * 2 + third, y: 0, w: third, h: floorY },
        { x: padding * 3 + third * 2, y: 0, w: third, h: floorY },
      ];
    }

    // 4 → 2×2 grid
    const half = (W - padding * 3) / 2;
    const halfH = (floorY - padding) / 2;
    return [
      { x: padding, y: 0, w: half, h: halfH },
      { x: padding * 2 + half, y: 0, w: half, h: halfH },
      { x: padding, y: halfH + padding, w: half, h: halfH },
      { x: padding * 2 + half, y: halfH + padding, w: half, h: halfH },
    ];
  }
}
