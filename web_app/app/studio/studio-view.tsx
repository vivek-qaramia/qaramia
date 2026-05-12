'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth-store';
import { db, rtdb } from '@/lib/firebase';
import { collection, addDoc, doc, updateDoc, serverTimestamp, increment } from 'firebase/firestore';
import { ref as rtdbRef, set as rtdbSet, remove as rtdbRemove } from 'firebase/database';
import { CaptionEngine, isCaptionSupported } from '@/lib/speech/caption-engine';
import { useDanmaku, useSingleStream } from '@/hooks/use-live-stream';
import { useCohosts } from '@/hooks/use-cohosts';
import { CohostInvite } from '@/components/live/cohost-invite';
import { RoomCompositorView, CompositorHandle } from '@/components/live/room-compositor-view';
import { RoomPicker } from '@/components/live/room-picker';
import { FilterPicker } from '@/components/live/filter-picker';
import { AudioEffectPicker } from '@/components/live/audio-effect-picker';
import { LensPicker } from '@/components/live/lens-picker';
import { ProductDrawer } from '@/components/live/product-drawer';
import { AudioEffectPipeline } from '@/lib/audio/audio-effects';
import { scanBarcodeFromVideo } from '@/lib/product-scanner/barcode-scanner';
import { lookupBarcode } from '@/lib/product-scanner/product-lookup';
import { captureFingerprint, fingerprintDiff, SCENE_CHANGE_THRESHOLD } from '@/lib/product-scanner/frame-fingerprint';
import type { ProductInfo, Ad } from '@/lib/types';
import { matchAd } from '@/hooks/use-ads';
import { SnapLensPipeline, type LensInfo } from '@/lib/snap/snap-lens-pipeline';
import { VIDEO_FILTERS } from '@/lib/compositing/video-filters';
import { FilterCanvas } from '@/lib/compositing/filter-canvas';
import AgoraRTC, { ILocalAudioTrack, IAgoraRTCRemoteUser } from 'agora-rtc-sdk-ng';

const QUALITY_PRESETS = {
  '480p':   { label: '480p',       width: 854,  height: 480,  frameRate: 30, bitrateMax: 1500, bitrateMin: 300  },
  '720p':   { label: '720p HD',    width: 1280, height: 720,  frameRate: 30, bitrateMax: 3000, bitrateMin: 600  },
  '720p60': { label: '720p 60fps', width: 1280, height: 720,  frameRate: 60, bitrateMax: 4500, bitrateMin: 1000 },
  '1080p':  { label: '1080p Full HD', width: 1920, height: 1080, frameRate: 30, bitrateMax: 5000, bitrateMin: 1000 },
} as const;
type QualityPresetKey = keyof typeof QUALITY_PRESETS;

const AGORA_APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? '';
const SNAP_API_TOKEN = process.env.NEXT_PUBLIC_SNAP_API_TOKEN ?? '';
const SNAP_LENS_GROUP_ID = process.env.NEXT_PUBLIC_SNAP_LENS_GROUP_ID ?? '';
const CATEGORIES = ['General', 'Gaming', 'Music', 'IRL', 'Sports', 'Cooking', 'Education'];

