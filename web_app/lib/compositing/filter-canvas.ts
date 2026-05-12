// Draws a video element through a canvas with a CSS filter applied.
// Used in non-room mode to apply filters to the raw camera feed before publishing to Agora.
import { VideoFilter } from './video-filters';

export class FilterCanvas {
  readonly canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private rafId = 0;
  private running = false;
  private filterCss = 'none';
  private postProcess: VideoFilter['postProcess'] | null = null;

  constructor(private video: HTMLVideoElement, width = 1280, height = 720) {
    this.canvas = document.createElement('canvas');
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext('2d', { alpha: false })!;
  }

  setFilter(filter: VideoFilter) {
    this.filterCss = filter.css;
    this.postProcess = filter.postProcess ?? null;
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.loop();
  }

  stop() {
    this.running = false;
    cancelAnimationFrame(this.rafId);
  }

  captureStream(fps = 30): MediaStream {
    return (this.canvas as any).captureStream(fps) as MediaStream;
  }

  private loop() {
    if (!this.running) return;
    if (this.video.readyState >= 2) {
      this.ctx.filter = this.filterCss;
      this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);
      this.ctx.filter = 'none';
      if (this.postProcess) this.postProcess(this.ctx, this.canvas.width, this.canvas.height);
    }
    this.rafId = requestAnimationFrame(() => this.loop());
  }
}
