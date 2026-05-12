// Uses @mediapipe/tasks-vision ImageSegmenter (replaces the broken @mediapipe/selfie_segmentation@0.1 WASM).
// Loaded via CDN dynamic import — no script tag or npm package required.
import { VideoFilter } from './video-filters';

export interface MaskStats {
  top: number;
  bottom: number;
  left: number;
  right: number;
  avgLuminance: number;
}

// Minimal type wrappers for the CDN-loaded tasks-vision module
interface MPMask {
  getAsFloat32Array(): Float32Array;
  width: number;
  height: number;
  close(): void;
}
interface SegResult {
  confidenceMasks?: MPMask[];
  close(): void;
}
interface Segmenter {
  segmentForVideo(video: HTMLVideoElement, ts: number): SegResult;
  close(): void;
}

const CDN = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';
const MODEL =
  'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite';

export class SegmentationPipeline {
  readonly outputCanvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private segmenter: Segmenter | null = null;
  private renderRafId = 0;
  private segmentTimeoutId = 0;
  private running = false;
  private filterCss = 'none';
  private postProcess: VideoFilter['postProcess'] | null = null;
  private lastTs = -1;
  // Last mask kept so the 60fps render loop can apply it every frame
  private lastMask: Float32Array | null = null;
  public stats: MaskStats = { top: 0, bottom: 1, left: 0, right: 1, avgLuminance: 128 };

  constructor(private video: HTMLVideoElement, width = 640, height = 480) {
    this.outputCanvas = document.createElement('canvas');
    this.outputCanvas.width = width;
    this.outputCanvas.height = height;
    this.ctx = this.outputCanvas.getContext('2d')!;
    this.initSegmenter();
  }

  private async initSegmenter() {
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const vision: any = await import(/* webpackIgnore: true */ `${CDN}/+esm`);
      const filesetResolver = await vision.FilesetResolver.forVisionTasks(`${CDN}/wasm`);
      this.segmenter = await vision.ImageSegmenter.createFromOptions(filesetResolver, {
        baseOptions: { modelAssetPath: MODEL, delegate: 'GPU' },
        outputCategoryMask: false,
        outputConfidenceMasks: true,
        runningMode: 'VIDEO',
      }) as Segmenter;
    } catch (e) {
      console.error('MediaPipe ImageSegmenter failed to load', e);
    }
  }

  setFilter(filter: VideoFilter) {
    this.filterCss = filter.css;
    this.postProcess = filter.postProcess ?? null;
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.renderLoop();   // 60 fps — draws video + applies last mask
    this.segmentLoop();  // ~15 fps — updates the mask
  }

  stop() {
    this.running = false;
    cancelAnimationFrame(this.renderRafId);
    clearTimeout(this.segmentTimeoutId);
    this.segmenter?.close();
  }

  // ── 60 fps render loop ──────────────────────────────────────────────────────
  private renderLoop() {
    if (!this.running) return;
    if (this.video.readyState >= 2) {
      this.renderFrame();
    }
    this.renderRafId = requestAnimationFrame(() => this.renderLoop());
  }

  private renderFrame() {
    const { width: w, height: h } = this.outputCanvas;
    this.ctx.clearRect(0, 0, w, h);
    this.ctx.filter = this.filterCss;
    this.ctx.drawImage(this.video, 0, 0, w, h);
    this.ctx.filter = 'none';

    if (this.lastMask) {
      const imageData = this.ctx.getImageData(0, 0, w, h);
      const pixels = imageData.data;
      for (let i = 0; i < this.lastMask.length; i++) {
        pixels[i * 4 + 3] = Math.round(this.lastMask[i] * 255);
      }
      this.ctx.putImageData(imageData, 0, 0);
    }
    if (this.postProcess) this.postProcess(this.ctx, w, h);
  }

  // ── ~15 fps segmentation loop ───────────────────────────────────────────────
  private segmentLoop() {
    if (!this.running) return;

    if (this.segmenter && this.video.readyState >= 2) {
      const ts = performance.now();
      const safeTs = ts > this.lastTs ? ts : this.lastTs + 1;
      this.lastTs = safeTs;

      const result = this.segmenter.segmentForVideo(this.video, safeTs);
      const mask = result.confidenceMasks?.[0];
      if (mask) {
        const arr = mask.getAsFloat32Array();
        // Copy into a persistent buffer so renderLoop can use it between segmentation frames
        if (!this.lastMask || this.lastMask.length !== arr.length) {
          this.lastMask = new Float32Array(arr.length);
        }
        this.lastMask.set(arr);
        mask.close();
        this.computeStats(this.lastMask, this.outputCanvas.width, this.outputCanvas.height);
      }
      result.close();
    }

    this.segmentTimeoutId = window.setTimeout(() => this.segmentLoop(), 66);
  }

  private computeStats(maskArr: Float32Array, w: number, h: number) {
    // Sample the current canvas pixels for luminance (already has the filter applied)
    const imgData = this.ctx.getImageData(0, 0, w, h).data;
    let minX = w, maxX = 0, minY = h, maxY = 0;
    let lumSum = 0, personPixels = 0;
    const stride = 4;

    for (let y = 0; y < h; y += stride) {
      for (let x = 0; x < w; x += stride) {
        const i = y * w + x;
        if (maskArr[i] > 0.5) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          const pi = i * 4;
          lumSum += 0.299 * imgData[pi] + 0.587 * imgData[pi + 1] + 0.114 * imgData[pi + 2];
          personPixels++;
        }
      }
    }

    if (personPixels > 0) {
      this.stats = {
        top: minY / h,
        bottom: maxY / h,
        left: minX / w,
        right: maxX / w,
        avgLuminance: lumSum / personPixels,
      };
    }
  }
}
