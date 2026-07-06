'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth-store';
import { db, rtdb } from '@/lib/firebase';
import { collection, addDoc, doc, getDoc, updateDoc, serverTimestamp, increment } from 'firebase/firestore';
import { ref as rtdbRef, set as rtdbSet, remove as rtdbRemove } from 'firebase/database';
import { CaptionEngine, isCaptionSupported } from '@/lib/speech/caption-engine';
import { useDanmaku, useSingleStream } from '@/hooks/use-live-stream';
import { useCohosts } from '@/hooks/use-cohosts';
import { CohostInvite } from '@/components/live/cohost-invite';
import { FilterPicker } from '@/components/live/filter-picker';
import { AudioEffectPicker } from '@/components/live/audio-effect-picker';
import { ProductDrawer } from '@/components/live/product-drawer';
import { GiftGoalBar } from '@/components/live/gift-goal-bar';
import { PostStreamEditor } from '@/components/studio/post-stream-editor';
import { AudioEffectPipeline } from '@/lib/audio/audio-effects';
import { scanBarcodeFromVideo } from '@/lib/product-scanner/barcode-scanner';
import { lookupBarcode } from '@/lib/product-scanner/product-lookup';
import { captureFingerprint, fingerprintDiff, SCENE_CHANGE_THRESHOLD } from '@/lib/product-scanner/frame-fingerprint';
import type { ProductInfo, Ad } from '@/lib/types';
import { matchAd } from '@/hooks/use-ads';
import { VIDEO_FILTERS } from '@/lib/compositing/video-filters';
import { FilterCanvas } from '@/lib/compositing/filter-canvas';
import { ROOM_BACKGROUNDS } from '@/lib/room-backgrounds';
import AgoraRTC, { ILocalAudioTrack, ICameraVideoTrack, ILocalVideoTrack, IAgoraRTCRemoteUser } from 'agora-rtc-sdk-ng';
import VirtualBackgroundExtension, { IVirtualBackgroundProcessor } from 'agora-extension-virtual-background';
import { ATTRIBUTE_LABELS, dayKey, type Game, type GameResult } from '@/lib/games';
import { useGamesCatalog } from '@/hooks/use-games-catalog';
import { useIsAdmin } from '@/hooks/use-is-admin';
import { completeGameTask } from '@/lib/game-progress';
import { GamePlayer } from '@/components/games/game-player';

// Must match _kScreenShareUid (Flutter) + SCREEN_SHARE_UID (live-view): the
// in-stream game is published on a 2nd Agora connection under this uid.
const WEB_SCREEN_SHARE_UID = 424242;

const QUALITY_PRESETS = {
  '480p':   { label: '480p',       width: 854,  height: 480,  frameRate: 30, bitrateMax: 1500, bitrateMin: 300  },
  '720p':   { label: '720p HD',    width: 1280, height: 720,  frameRate: 30, bitrateMax: 3000, bitrateMin: 600  },
  '720p60': { label: '720p 60fps', width: 1280, height: 720,  frameRate: 60, bitrateMax: 4500, bitrateMin: 1000 },
  '1080p':  { label: '1080p Full HD', width: 1920, height: 1080, frameRate: 30, bitrateMax: 5000, bitrateMin: 1000 },
} as const;
type QualityPresetKey = keyof typeof QUALITY_PRESETS;

const AGORA_APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? '';
const CATEGORIES = ['General', 'Gaming', 'Music', 'IRL', 'Sports', 'Cooking', 'Education'];

// Loaded HTMLImageElements for Room Mode are kept here so toggling between
// rooms doesn't re-fetch the JPG every time. The Agora VB extension requires
// a fully-decoded Image (img.complete === true) — we await img.decode() once
// per URL and reuse from cache afterwards.
const roomImageCache = new Map<string, HTMLImageElement>();
async function loadRoomImage(url: string): Promise<HTMLImageElement> {
  const cached = roomImageCache.get(url);
  if (cached) return cached;
  const img = new Image();
  img.crossOrigin = 'anonymous';
  img.src = url;
  await img.decode();
  roomImageCache.set(url, img);
  return img;
}

