'use client';
import { useEffect, useRef, useState, useImperativeHandle, forwardRef } from 'react';
import { RoomCompositor, Participant } from '@/lib/compositing/room-compositor';
import { SegmentationPipeline } from '@/lib/compositing/segmentation-pipeline';
import { ROOM_BACKGROUNDS } from '@/lib/compositing/room-backgrounds';
import { VIDEO_FILTERS } from '@/lib/compositing/video-filters';

export interface CompositorHandle {
  captureStream: (fps?: number) => MediaStream | null;
  addRemoteVideo: (uid: string, videoElement: HTMLVideoElement) => void;
  removeRemoteVideo: (uid: string) => void;
}

interface Props {
  localVideoElement: HTMLVideoElement | null;
  localUid: string;
  backgroundId?: string;
  filterId?: string;
  showControls?: boolean;
}

export const RoomCompositorView = forwardRef<CompositorHandle, Props>(
  ({ localVideoElement, localUid, backgroundId, filterId, showControls = true }, ref) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const compositorRef = useRef<RoomCompositor | null>(null);
    const localPipelineRef = useRef<SegmentationPipeline | null>(null);
    const remotePipelines = useRef<Map<string, SegmentationPipeline>>(new Map());
    const [scales, setScales] = useState<Record<string, number>>({});
    const [brightnesses, setBrightnesses] = useState<Record<string, number>>({});

    // Boot the compositor once — mount its canvas directly to avoid a second RAF copy loop
    useEffect(() => {
      const compositor = new RoomCompositor(1280, 720);
      compositor.setBackground(ROOM_BACKGROUNDS[0]);
      compositorRef.current = compositor;
      compositor.start();

      const canvas = compositor.outputCanvas;
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.display = 'block';
      containerRef.current?.appendChild(canvas);

      return () => {
        compositor.stop();
        canvas.parentNode?.removeChild(canvas);
      };
    }, []);

    // Sync background when backgroundId prop changes
    useEffect(() => {
      const bg = ROOM_BACKGROUNDS.find((b) => b.id === backgroundId) ?? ROOM_BACKGROUNDS[0];
      compositorRef.current?.setBackground(bg);
    }, [backgroundId]);

    // Sync filter into local pipeline
    useEffect(() => {
      const filter = VIDEO_FILTERS.find((f) => f.id === filterId) ?? VIDEO_FILTERS[0];
      localPipelineRef.current?.setFilter(filter);
    }, [filterId]);

    // Add local participant when video element is ready
    useEffect(() => {
      if (!localVideoElement || !compositorRef.current) return;
      const pipeline = new SegmentationPipeline(localVideoElement);
      pipeline.start();
      localPipelineRef.current = pipeline;
      compositorRef.current.addParticipant({ id: localUid, pipeline });
      return () => {
        pipeline.stop();
        compositorRef.current?.removeParticipant(localUid);
      };
    }, [localVideoElement, localUid]);

    // Expose imperative API
    useImperativeHandle(ref, () => ({
      captureStream: (fps = 30) => compositorRef.current?.captureStream(fps) ?? null,
      addRemoteVideo: (uid: string, videoElement: HTMLVideoElement) => {
        if (remotePipelines.current.has(uid)) return;
        const pipeline = new SegmentationPipeline(videoElement);
        pipeline.start();
        remotePipelines.current.set(uid, pipeline);
        compositorRef.current?.addParticipant({ id: uid, pipeline });
      },
      removeRemoteVideo: (uid: string) => {
        remotePipelines.current.get(uid)?.stop();
        remotePipelines.current.delete(uid);
        compositorRef.current?.removeParticipant(uid);
      },
    }));

    const handleScale = (uid: string, val: number) => {
      setScales((prev) => ({ ...prev, [uid]: val }));
      compositorRef.current?.setManualScale(uid, val);
    };

    const handleBrightness = (uid: string, val: number) => {
      setBrightnesses((prev) => ({ ...prev, [uid]: val }));
      compositorRef.current?.setManualBrightness(uid, val);
    };

    const participants = [localUid, ...Array.from(remotePipelines.current.keys())];

    return (
      <div className="space-y-4">
        {/* Compositor preview */}
        <div className="relative aspect-video bg-black rounded-xl overflow-hidden">
          <div ref={containerRef} className="w-full h-full" />
          <div className="absolute top-3 left-3 px-2 py-1 bg-[#FF7043] text-white text-xs font-bold rounded">
            ROOM MODE
          </div>
        </div>

        {showControls && (
          <div>
            {/* Per-person controls */}
            <div>
              <p className="text-xs text-white/40 uppercase tracking-wider mb-2 font-semibold">Person Controls</p>
              <div className="space-y-3">
                {participants.map((uid) => (
                  <div key={uid} className="bg-white/5 rounded-xl p-3 space-y-2">
                    <p className="text-xs text-white/60 font-medium">{uid === localUid ? 'You' : `Co-host (${uid.slice(0, 6)})`}</p>
                    <label className="flex items-center gap-2 text-xs text-white/50">
                      Scale
                      <input
                        type="range" min={0.4} max={2.0} step={0.05}
                        value={scales[uid] ?? 1}
                        onChange={(e) => handleScale(uid, parseFloat(e.target.value))}
                        className="flex-1 accent-[#FF7043]"
                      />
                      <span className="w-8 text-right">{(scales[uid] ?? 1).toFixed(2)}×</span>
                    </label>
                    <label className="flex items-center gap-2 text-xs text-white/50">
                      Light
                      <input
                        type="range" min={0.5} max={2.0} step={0.05}
                        value={brightnesses[uid] ?? 1}
                        onChange={(e) => handleBrightness(uid, parseFloat(e.target.value))}
                        className="flex-1 accent-[#FFD166]"
                      />
                      <span className="w-8 text-right">{(brightnesses[uid] ?? 1).toFixed(2)}×</span>
                    </label>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    );
  },
);

RoomCompositorView.displayName = 'RoomCompositorView';