export default function StudioView() {
  const { user } = useAuthStore();
  const router = useRouter();
  const [isLive, setIsLive] = useState(false);
  const [streamId, setStreamId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('General');
  const [starting, setStarting] = useState(false);
  const [virtualBg, setVirtualBg] = useState(false);
  const [roomMode, setRoomMode] = useState(false);
  const [selectedBgId, setSelectedBgId] = useState('studio_black');

  const useCompositor = virtualBg || roomMode;
  const [filterId, setFilterId] = useState('none');
  const filterCanvasRef = useRef<FilterCanvas | null>(null);
  const [audioEffectId, setAudioEffectId] = useState('none');
  const audioEffectRef = useRef<AudioEffectPipeline | null>(null);

  const [qualityPreset, setQualityPreset] = useState<QualityPresetKey>('720p');
  const [uplinkQuality, setUplinkQuality] = useState(0);
  const [snapPanelOpen, setSnapPanelOpen] = useState(false);
  const [bgPanelOpen, setBgPanelOpen] = useState(false); // 0=unknown 1-2=good 3=fair 4-5=poor 6=down

  // Product scanner
  const [scanning, setScanning] = useState(false);
  const [detectedProducts, setDetectedProducts] = useState<ProductInfo[]>([]);
  const [featuredAd, setFeaturedAd] = useState<Ad | null>(null);
  const [continuousScan, setContinuousScan] = useState(false);

  // Session earnings tracking
  const [sessionProductCount, setSessionProductCount] = useState(0);
  const [sessionImpressions, setSessionImpressions] = useState(0);
  const [sessionAffiliateClicks, setSessionAffiliateClicks] = useState(0);
  const lastFingerprintRef = useRef<Uint8ClampedArray | null>(null);
  const lastBarcodeRef = useRef<string | null>(null);
  const continuousIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Captions + spoken product detection
  const [captionsEnabled, setCaptionsEnabled] = useState(false);
  const [captionsSupported] = useState(() => typeof window !== 'undefined' && isCaptionSupported());
  const [currentCaption, setCurrentCaption] = useState('');
  const captionEngineRef = useRef<CaptionEngine | null>(null);
  const lastCaptionWriteRef = useRef<number>(0);
  const transcriptBufferRef = useRef<{ text: string; t: number }[]>([]);
  const lastSpeechMatchRef = useRef<number>(0);

  // Snap Camera Kit
  const [snapEnabled, setSnapEnabled] = useState(false);
  const [selectedLensId, setSelectedLensId] = useState<string | null>(null);
  const [snapLenses, setSnapLenses] = useState<LensInfo[]>([]);
  const [snapLoading, setSnapLoading] = useState(false);
  const snapPipelineRef = useRef<SnapLensPipeline | null>(null);
  const snapPreviewContainerRef = useRef<HTMLDivElement | null>(null);

  // Raw camera preview (used in normal + compositor mode)
  const previewRef = useRef<HTMLDivElement>(null);
  const localVideoElRef = useRef<HTMLVideoElement | null>(null);

  const clientRef = useRef<ReturnType<typeof AgoraRTC.createClient> | null>(null);
  const audioTrackRef = useRef<ILocalAudioTrack | null>(null);
  const compositorRef = useRef<CompositorHandle | null>(null);

  const stream = useSingleStream(streamId);
  const messages = useDanmaku(streamId ?? '');
  const cohosts = useCohosts(streamId ?? '');

  useEffect(() => {
    if (!user) router.push('/login');
  }, [user, router]);

  // Agora camera preview — skip when Snap owns the camera
  useEffect(() => {
    if (snapEnabled) return;
    let videoTrack: Awaited<ReturnType<typeof AgoraRTC.createCameraVideoTrack>>;
    AgoraRTC.createCameraVideoTrack().then((track) => {
      videoTrack = track;
      if (previewRef.current) {
        track.play(previewRef.current);
        const el = previewRef.current.querySelector('video');
        if (el) localVideoElRef.current = el;
      }
    }).catch(() => {});
    return () => { videoTrack?.stop(); videoTrack?.close(); };
  }, [snapEnabled]);

  // Camera Kit lifecycle
  useEffect(() => {
    if (!snapEnabled || !SNAP_API_TOKEN) return;
    setSnapLoading(true);
    const pipeline = new SnapLensPipeline();
    snapPipelineRef.current = pipeline;

    pipeline.init(SNAP_API_TOKEN, SNAP_LENS_GROUP_ID)
      .then(() => {
        if (snapPreviewContainerRef.current && pipeline.outputCanvas) {
          snapPreviewContainerRef.current.innerHTML = '';
          const canvas = pipeline.outputCanvas;
          canvas.style.cssText = 'width:100%;height:100%;display:block;';
          snapPreviewContainerRef.current.appendChild(canvas);
        }
        setSnapLenses(pipeline.getLenses());
        setSnapLoading(false);
      })
      .catch((err) => {
        console.error('Camera Kit init failed', err);
        setSnapLoading(false);
      });

    return () => {
      pipeline.destroy();
      snapPipelineRef.current = null;
      setSnapLenses([]);
      setSelectedLensId(null);
    };
  }, [snapEnabled]);

  // Apply / clear lens when selection changes
  useEffect(() => {
    if (!snapPipelineRef.current) return;
    if (selectedLensId) {
      snapPipelineRef.current.applyLens(selectedLensId);
    } else {
      snapPipelineRef.current.clearLens();
    }
  }, [selectedLensId]);

  // Wire co-host remote video tracks into the compositor
  useEffect(() => {
    if (!clientRef.current || !compositorRef.current) return;
    const client = clientRef.current;
    const comp = compositorRef.current;

    const onPublished = async (remoteUser: IAgoraRTCRemoteUser, mediaType: 'video' | 'audio') => {
      try {
        await client.subscribe(remoteUser, mediaType);
      } catch (e: unknown) {
        if ((e as { code?: string })?.code !== 'OPERATION_ABORTED') console.error(e);
        return;
      }
      if (mediaType === 'video' && remoteUser.videoTrack && useCompositor) {
        const el = document.createElement('video');
        el.autoplay = true; el.muted = true; el.playsInline = true;
        remoteUser.videoTrack.play(el);
        comp.addRemoteVideo(String(remoteUser.uid), el);
      }
    };
    const onUnpublished = (remoteUser: IAgoraRTCRemoteUser) => {
      comp.removeRemoteVideo(String(remoteUser.uid));
    };

    client.on('user-published', onPublished);
    client.on('user-unpublished', onUnpublished);
    return () => {
      client.off('user-published', onPublished);
      client.off('user-unpublished', onUnpublished);
    };
  }, [isLive, useCompositor]);

  useEffect(() => {
    audioEffectRef.current?.setEffect(audioEffectId);
  }, [audioEffectId]);

  // Continuous scan — 5-second interval, stops when toggled off or stream ends
  useEffect(() => {
    if (!continuousScan) {
      if (continuousIntervalRef.current) {
        clearInterval(continuousIntervalRef.current);
        continuousIntervalRef.current = null;
      }
      lastFingerprintRef.current = null;
      lastBarcodeRef.current = null;
      return;
    }
    continuousIntervalRef.current = setInterval(() => { handleScan(true); }, 5000);
    return () => {
      if (continuousIntervalRef.current) clearInterval(continuousIntervalRef.current);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [continuousScan]);

  const handleScan = async (auto = false) => {
    if (scanning) return;
    setScanning(true);
    if (!auto) setDetectedProducts([]);
    try {
      const videoEl = snapEnabled
        ? snapPipelineRef.current?.rawVideoEl ?? null
        : localVideoElRef.current;
      if (!videoEl) return;

      // 1. Barcode (always fast + free)
      const barcode = await scanBarcodeFromVideo(videoEl);
      if (barcode) {
        // Skip lookup if same barcode as last auto-scan tick
        if (auto && barcode === lastBarcodeRef.current) return;
        lastBarcodeRef.current = barcode;
        lastFingerprintRef.current = null; // reset vision fingerprint
        const product = await lookupBarcode(barcode);
        const barcodeProducts: ProductInfo[] = [product ?? { barcode, source: 'barcode', name: barcode, description: 'Product not found in database.' }];
        await publishProducts(barcodeProducts);
        return;
      }

      // 2. Claude Vision fallback
      const fingerprint = captureFingerprint(videoEl);

      // In auto mode: skip the API call if the scene hasn't changed
      if (auto && fingerprint && lastFingerprintRef.current) {
        const diff = fingerprintDiff(fingerprint, lastFingerprintRef.current);
        if (diff < SCENE_CHANGE_THRESHOLD) return;
      }

      lastFingerprintRef.current = fingerprint;
      lastBarcodeRef.current = null;

      const canvas = document.createElement('canvas');
      canvas.width = videoEl.videoWidth || 1280;
      canvas.height = videoEl.videoHeight || 720;
      canvas.getContext('2d')!.drawImage(videoEl, 0, 0);
      const base64 = canvas.toDataURL('image/jpeg', 0.8).split(',')[1];

      const res = await fetch('/api/scan-product', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image: base64 }),
      });
      const data = await res.json() as { products: Omit<ProductInfo, 'source'>[] };
      if (data.products?.length > 0) {
        const visionProducts = data.products.map((p) => ({ ...p, source: 'vision' as const }));
        await publishProducts(visionProducts);
      }
    } catch (err) {
      console.error('Scan failed', err);
    } finally {
      setScanning(false);
    }
  };

  const publishProducts = async (products: ProductInfo[]) => {
    setDetectedProducts(products);
    setSessionProductCount(c => c + 1);
    const ad = await matchAd(products).catch(() => null);
    setFeaturedAd(ad);
    if (ad) setSessionImpressions(c => c + 1);
    if (stream?.id) {
      updateDoc(doc(db, 'streams', stream.id), {
        featuredProducts: products,
        featuredAd: ad ?? null,
      }).catch(() => {});
    }
  };

  const dismissProducts = () => {
    setDetectedProducts([]);
    setFeaturedAd(null);
    if (stream?.id) updateDoc(doc(db, 'streams', stream.id), { featuredProducts: [], featuredAd: null }).catch(() => {});
  };

  // Stable ref to publishProducts so the speech-detection callback always uses the latest closure.
  const publishProductsRef = useRef(publishProducts);
  useEffect(() => { publishProductsRef.current = publishProducts; });

  // Caption engine lifecycle — runs while streaming AND captions toggle is on.
  // Single transcript stream feeds both viewer captions (RTDB) and spoken product detection.
  useEffect(() => {
    if (!isLive || !captionsEnabled || !streamId) return;
    if (!isCaptionSupported()) return;

    const tryMatchSpoken = async (newText: string) => {
      const now = Date.now();
      transcriptBufferRef.current.push({ text: newText, t: now });
      transcriptBufferRef.current = transcriptBufferRef.current.filter(e => now - e.t <= 30_000);

      if (now - lastSpeechMatchRef.current < 8_000) return;

      const combined = transcriptBufferRef.current.map(e => e.text).join(' ').toLowerCase();
      const tokens = combined.split(/[\s,.!?;:]+/).filter(t => t.length > 2);
      if (tokens.length < 2) return;

      const uniqueTokens = [...new Set(tokens)].slice(0, 10);
      const probe: ProductInfo[] = [{ source: 'speech', name: uniqueTokens.join(' ') }];
      const ad = await matchAd(probe).catch(() => null);
      if (!ad) return;

      const adKeywordSet = new Set(ad.keywords ?? []);
      const matchingWords = uniqueTokens.filter(t => adKeywordSet.has(t));
      if (!matchingWords.length) return;

      lastSpeechMatchRef.current = now;
      const displayName = matchingWords.map(w => w[0].toUpperCase() + w.slice(1)).join(' ');
      publishProductsRef.current([{ name: displayName, source: 'speech' }]);
    };

    const engine = new CaptionEngine((result) => {
      // Always update local preview so the streamer sees what's being transcribed
      setCurrentCaption(result.text);

      // Throttled write to RTDB for viewer fan-out (250ms minimum gap, but always send finals)
      const now = Date.now();
      if (result.isFinal || now - lastCaptionWriteRef.current >= 250) {
        lastCaptionWriteRef.current = now;
        rtdbSet(rtdbRef(rtdb, `captions/${streamId}/current`), {
          text: result.text,
          t: now,
          isFinal: result.isFinal,
        }).catch(() => {});
      }

      if (result.isFinal) {
        tryMatchSpoken(result.text);
      }
    });

    const started = engine.start();
    if (!started) {
      setCaptionsEnabled(false);
      return;
    }
    captionEngineRef.current = engine;

    return () => {
      engine.stop();
      captionEngineRef.current = null;
      setCurrentCaption('');
      transcriptBufferRef.current = [];
      // Clear caption from RTDB so viewers don't see a stale frame
      rtdbRemove(rtdbRef(rtdb, `captions/${streamId}/current`)).catch(() => {});
    };
  }, [isLive, captionsEnabled, streamId]);

  const startStream = async () => {
    if (!title.trim() || !user) return;
    setStarting(true);
    try {
      const docRef = await addDoc(collection(db, 'streams'), {
        hostUid: user.uid,
        hostUsername: user.username,
        hostAvatarUrl: user.avatarUrl ?? null,
        title: title.trim(),
        category,
        viewerCount: 0,
        peakViewerCount: 0,
        totalGifts: 0,
        status: 'live',
        agoraChannel: '',
        roomMode,
        startedAt: serverTimestamp(),
      });
      await updateDoc(doc(db, 'streams', docRef.id), { agoraChannel: docRef.id, id: docRef.id });
      await updateDoc(doc(db, 'users', user.uid), { isLive: true });

      const client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
      clientRef.current = client;
      await client.setClientRole('host');
      await client.join(AGORA_APP_ID, docRef.id, null, null);

      client.on('network-quality', (stats) => {
        setUplinkQuality(stats.uplinkNetworkQuality);
      });

      const preset = QUALITY_PRESETS[qualityPreset];

      // Mic only in snap mode (Camera Kit already owns the camera)
      let audioTrack: ILocalAudioTrack;
      let videoTrackFromAgora: Awaited<ReturnType<typeof AgoraRTC.createCameraVideoTrack>> | null = null;
      if (snapEnabled) {
        audioTrack = await AgoraRTC.createMicrophoneAudioTrack();
      } else {
        const tracks = await AgoraRTC.createMicrophoneAndCameraTracks({}, {
          encoderConfig: {
            width: preset.width, height: preset.height,
            frameRate: preset.frameRate,
            bitrateMax: preset.bitrateMax, bitrateMin: preset.bitrateMin,
          },
        });
        audioTrack = tracks[0];
        videoTrackFromAgora = tracks[1];
      }

      audioTrackRef.current = audioTrack;

      const rawMicStream = new MediaStream([audioTrack.getMediaStreamTrack()]);
      const audioPipeline = new AudioEffectPipeline(rawMicStream);
      audioPipeline.setEffect(audioEffectId);
      audioEffectRef.current = audioPipeline;
      const effectiveAudioTrack = audioEffectId !== 'none'
        ? AgoraRTC.createCustomAudioTrack({ mediaStreamTrack: audioPipeline.outputStream.getAudioTracks()[0] })
        : audioTrack;

      const customTrackOpts = { bitrateMax: preset.bitrateMax, bitrateMin: preset.bitrateMin, frameRate: preset.frameRate };

      if (snapEnabled && snapPipelineRef.current) {
        const snapStream = snapPipelineRef.current.captureStream(preset.frameRate);
        if (snapStream) {
          const snapVideoTrack = AgoraRTC.createCustomVideoTrack({ mediaStreamTrack: snapStream.getVideoTracks()[0], ...customTrackOpts });
          await client.publish([effectiveAudioTrack, snapVideoTrack]);
        }
      } else if (useCompositor && compositorRef.current) {
        const compositeStream = compositorRef.current.captureStream(preset.frameRate);
        if (compositeStream) {
          const compositeTrack = AgoraRTC.createCustomVideoTrack({ mediaStreamTrack: compositeStream.getVideoTracks()[0], ...customTrackOpts });
          await client.publish([effectiveAudioTrack, compositeTrack]);
        }
      } else {
        const selectedFilter = VIDEO_FILTERS.find((f) => f.id === filterId);
        if (selectedFilter && selectedFilter.css !== 'none' && localVideoElRef.current) {
          const fc = new FilterCanvas(localVideoElRef.current);
          fc.setFilter(selectedFilter);
          fc.start();
          filterCanvasRef.current = fc;
          const filteredTrack = AgoraRTC.createCustomVideoTrack({ mediaStreamTrack: fc.captureStream(preset.frameRate).getVideoTracks()[0], ...customTrackOpts });
          await client.publish([effectiveAudioTrack, filteredTrack]);
        } else if (videoTrackFromAgora) {
          if (previewRef.current) videoTrackFromAgora.play(previewRef.current);
          await client.publish([effectiveAudioTrack, videoTrackFromAgora]);
        }
      }

      setStreamId(docRef.id);
      setIsLive(true);
    } catch (err) {
      console.error(err);
    } finally {
      setStarting(false);
    }
  };

  const endStream = async () => {
    if (!streamId || !user) return;
    audioTrackRef.current?.stop(); audioTrackRef.current?.close();
    filterCanvasRef.current?.stop(); filterCanvasRef.current = null;
    audioEffectRef.current?.close(); audioEffectRef.current = null;
    await clientRef.current?.leave();
    await updateDoc(doc(db, 'streams', streamId), { status: 'ended', endedAt: serverTimestamp() });

    // Credit estimated earnings to the streamer's lifetime total
    const sessionEarnings = sessionImpressions * 0.025 + sessionAffiliateClicks * 0.10;
    await updateDoc(doc(db, 'users', user.uid), {
      isLive: false,
      ...(sessionEarnings > 0 && { estimatedEarningsUsd: increment(sessionEarnings) }),
    });

    setIsLive(false);
    setStreamId(null);
    setUplinkQuality(0);
    setSessionProductCount(0);
    setSessionImpressions(0);
    setSessionAffiliateClicks(0);
  };

  if (!user) return null;

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Creator Studio</h1>
        <Link href="/studio/ads" className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-sm text-white/70 hover:text-white rounded-lg transition">
          📢 Manage Ads
        </Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Preview + controls */}
        <div className="lg:col-span-2 space-y-4">

          {/* Preview — Snap AR / Compositor / Raw camera */}
          {snapEnabled ? (
            <div className="relative aspect-video bg-black rounded-xl overflow-hidden">
              <div ref={snapPreviewContainerRef} className="w-full h-full" />
              {snapLoading && (
                <div className="absolute inset-0 flex items-center justify-center bg-black/60">
                  <div className="flex flex-col items-center gap-3">
                    <div className="w-8 h-8 border-2 border-[#FFFC00] border-t-transparent rounded-full animate-spin" />
                    <span className="text-xs text-white/60">Loading Camera Kit…</span>
                  </div>
                </div>
              )}
              <div className="absolute top-3 left-3 flex items-center gap-2">
                <div className="px-2 py-1 bg-[#FFFC00] text-black text-xs font-bold rounded">AR</div>
                <div className="px-2 py-1 bg-black/60 text-white text-xs font-semibold rounded">Snap Camera Kit</div>
              </div>
              {isLive && (
                <div className="absolute top-3 right-3 flex items-center gap-2">
                  <SignalBadge quality={uplinkQuality} />
                  <span className="px-3 py-1 bg-[#FF7043] text-white text-sm font-bold rounded-full animate-pulse">● LIVE</span>
                </div>
              )}
              <ScanButton scanning={scanning} continuous={continuousScan} onScan={() => handleScan(false)} onToggleContinuous={() => setContinuousScan(c => !c)} />
              <ProductDrawer products={detectedProducts} featuredAd={featuredAd} onClose={dismissProducts} onAffiliateClick={() => setSessionAffiliateClicks(c => c + 1)} />
            </div>
          ) : useCompositor ? (
            <div className="relative">
              <RoomCompositorView
                ref={compositorRef}
                localVideoElement={localVideoElRef.current}
                localUid={user.uid}
                backgroundId={selectedBgId}
                filterId={filterId}
              />
              {isLive && (
                <div className="absolute top-3 right-3 flex items-center gap-2 z-10">
                  <SignalBadge quality={uplinkQuality} />
                  <span className="px-3 py-1 bg-[#FF7043] text-white text-sm font-bold rounded-full animate-pulse">● LIVE</span>
                </div>
              )}
              <ScanButton scanning={scanning} continuous={continuousScan} onScan={() => handleScan(false)} onToggleContinuous={() => setContinuousScan(c => !c)} />
              <ProductDrawer products={detectedProducts} featuredAd={featuredAd} onClose={dismissProducts} onAffiliateClick={() => setSessionAffiliateClicks(c => c + 1)} />
            </div>
          ) : (
            <div className="relative aspect-video bg-zinc-950 rounded-xl overflow-hidden">
              <div
                ref={previewRef}
                className="w-full h-full"
                style={{ filter: filterId !== 'none' ? (VIDEO_FILTERS.find(f => f.id === filterId)?.css ?? '') : undefined }}
              />
              {isLive && (
                <div className="absolute top-4 left-4 flex items-center gap-3">
                  <span className="px-3 py-1 bg-[#FF7043] text-white text-sm font-bold rounded-full animate-pulse">● LIVE</span>
                  <span className="px-3 py-1 bg-black/60 text-white text-sm rounded-full">
                    👁 {stream?.viewerCount ?? 0}
                  </span>
                  <span className="px-3 py-1 bg-black/60 text-yellow-400 text-sm rounded-full">
                    🎁 {stream?.totalGifts ?? 0}
                  </span>
                </div>
              )}
              {isLive && (
                <div className="absolute top-4 right-4">
                  <SignalBadge quality={uplinkQuality} />
                </div>
              )}
              <ScanButton scanning={scanning} continuous={continuousScan} onScan={() => handleScan(false)} onToggleContinuous={() => setContinuousScan(c => !c)} />
              <ProductDrawer products={detectedProducts} featuredAd={featuredAd} onClose={dismissProducts} onAffiliateClick={() => setSessionAffiliateClicks(c => c + 1)} />
            </div>
          )}

          {/* Stream setup */}
          {!isLive ? (
            <div className="bg-zinc-900 rounded-xl p-6 space-y-4">
              <FilterPicker selected={filterId} onSelect={setFilterId} />
              <AudioEffectPicker selected={audioEffectId} onSelect={setAudioEffectId} />
              <div>
                <label className="text-sm text-white/50 mb-1 block">Stream Title</label>
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="What are you streaming today?"
                  className="w-full bg-white/10 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:outline-none focus:border-[#FF7043] transition"
                />
              </div>
              <div>
                <label className="text-sm text-white/50 mb-2 block">Category</label>
                <div className="flex flex-wrap gap-2">
                  {CATEGORIES.map((cat) => (
                    <button
                      key={cat}
                      onClick={() => setCategory(cat)}
                      className={`px-4 py-2 rounded-full text-sm font-medium transition ${category === cat ? 'bg-[#FF7043] text-white' : 'bg-white/10 text-white/60 hover:bg-white/20'}`}
                    >
                      {cat}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-sm text-white/50 mb-2 block">Stream Quality</label>
                <div className="flex gap-2 flex-wrap">
                  {(Object.entries(QUALITY_PRESETS) as [QualityPresetKey, typeof QUALITY_PRESETS[QualityPresetKey]][]).map(([key, p]) => (
                    <button
                      key={key}
                      onClick={() => setQualityPreset(key)}
                      className={`px-3 py-1.5 rounded-full text-xs font-semibold transition ${qualityPreset === key ? 'bg-[#FFD166] text-black' : 'bg-white/10 text-white/60 hover:bg-white/20'}`}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>
                <p className="text-[10px] text-white/30 mt-1.5">
                  {QUALITY_PRESETS[qualityPreset].width}×{QUALITY_PRESETS[qualityPreset].height} · {QUALITY_PRESETS[qualityPreset].frameRate}fps · up to {QUALITY_PRESETS[qualityPreset].bitrateMax}kbps
                </p>
              </div>
              <button
                onClick={startStream}
                disabled={starting || !title.trim()}
                className="w-full py-4 bg-[#FF7043] hover:bg-[#e55a2b] disabled:opacity-50 rounded-xl font-bold text-lg transition flex items-center justify-center gap-2"
              >
                {starting
                  ? <><div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" /> Starting...</>
                  : <><span>📡</span> Go Live</>
                }
              </button>
            </div>
          ) : (
            <button onClick={endStream} className="w-full py-4 bg-red-600 hover:bg-red-700 rounded-xl font-bold text-lg transition">
              End Stream
            </button>
          )}

          {/* Snap AR Lenses — collapsible */}
          {!isLive && (
            <div className="bg-zinc-900 rounded-xl overflow-hidden">
              <div className="flex items-center gap-3 px-4 py-3">
                <div
                  onClick={() => { const next = !snapEnabled; setSnapEnabled(next); if (next) { setVirtualBg(false); setRoomMode(false); } }}
                  className={`relative w-11 h-6 rounded-full transition-colors cursor-pointer shrink-0 ${snapEnabled ? 'bg-[#FFFC00]' : 'bg-white/20'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${snapEnabled ? 'translate-x-6' : 'translate-x-1'}`} />
                </div>
                <div className="flex items-center gap-2 flex-1">
                  <span className="text-sm font-medium">AR Lenses</span>
                  <span className="px-1.5 py-0.5 bg-[#FFFC00] text-black text-[10px] font-bold rounded">Snap</span>
                </div>
                <button onClick={() => setSnapPanelOpen(o => !o)} className="text-white/40 hover:text-white/70 text-xs px-1 transition">
                  {snapPanelOpen ? '▲' : '▼'}
                </button>
              </div>
              {snapPanelOpen && (
                <div className="px-4 pb-4 space-y-3 border-t border-white/10 pt-3">
                  {snapEnabled && !SNAP_API_TOKEN && (
                    <p className="text-xs text-amber-400/80 bg-amber-400/10 rounded-lg px-3 py-2">
                      Add <code className="font-mono">NEXT_PUBLIC_SNAP_API_TOKEN</code> and <code className="font-mono">NEXT_PUBLIC_SNAP_LENS_GROUP_ID</code> to <code className="font-mono">.env.local</code> to use Camera Kit lenses.
                    </p>
                  )}
                  {snapEnabled && SNAP_API_TOKEN && (
                    <LensPicker lenses={snapLenses} selected={selectedLensId} onSelect={setSelectedLensId} loading={snapLoading} />
                  )}
                  {!snapEnabled && <p className="text-xs text-white/30">Enable the toggle to activate AR lenses.</p>}
                </div>
              )}
            </div>
          )}

          {/* Virtual Background + Room Mode — collapsible */}
          {!isLive && (
            <div className={`bg-zinc-900 rounded-xl overflow-hidden ${snapEnabled ? 'opacity-40 pointer-events-none' : ''}`}>
              <div className="flex items-center gap-3 px-4 py-3">
                <div
                  onClick={() => { const next = !virtualBg; setVirtualBg(next); if (!next) setRoomMode(false); }}
                  className={`relative w-11 h-6 rounded-full transition-colors cursor-pointer shrink-0 ${virtualBg ? 'bg-[#FF7043]' : 'bg-white/20'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${virtualBg ? 'translate-x-6' : 'translate-x-1'}`} />
                </div>
                <span className="text-sm font-medium flex-1">Virtual Background</span>
                <button onClick={() => setBgPanelOpen(o => !o)} className="text-white/40 hover:text-white/70 text-xs px-1 transition">
                  {bgPanelOpen ? '▲' : '▼'}
                </button>
              </div>
              {bgPanelOpen && (
                <div className="px-4 pb-4 space-y-3 border-t border-white/10 pt-3">
                  {virtualBg ? (
                    <>
                      <RoomPicker selected={selectedBgId} onSelect={(bg) => setSelectedBgId(bg.id)} />
                      <label className="flex items-center gap-3 cursor-pointer select-none pt-1 border-t border-white/10">
                        <div
                          onClick={() => setRoomMode(!roomMode)}
                          className={`relative w-11 h-6 rounded-full transition-colors ${roomMode ? 'bg-[#FFD166]' : 'bg-white/20'}`}
                        >
                          <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${roomMode ? 'translate-x-6' : 'translate-x-1'}`} />
                        </div>
                        <div>
                          <p className="text-sm font-medium">Room Mode</p>
                          <p className="text-xs text-white/40">Co-hosts appear in the same virtual space</p>
                        </div>
                      </label>
                    </>
                  ) : (
                    <p className="text-xs text-white/30">Enable the toggle to choose a background.</p>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Live Captions toggle */}
          <div className="bg-zinc-900 rounded-xl px-4 py-3">
            <div className="flex items-center gap-3">
              <div
                onClick={() => captionsSupported && setCaptionsEnabled(e => !e)}
                className={`relative w-11 h-6 rounded-full transition-colors shrink-0 ${
                  !captionsSupported ? 'bg-white/10 cursor-not-allowed'
                    : captionsEnabled ? 'bg-[#FF7043] cursor-pointer' : 'bg-white/20 cursor-pointer'
                }`}
              >
                <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${captionsEnabled ? 'translate-x-6' : 'translate-x-1'}`} />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium flex items-center gap-2">
                  Live Captions
                  {captionsEnabled && isLive && (
                    <span className="text-[10px] bg-emerald-500/20 text-emerald-400 px-1.5 py-0.5 rounded-full font-semibold">REC</span>
                  )}
                </p>
                <p className="text-[10px] text-white/40">
                  {!captionsSupported
                    ? 'Not supported in this browser (Chrome/Edge/Safari only)'
                    : 'Auto-transcribes speech + detects spoken product names'}
                </p>
              </div>
            </div>
            {isLive && captionsEnabled && currentCaption && (
              <div className="mt-2 px-2 py-1.5 bg-black/40 rounded text-xs text-white/80 italic">
                {currentCaption}
              </div>
            )}
          </div>
        </div>

        {/* Right: Earnings + Chat + Co-host panel */}
        <div className="space-y-4">
          {isLive && (
            <div className="bg-zinc-900 rounded-xl p-4 space-y-3">
              <p className="text-[10px] font-semibold text-white/40 uppercase tracking-wider">Session Earnings</p>
              <div className="grid grid-cols-3 gap-2 text-center">
                <div>
                  <p className="text-xl font-bold text-white">{sessionProductCount}</p>
                  <p className="text-[10px] text-white/40 mt-0.5">Products</p>
                </div>
                <div>
                  <p className="text-xl font-bold text-white">{sessionImpressions}</p>
                  <p className="text-[10px] text-white/40 mt-0.5">Ad Matches</p>
                </div>
                <div>
                  <p className="text-xl font-bold text-white">{sessionAffiliateClicks}</p>
                  <p className="text-[10px] text-white/40 mt-0.5">Affiliate Clicks</p>
                </div>
              </div>
              <div className="border-t border-white/10 pt-3 flex items-center justify-between">
                <p className="text-xs text-white/40">Est. session value</p>
                <p className="text-lg font-bold text-[#FF7043]">
                  ${(sessionImpressions * 0.025 + sessionAffiliateClicks * 0.10).toFixed(2)}
                </p>
              </div>
              <p className="text-[10px] text-white/20">Based on $25 CPM floor. Actual payouts vary.</p>
            </div>
          )}
          {isLive && streamId && (
            <div className="bg-zinc-900 rounded-xl p-4 space-y-4">
              <CohostInvite streamId={streamId} hostUsername={user.username} cohosts={cohosts} />
            </div>
          )}
          {isLive && (
            <div className="bg-zinc-900 rounded-xl flex flex-col" style={{ height: 360 }}>
              <div className="px-4 py-3 border-b border-white/10 font-semibold text-sm">Live Chat</div>
              <div className="flex-1 overflow-y-auto p-4 space-y-2">
                {messages.map((msg) => (
                  <div key={msg.id} className="text-sm">
                    <span className={`font-semibold ${msg.type === 'gift' ? 'text-yellow-400' : 'text-[#FFD166]'}`}>
                      {msg.authorUsername}
                    </span>{' '}
                    <span className="text-white/80">{msg.text}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function SignalBadge({ quality }: { quality: number }) {
  const bars = [1, 2, 3, 4];
  const color = quality === 0 ? '#666' : quality <= 2 ? '#22c55e' : quality <= 3 ? '#eab308' : '#ef4444';
  const filled = quality === 0 ? 0 : quality <= 2 ? 4 : quality <= 3 ? 2 : quality <= 5 ? 1 : 0;
  const label = quality === 0 ? '–' : quality <= 2 ? 'Good' : quality <= 3 ? 'Fair' : quality <= 5 ? 'Poor' : 'Down';
  return (
    <div className="flex items-center gap-1.5 px-2 py-1 bg-black/60 rounded-full">
      <div className="flex items-end gap-px h-3">
        {bars.map((b) => (
          <div key={b} style={{ height: `${b * 25}%`, backgroundColor: b <= filled ? color : '#444', width: 3, borderRadius: 1 }} />
        ))}
      </div>
      <span className="text-[10px] font-semibold" style={{ color }}>{label}</span>
    </div>
  );
}

function ScanButton({ scanning, continuous, onScan, onToggleContinuous }: {
  scanning: boolean;
  continuous: boolean;
  onScan: () => void;
  onToggleContinuous: () => void;
}) {
  return (
    <div className="absolute bottom-4 right-4 flex items-center gap-2">
      {/* Manual scan */}
      <button
        onClick={onScan}
        disabled={scanning}
        className="flex items-center gap-1.5 px-3 py-2 bg-black/70 hover:bg-black/90 disabled:opacity-60 backdrop-blur-sm border border-white/20 rounded-xl text-white text-xs font-semibold transition"
      >
        {scanning
          ? <><div className="w-3 h-3 border border-white border-t-transparent rounded-full animate-spin" /> Scanning…</>
          : <>🔍 Scan</>
        }
      </button>

      {/* Continuous toggle */}
      <button
        onClick={onToggleContinuous}
        className={`flex items-center gap-1.5 px-3 py-2 backdrop-blur-sm border rounded-xl text-xs font-semibold transition ${
          continuous
            ? 'bg-[#FF7043]/80 border-[#FF7043] text-white'
            : 'bg-black/70 hover:bg-black/90 border-white/20 text-white/70'
        }`}
      >
        {continuous
          ? <><div className="w-2 h-2 rounded-full bg-white animate-pulse" /> Auto On</>
          : <>⟳ Auto</>
        }
      </button>
    </div>
  );
}
