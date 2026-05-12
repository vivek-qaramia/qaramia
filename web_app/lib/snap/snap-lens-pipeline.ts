import {
  bootstrapCameraKit,
  createMediaStreamSource,
  Transform2D,
  type CameraKit,
  type CameraKitSession,
  type Lens,
} from '@snap/camera-kit';

export interface LensInfo {
  id: string;
  name: string;
  thumbnailUrl?: string;
}

export class SnapLensPipeline {
  outputCanvas: HTMLCanvasElement | null = null;
  /** Hidden video element playing the raw (unprocessed) camera stream — use this for product scanning. */
  rawVideoEl: HTMLVideoElement | null = null;

  private cameraKit: CameraKit | null = null;
  private session: CameraKitSession | null = null;
  private lensObjects: Lens[] = [];
  private cameraStream: MediaStream | null = null;

  async init(apiToken: string, lensGroupId: string): Promise<void> {
    this.cameraStream = await navigator.mediaDevices.getUserMedia({
      video: { width: { ideal: 1280 }, height: { ideal: 720 }, facingMode: 'user' },
      audio: false,
    });

    this.cameraKit = await bootstrapCameraKit({ apiToken });
    this.session = await this.cameraKit.createSession();

    const source = createMediaStreamSource(this.cameraStream, {
      transform: Transform2D.MirrorX,
      disableSourceAudio: true,
    });
    await this.session.setSource(source);
    this.outputCanvas = this.session.output.live;

    if (lensGroupId) {
      try {
        const { lenses } = await this.cameraKit.lensRepository.loadLensGroups([lensGroupId]);
        this.lensObjects = lenses;
      } catch (e) {
        console.error('Snap: failed to load lens group', e);
      }
    }

    await this.session.play();

    // Hidden video for raw-frame access (used by product scanner)
    const vid = document.createElement('video');
    vid.srcObject = this.cameraStream;
    vid.autoplay = true;
    vid.muted = true;
    vid.playsInline = true;
    await vid.play().catch(() => {});
    this.rawVideoEl = vid;
  }

  getLenses(): LensInfo[] {
    return this.lensObjects.map((l) => ({
      id: l.id,
      name: l.name,
      // Snap Lens type doesn't expose icons in the public type; access defensively
      thumbnailUrl: (l as unknown as { icons?: { imageUrl: string }[] }).icons?.[0]?.imageUrl,
    }));
  }

  async applyLens(id: string): Promise<void> {
    const lens = this.lensObjects.find((l) => l.id === id);
    if (lens && this.session) await this.session.applyLens(lens);
  }

  async clearLens(): Promise<void> {
    await this.session?.removeLens();
  }

  captureStream(fps = 30): MediaStream | null {
    if (!this.outputCanvas) return null;
    return (this.outputCanvas as HTMLCanvasElement & { captureStream(fps: number): MediaStream }).captureStream(fps);
  }

  destroy(): void {
    this.session?.removeLens().catch(() => {});
    this.cameraKit?.destroy().catch(() => {});
    this.cameraStream?.getTracks().forEach((t) => t.stop());
    if (this.rawVideoEl) { this.rawVideoEl.srcObject = null; this.rawVideoEl = null; }
    this.session = null;
    this.cameraKit = null;
    this.cameraStream = null;
    this.lensObjects = [];
    this.outputCanvas = null;
  }
}