export default function StudioView() {
  const { user } = useAuthStore();
  const gamesCatalog = useGamesCatalog();
  const isAdmin = useIsAdmin();
  const router = useRouter();
  const [isLive, setIsLive] = useState(false);
  const [streamId, setStreamId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('General');
  const [starting, setStarting] = useState(false);
  // Room Mode — host's camera background is replaced with the chosen
  // preset's solid colour via Agora's virtual-background extension.
  // Mirrors flutter_app's _roomMode + _selectedBgId.
  const [roomMode, setRoomMode] = useState(false);
  const [selectedBgId, setSelectedBgId] = useState('modern_studio');
  const [roomPanelOpen, setRoomPanelOpen] = useState(false);
  // Gift goal (optional) — label + coin target set before going live.
  const [giftGoalLabel, setGiftGoalLabel] = useState('');
  const [giftGoalTargetInput, setGiftGoalTargetInput] = useState('');
  const giftGoalTarget = parseInt(giftGoalTargetInput, 10) || 0;
  // Single VB processor, piped onto the preview camera track by the Room Mode
  // toggle effect. That same track is what gets published, so this one
  // processor composites the background for both preview and broadcast.
  const vbProcessorRef = useRef<IVirtualBackgroundProcessor | null>(null);
  // Flips true once processor.init() resolves. The Room Mode toggle effect
  // depends on it so it re-pipes when the processor becomes ready — otherwise
  // toggling Room Mode before init finishes would silently never apply.
  const [vbReady, setVbReady] = useState(false);
  const previewVideoTrackRef = useRef<ICameraVideoTrack | null>(null);
  const [filterId, setFilterId] = useState('none');
  const filterCanvasRef = useRef<FilterCanvas | null>(null);
  const [audioEffectId, setAudioEffectId] = useState('none');
  const audioEffectRef = useRef<AudioEffectPipeline | null>(null);

  const [qualityPreset, setQualityPreset] = useState<QualityPresetKey>('720p');
  const [uplinkQuality, setUplinkQuality] = useState(0);

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

  // Raw camera preview (used in normal + compositor mode)
  const previewRef = useRef<HTMLDivElement>(null);
  const localVideoElRef = useRef<HTMLVideoElement | null>(null);
  // Where the co-host's remote video gets attached when they join. Null
  // when no co-host is publishing; a ref to a div otherwise. The host
  // doesn't auto-subscribe to other broadcasters in Agora's model, so we
  // subscribe explicitly in the user-published handler.
  const cohostRef = useRef<HTMLDivElement>(null);
  const [cohostUid, setCohostUid] = useState<string | number | null>(null);

  const clientRef = useRef<ReturnType<typeof AgoraRTC.createClient> | null>(null);
  const audioTrackRef = useRef<ILocalAudioTrack | null>(null);

  // In-stream game (W4): the game is published on a SECOND Agora client under
  // WEB_SCREEN_SHARE_UID via a screen-share track; the camera client is
  // untouched. Viewers render that uid full-screen (3b/W3).
  const [activeGame, setActiveGame] = useState<Game | null>(null);
  const [showGamePicker, setShowGamePicker] = useState(false);
  const [gameResultMsg, setGameResultMsg] = useState<string | null>(null);
  const screenClientRef = useRef<ReturnType<typeof AgoraRTC.createClient> | null>(null);
  const screenTrackRef = useRef<ILocalVideoTrack | null>(null);
  const activeGameRef = useRef<Game | null>(null);

  // Clip recording — capture the broadcast via MediaRecorder, then hand the
  // blob to the post-stream editor before publishing to the feed.
  const [recording, setRecording] = useState(false);
  const [clipMsg, setClipMsg] = useState<string | null>(null);
  const [editorBlob, setEditorBlob] = useState<Blob | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const recordedChunksRef = useRef<Blob[]>([]);

  const stream = useSingleStream(streamId);
  const messages = useDanmaku(streamId ?? '');
  const cohosts = useCohosts(streamId ?? '');

  useEffect(() => {
    if (!user) router.push('/login');
  }, [user, router]);

  // Register the Agora virtual-background extension once. The same extension
  // singleton is shared across all video tracks the page creates (preview +
  // the published track once Go Live is tapped).
  //
  // The extension's enable/disable/setOptions are sync-void (not Promise);
  // only init() returns a Promise. Mixing them needs try/catch instead of
  // .catch() chains — getting that wrong was an earlier runtime crash.
  useEffect(() => {
    const ext = new VirtualBackgroundExtension();
    AgoraRTC.registerExtensions([ext]);
    const processor = ext.createProcessor();
    processor.init().then(() => {
      vbProcessorRef.current = processor;
      setVbReady(true);
    }).catch((e) => console.warn('VB extension init failed', e));
    return () => {
      vbProcessorRef.current = null;
      setVbReady(false);
      try { processor.disable(); } catch { /* extension teardown — ignore */ }
    };
  }, []);

  // Agora camera preview
  useEffect(() => {
    let videoTrack: ICameraVideoTrack | undefined;
    AgoraRTC.createCameraVideoTrack().then((track) => {
      videoTrack = track;
      previewVideoTrackRef.current = track;
      if (previewRef.current) {
        track.play(previewRef.current);
        const el = previewRef.current.querySelector('video');
        if (el) localVideoElRef.current = el;
      }
    }).catch(() => {});
    return () => {
      previewVideoTrackRef.current = null;
      videoTrack?.stop();
      videoTrack?.close();
    };
  }, []);

  // Toggle the virtual background processor on the preview track whenever
  // Room Mode is enabled/disabled or the chosen background changes. The
  // exact same processor will be carried over to the published track in
  // startStream so what the host sees is what viewers see.
  useEffect(() => {
    const processor = vbProcessorRef.current;
    const track = previewVideoTrackRef.current;
    if (!processor || !track) return;
    if (!roomMode) {
      try { processor.disable(); track.unpipe(); } catch (e) {
        console.warn('Room Mode disable failed', e);
      }
      return;
    }
    // Guard against a superseded run (deps changed mid-await) piping after a
    // newer run already unpiped — without this the async pipe could land after
    // teardown and leave the track in the wrong state.
    let cancelled = false;
    // Async because the JPG has to be fetched + decoded before the processor
    // can use it. We fall back to a solid colour if the image fails to load
    // (e.g. file missing in dev) so the host still gets a noticeable change.
    (async () => {
      const bg = ROOM_BACKGROUNDS.find((b) => b.id === selectedBgId) ?? ROOM_BACKGROUNDS[0];
      try {
        const img = await loadRoomImage(bg.imageUrl);
        if (cancelled) return;
        processor.setOptions({ type: 'img', source: img });
      } catch (e) {
        if (cancelled) return;
        console.warn(`Room image failed (${bg.imageUrl}), falling back to colour`, e);
        processor.setOptions({ type: 'color', color: bg.color });
      }
      if (cancelled) return;
      try {
        processor.enable();
        track.pipe(processor).pipe(track.processorDestination);
      } catch (e) {
        console.warn('Room Mode toggle failed', e);
      }
    })();
    return () => { cancelled = true; };
  }, [roomMode, selectedBgId, vbReady]);


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
      const videoEl = localVideoElRef.current;
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
        giftGoalLabel: giftGoalTarget > 0 && giftGoalLabel.trim() ? giftGoalLabel.trim() : null,
        giftGoalTarget,
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

      // Co-host video — when a second broadcaster publishes, subscribe and
      // bind the remote video track to the cohostRef tile. Agora doesn't
      // auto-subscribe broadcasters to each other so we have to do this
      // explicitly. v1 supports a single co-host.
      client.on('user-published', async (remote: IAgoraRTCRemoteUser, mediaType: 'video' | 'audio') => {
        try {
          await client.subscribe(remote, mediaType);
        } catch (e: unknown) {
          if ((e as { code?: string })?.code !== 'OPERATION_ABORTED') console.error(e);
          return;
        }
        if (mediaType === 'video' && remote.videoTrack && cohostRef.current) {
          remote.videoTrack.play(cohostRef.current);
          setCohostUid(remote.uid);
        }
      });
      client.on('user-unpublished', (remote: IAgoraRTCRemoteUser) => {
        if (cohostUid === remote.uid) setCohostUid(null);
      });

      const preset = QUALITY_PRESETS[qualityPreset];

      // Microphone is always a fresh track. The video track is REUSED from the
      // preview (previewVideoTrackRef) rather than creating a second camera +
      // second VB processor. Agora's segmentation backend behaves like a
      // singleton — a second processor enables and pipes successfully but
      // passes frames through unmodified, so viewers saw the raw camera. One
      // camera + one processor (already piped by the Room Mode toggle effect)
      // is what actually composites the background onto the published stream.
      const audioTrack = await AgoraRTC.createMicrophoneAudioTrack();
      audioTrackRef.current = audioTrack;

      const videoTrack = previewVideoTrackRef.current;
      if (videoTrack) {
        try {
          await videoTrack.setEncoderConfiguration({
            width: preset.width, height: preset.height,
            frameRate: preset.frameRate,
            bitrateMax: preset.bitrateMax, bitrateMin: preset.bitrateMin,
          });
        } catch (e) {
          console.warn('setEncoderConfiguration failed', e);
        }
      }

      const rawMicStream = new MediaStream([audioTrack.getMediaStreamTrack()]);
      const audioPipeline = new AudioEffectPipeline(rawMicStream);
      audioPipeline.setEffect(audioEffectId);
      audioEffectRef.current = audioPipeline;
      const effectiveAudioTrack = audioEffectId !== 'none'
        ? AgoraRTC.createCustomAudioTrack({ mediaStreamTrack: audioPipeline.outputStream.getAudioTracks()[0] })
        : audioTrack;

      const customTrackOpts = { bitrateMax: preset.bitrateMax, bitrateMin: preset.bitrateMin, frameRate: preset.frameRate };

      const selectedFilter = VIDEO_FILTERS.find((f) => f.id === filterId);
      if (selectedFilter && selectedFilter.css !== 'none' && localVideoElRef.current) {
        // Filter path: capture the preview <video> element — which already
        // shows the VB-composited frames when Room Mode is on — through the
        // filter canvas, so a filter and Room Mode compose correctly.
        const fc = new FilterCanvas(localVideoElRef.current);
        fc.setFilter(selectedFilter);
        fc.start();
        filterCanvasRef.current = fc;
        const filteredTrack = AgoraRTC.createCustomVideoTrack({ mediaStreamTrack: fc.captureStream(preset.frameRate).getVideoTracks()[0], ...customTrackOpts });
        await client.publish([effectiveAudioTrack, filteredTrack]);
      } else if (videoTrack) {
        if (previewRef.current) videoTrack.play(previewRef.current);
        await client.publish([effectiveAudioTrack, videoTrack]);
      }

      setStreamId(docRef.id);
      setIsLive(true);
    } catch (err) {
      console.error(err);
    } finally {
      setStarting(false);
    }
  };

  // ── Clip recording ──────────────────────────────────────────────────────
  // Capture the broadcast (the preview <video>, which shows the published
  // frame incl. Room Mode/filters, + the mic) via MediaRecorder.
  const startClipRecording = () => {
    const videoEl = localVideoElRef.current as
      (HTMLVideoElement & { captureStream?: () => MediaStream }) | null;
    if (!videoEl || !videoEl.captureStream) {
      setClipMsg('Recording is not supported in this browser.');
      return;
    }
    try {
      const captured = videoEl.captureStream();
      const micTrack = audioTrackRef.current?.getMediaStreamTrack();
      const stream = new MediaStream([
        ...captured.getVideoTracks(),
        ...(micTrack ? [micTrack] : []),
      ]);
      const mime = ['video/webm;codecs=vp9,opus', 'video/webm;codecs=vp8,opus', 'video/webm']
        .find((m) => MediaRecorder.isTypeSupported(m)) ?? 'video/webm';
      // Cap the recording bitrate so the .webm we upload stays small. Without a
      // cap MediaRecorder picks a high default (often 5-8 Mbps), which makes the
      // upload slow; ~2.5 Mbps video + 128 kbps audio is plenty for 1080p social
      // clips. The server (transcodeClipToMp4) re-encodes to mp4 afterwards.
      const rec = new MediaRecorder(stream, {
        mimeType: mime,
        videoBitsPerSecond: 2_500_000,
        audioBitsPerSecond: 128_000,
      });
      recordedChunksRef.current = [];
      rec.ondataavailable = (e) => { if (e.data.size > 0) recordedChunksRef.current.push(e.data); };
      rec.onstop = () => { void finalizeClip(); };
      rec.start(1000);
      mediaRecorderRef.current = rec;
      setRecording(true);
      setClipMsg(null);
    } catch (e) {
      console.error('startClipRecording failed', e);
      setClipMsg('Could not start recording.');
    }
  };

  const stopClipRecording = () => {
    try { mediaRecorderRef.current?.stop(); } catch { /* already stopped */ }
    setRecording(false);
  };

  // On stop, assemble the blob and open the post-stream editor (which handles
  // effects, thumbnail, and publishing).
  const finalizeClip = () => {
    const chunks = recordedChunksRef.current;
    recordedChunksRef.current = [];
    if (chunks.length === 0) return;
    const videoBlob = new Blob(chunks, { type: mediaRecorderRef.current?.mimeType || 'video/webm' });
    setEditorBlob(videoBlob);
  };

  // Start a game live: publish it on a 2nd Agora client via screen-share (the
  // browser prompts the streamer to pick the tab/window showing the game).
  const startWebGame = async (game: Game) => {
    if (!streamId || activeGameRef.current) return;
    setShowGamePicker(false);
    let screenTrack: ILocalVideoTrack;
    try {
      screenTrack = (await AgoraRTC.createScreenVideoTrack({ optimizationMode: 'detail' }, 'disable')) as ILocalVideoTrack;
    } catch {
      return; // streamer cancelled the share picker
    }
    screenTrackRef.current = screenTrack;
    setActiveGame(game);
    activeGameRef.current = game;
    try {
      const sc = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
      screenClientRef.current = sc;
      await sc.setClientRole('host');
      await sc.join(AGORA_APP_ID, streamId, null, WEB_SCREEN_SHARE_UID);
      await sc.publish([screenTrack]);
      await updateDoc(doc(db, 'streams', streamId), {
        gameActive: true, gameScreenUid: WEB_SCREEN_SHARE_UID, activeGameName: game.name,
      });
      // If the streamer stops sharing via the browser bar, end the game.
      screenTrack.on('track-ended', () => endWebGame({ score: 0, success: false }));
    } catch {
      try { screenTrack.close(); } catch {}
      screenTrackRef.current = null;
      screenClientRef.current = null;
      setActiveGame(null);
      activeGameRef.current = null;
    }
  };

  const endWebGame = async (result: GameResult) => {
    const game = activeGameRef.current;
    const st = screenTrackRef.current;
    const sc = screenClientRef.current;
    screenTrackRef.current = null;
    screenClientRef.current = null;
    activeGameRef.current = null;
    setActiveGame(null);
    try { st?.close(); } catch {}
    try { await sc?.leave(); } catch {}
    if (streamId) {
      try {
        await updateDoc(doc(db, 'streams', streamId), { gameActive: false, gameScreenUid: null, activeGameName: null });
      } catch {}
    }
    if (game && result.success && user) {
      try {
        const snap = await getDoc(doc(db, 'users', user.uid));
        const d = snap.data() ?? {};
        const done = (d.gameTasksDate as string) === dayKey(new Date()) ? ((d.gameTasksDone as string[]) ?? []) : [];
        await completeGameTask({ uid: user.uid, game, doneToday: done });
      } catch {}
    }
    if (game) {
      setGameResultMsg(result.success
        ? `⚡ Cleared! +${game.rewardPoints} ${ATTRIBUTE_LABELS[game.attribute] ?? game.attribute}`
        : `Game over — score ${result.score}/${game.successScore}`);
    }
  };

  const endStream = async () => {
    if (!streamId || !user) return;
    if (activeGameRef.current) await endWebGame({ score: 0, success: false });
    if (recording) stopClipRecording();
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
        <div className="flex gap-2">
          {isAdmin && (
            <Link href="/studio/games" className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-sm text-white/70 hover:text-white rounded-lg transition">
              🎮 Game Catalog
            </Link>
          )}
          <Link href="/studio/ads" className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-sm text-white/70 hover:text-white rounded-lg transition">
            📢 Manage Ads
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Preview + controls */}
        <div className="lg:col-span-2 space-y-4">

          {/* Preview — raw camera. Splits 50/50 side-by-side when a co-host
              has joined and is publishing. cohostRef is always mounted (just
              hidden until a co-host joins) so the user-published handler can
              call .play() into it BEFORE setCohostUid flips the layout —
              otherwise the ref would be null and we'd never set the uid. */}
          <div className="relative aspect-video bg-zinc-950 rounded-xl overflow-hidden">
              <div className={`w-full h-full ${cohostUid ? 'flex flex-row' : ''}`}>
                <div
                  ref={previewRef}
                  className={cohostUid ? 'flex-1 min-w-0' : 'w-full h-full'}
                  style={{ filter: filterId !== 'none' ? (VIDEO_FILTERS.find(f => f.id === filterId)?.css ?? '') : undefined }}
                />
                {cohostUid && <div className="w-0.5 bg-white/20 shrink-0" />}
                <div ref={cohostRef} className={cohostUid ? 'flex-1 min-w-0' : 'hidden'} />
              </div>
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
              {isLive && stream && (
                <div className="absolute top-16 left-4">
                  <GiftGoalBar stream={stream} />
                </div>
              )}
              <ScanButton scanning={scanning} continuous={continuousScan} onScan={() => handleScan(false)} onToggleContinuous={() => setContinuousScan(c => !c)} />
              <ProductDrawer products={detectedProducts} featuredAd={featuredAd} onClose={dismissProducts} onAffiliateClick={() => setSessionAffiliateClicks(c => c + 1)} />
          </div>

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
                <label className="text-sm text-white/50 mb-1 block">Gift Goal <span className="text-white/30">(optional)</span></label>
                <div className="flex gap-2">
                  <input
                    value={giftGoalLabel}
                    onChange={(e) => setGiftGoalLabel(e.target.value)}
                    placeholder="e.g. New mic"
                    className="flex-[3] min-w-0 bg-white/10 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:outline-none focus:border-[#FF7043] transition"
                  />
                  <input
                    value={giftGoalTargetInput}
                    onChange={(e) => setGiftGoalTargetInput(e.target.value.replace(/[^0-9]/g, ''))}
                    inputMode="numeric"
                    placeholder="🪙 target"
                    className="flex-[2] min-w-0 bg-white/10 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:outline-none focus:border-[#FF7043] transition"
                  />
                </div>
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
            <div className="space-y-3">
              {/* Record → edit → publish a clip of the broadcast to the feed */}
              <button
                onClick={recording ? stopClipRecording : startClipRecording}
                className="w-full py-3 rounded-xl font-bold transition flex items-center justify-center gap-2 bg-white/10 text-white hover:bg-white/20"
              >
                {recording ? (
                  <><span className="w-3 h-3 rounded-sm bg-red-500" /> Stop &amp; edit clip</>
                ) : (
                  <><span className="w-3 h-3 rounded-full bg-red-500 animate-pulse" /> Record clip</>
                )}
              </button>
              {clipMsg && <p className="text-xs text-center text-white/60">{clipMsg}</p>}
              <button
                onClick={() => setShowGamePicker(true)}
                disabled={!!activeGame}
                className="w-full py-3 rounded-xl font-bold transition flex items-center justify-center gap-2 disabled:opacity-50"
                style={{ backgroundColor: 'rgba(91,225,255,0.15)', color: '#5BE1FF', border: '1px solid rgba(91,225,255,0.5)' }}
              >
                🎮 Play a game live
              </button>
              <button onClick={endStream} className="w-full py-4 bg-red-600 hover:bg-red-700 rounded-xl font-bold text-lg transition">
                End Stream
              </button>
            </div>
          )}

          {/* Room Mode — virtual background. Mirrors Flutter's _roomMode UI:
              host toggles on, picks one of the four preset rooms, and the
              Agora virtual-background extension paints that solid colour
              behind them using on-device AI segmentation. */}
          {!isLive && (
            <div className="bg-zinc-900 rounded-xl overflow-hidden">
              <div className="flex items-center gap-3 px-4 py-3">
                <div
                  onClick={() => setRoomMode((r) => !r)}
                  className={`relative w-11 h-6 rounded-full transition-colors cursor-pointer shrink-0 ${
                    roomMode ? 'bg-[#FF7043]' : 'bg-white/20'
                  }`}
                >
                  <div
                    className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                      roomMode ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium">🏠 Room Mode</p>
                  <p className="text-xs text-white/40">Replace your background with a virtual room</p>
                </div>
                <button
                  onClick={() => setRoomPanelOpen((o) => !o)}
                  className="text-white/40 hover:text-white/70 text-xs px-1 transition"
                >
                  {roomPanelOpen ? '▲' : '▼'}
                </button>
              </div>
              {roomPanelOpen && roomMode && (
                <div className="px-4 pb-4 border-t border-white/10 pt-3">
                  <div className="grid grid-cols-4 gap-2">
                    {ROOM_BACKGROUNDS.map((bg) => (
                      <button
                        key={bg.id}
                        onClick={() => setSelectedBgId(bg.id)}
                        className={`aspect-square rounded-lg transition border-2 overflow-hidden bg-cover bg-center ${
                          selectedBgId === bg.id
                            ? 'border-[#FF7043]'
                            : 'border-transparent hover:border-white/30'
                        }`}
                        style={{
                          backgroundImage: `url(${bg.imageUrl}), linear-gradient(to bottom, ${bg.color}, #000)`,
                          backgroundColor: bg.color,
                        }}
                        title={bg.name}
                      >
                        <span className="block text-[10px] text-white text-center pt-1 px-1 truncate drop-shadow">
                          {bg.name}
                        </span>
                      </button>
                    ))}
                  </div>
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

      {editorBlob && user && (
        <PostStreamEditor
          blob={editorBlob}
          author={{ uid: user.uid, username: user.username, avatarUrl: user.avatarUrl }}
          defaultCaption={title.trim() || 'Live clip'}
          onClose={(published) => {
            setEditorBlob(null);
            setClipMsg(published ? 'Clip published to your feed 🎉' : null);
          }}
        />
      )}

      {/* Game picker — choose a game to play live (screen-shared to viewers). */}
      {showGamePicker && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/70" onClick={() => setShowGamePicker(false)}>
          <div className="rounded-2xl p-5 w-80 max-w-[90%]" style={{ backgroundColor: '#0A1430', border: '1px solid rgba(91,225,255,0.5)' }} onClick={(e) => e.stopPropagation()}>
            <p className="font-extrabold mb-1" style={{ color: '#CFE8FF' }}>🎮 Play a game live</p>
            <p className="text-[11px] text-[#6E86B0] mb-3">You&apos;ll pick the tab/window to share; viewers watch the game.</p>
            <div className="space-y-1.5 max-h-72 overflow-y-auto">
              {gamesCatalog.filter((g) => g.enabled !== false).map((g) => (
                <button key={g.id} onClick={() => startWebGame(g)} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left hover:bg-white/10 transition">
                  <span className="text-2xl">{g.emoji}</span>
                  <span className="flex-1 min-w-0">
                    <span className="block text-sm font-semibold" style={{ color: '#CFE8FF' }}>{g.name}</span>
                    <span className="block text-[11px] text-[#6E86B0]">{g.difficulty} · ⏱ {g.timeLimitSec}s · +{g.rewardPoints} {ATTRIBUTE_LABELS[g.attribute] ?? g.attribute}</span>
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Full-screen game overlay — the streamer plays here; screen-share captures it. */}
      {activeGame && (
        <div className="fixed inset-0 z-[80]" style={{ backgroundColor: '#0A1430' }}>
          <GamePlayer game={activeGame} onFinish={(r) => endWebGame(r)} />
        </div>
      )}

      {/* Result dialog */}
      {gameResultMsg && (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/60" onClick={() => setGameResultMsg(null)}>
          <div className="rounded-2xl p-6 max-w-xs text-center" style={{ backgroundColor: '#0A1430', border: '1px solid rgba(91,225,255,0.55)', color: '#CFE8FF' }}>
            <p className="mb-4">{gameResultMsg}</p>
            <button onClick={() => setGameResultMsg(null)} className="px-6 py-2 rounded-full font-bold" style={{ backgroundColor: '#5BE1FF', color: '#0A1430' }}>OK</button>
          </div>
        </div>
      )}
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
