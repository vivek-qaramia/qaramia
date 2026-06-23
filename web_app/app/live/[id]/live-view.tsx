'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useSingleStream, useDanmaku } from '@/hooks/use-live-stream';
import { useCohosts, usePendingCoHostInvite, acceptCoHostInvite, setCoHostActive, declineCoHostInvite } from '@/hooks/use-cohosts';
import { db, rtdb } from '@/lib/firebase';
import { doc, updateDoc, increment, collection, runTransaction, serverTimestamp, setDoc } from 'firebase/firestore';
import { ref as rtdbRef, push } from 'firebase/database';
import { useAuthStore } from '@/store/auth-store';
import { GiftType, Sponsorship, sponsorshipApplies, viewerCoinCost } from '@/lib/types';
import { useGiftCatalog } from '@/hooks/use-gift-catalog';
import { useActiveSponsorships } from '@/hooks/use-sponsorships';
import { useWallet } from '@/hooks/use-wallet';
import { ProductDrawer } from '@/components/live/product-drawer';
import { GiftPanel } from '@/components/live/gift-panel';
import { GiftGoalBar } from '@/components/live/gift-goal-bar';
import { GiftAnimationOverlay } from '@/components/live/gift-animation-overlay';
import { CaptionOverlay } from '@/components/live/caption-overlay';
import { TopGiftersBoard } from '@/components/live/top-gifters-board';
import AgoraRTC, { ILocalAudioTrack, ICameraVideoTrack } from 'agora-rtc-sdk-ng';

const AGORA_APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? '';

// Must match _kScreenShareUid in the Flutter go_live_screen — the host
// publishes the in-stream game (game + face PiP) on a second connection under
// this uid. Viewers render it full-screen while gameActive.
const SCREEN_SHARE_UID = 424242;

export default function LiveView({ streamId }: { streamId: string }) {
  const stream = useSingleStream(streamId);
  const messages = useDanmaku(streamId);
  const cohosts = useCohosts(streamId);
  const { user } = useAuthStore();

  const [chatInput, setChatInput] = useState('');
  const [showGifts, setShowGifts] = useState(false);
  const [isCoHost, setIsCoHost] = useState(false);
  const [insufficientCoins, setInsufficientCoins] = useState<number | null>(null);
  const [captionsOn, setCaptionsOn] = useState(true);
  const { wallet } = useWallet(user?.uid);
  const giftCatalog = useGiftCatalog();
  const sponsorships = useActiveSponsorships();

  // Persist caption preference per-viewer
  useEffect(() => {
    const stored = typeof window !== 'undefined' ? localStorage.getItem('qaramia-captions') : null;
    if (stored === '0') setCaptionsOn(false);
  }, []);
  useEffect(() => {
    if (typeof window !== 'undefined') localStorage.setItem('qaramia-captions', captionsOn ? '1' : '0');
  }, [captionsOn]);

  const clientRef = useRef<ReturnType<typeof AgoraRTC.createClient> | null>(null);
  // Two slots so the viewer can render a 50/50 split when the host AND a
  // co-host are both publishing. First broadcaster published lands in
  // hostVideoRef; the second in cohostVideoRef. Cleared on user-unpublished.
  const hostVideoRef = useRef<HTMLDivElement>(null);
  const cohostVideoRef = useRef<HTMLDivElement>(null);
  // Full-screen container for the host's in-stream game screen-share track.
  const gameVideoRef = useRef<HTMLDivElement>(null);
  const remoteSlotsRef = useRef<Map<string | number, 'host' | 'cohost'>>(new Map());
  const [cohostActive, setCohostActive] = useState(false);
  const coHostPreviewRef = useRef<HTMLDivElement>(null);
  const localVideoElRef = useRef<HTMLVideoElement | null>(null);
  const audioTrackRef = useRef<ILocalAudioTrack | null>(null);
  const localVideoTrackRef = useRef<ICameraVideoTrack | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const pendingInvite = usePendingCoHostInvite(user?.uid ?? '');
  const hasPendingInvite = pendingInvite?.streamId === streamId;

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);


  const agoraChannel = stream?.agoraChannel;

  useEffect(() => {
    // Only depend on the channel string (stable), not the whole stream object.
    // stream updates on every viewerCount/gift change which would cause rapid rejoin.
    // Do NOT depend on isCoHost — when the viewer accepts a co-host invite we
    // role-switch on the existing client and keep using it. Re-running this
    // effect would tear down the just-published broadcast.
    if (!agoraChannel) return;

    const client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
    clientRef.current = client;
    let left = false;

    client.setClientRole('audience').catch(() => {});

    client.on('user-published', async (remoteUser, mediaType) => {
      if (left) return;
      try {
        await client.subscribe(remoteUser, mediaType);
        if (mediaType !== 'video' || !remoteUser.videoTrack) return;
        // The in-stream game's screen-share (already has the face PiP composited
        // by MediaProjection) — render full-screen, not as a co-host tile.
        if (Number(remoteUser.uid) === SCREEN_SHARE_UID) {
          if (gameVideoRef.current) remoteUser.videoTrack.play(gameVideoRef.current);
          return;
        }
        const slots = remoteSlotsRef.current;
        let slot = slots.get(remoteUser.uid);
        if (!slot) {
          // First broadcaster fills the host tile; second fills the co-host
          // tile. A third would have nowhere to go in v1 — silently skip
          // and rely on the cohostActive split to remain consistent.
          slot = [...slots.values()].includes('host') ? 'cohost' : 'host';
          slots.set(remoteUser.uid, slot);
        }
        const target = slot === 'host' ? hostVideoRef.current : cohostVideoRef.current;
        if (target) remoteUser.videoTrack.play(target);
        if (slot === 'cohost') setCohostActive(true);
      } catch (e: unknown) {
        if ((e as { code?: string })?.code !== 'OPERATION_ABORTED') console.error(e);
      }
    });
    client.on('user-unpublished', (remoteUser) => {
      const slots = remoteSlotsRef.current;
      const slot = slots.get(remoteUser.uid);
      if (slot === 'cohost') setCohostActive(false);
      slots.delete(remoteUser.uid);
    });

    // Keep the join promise so cleanup can wait for it. Leaving a client whose
    // join is still in flight (StrictMode double-mount / Fast Refresh) orphans
    // the websocket, and its reconnect logic then fires ERR_REJOIN_NOT_JOINED
    // (2025). Awaiting join before leave avoids that.
    const joinPromise = client.join(AGORA_APP_ID, agoraChannel, null, null)
      .catch((e: unknown) => {
        if ((e as { code?: string })?.code !== 'OPERATION_ABORTED') console.error(e);
      });

    updateDoc(doc(db, 'streams', streamId), { viewerCount: increment(1) }).catch(() => {});

    return () => {
      left = true;
      updateDoc(doc(db, 'streams', streamId), { viewerCount: increment(-1) }).catch(() => {});
      try { audioTrackRef.current?.stop(); audioTrackRef.current?.close(); } catch { /* track may be unstarted — ignore */ }
      try { localVideoTrackRef.current?.stop(); localVideoTrackRef.current?.close(); } catch { /* track may be unstarted — ignore */ }
      audioTrackRef.current = null;
      localVideoTrackRef.current = null;
      joinPromise.then(() => client.leave()).catch(() => {});
    };
  }, [agoraChannel, streamId]);

  const handleAcceptInvite = async () => {
    if (!user || !stream) return;
    await acceptCoHostInvite(streamId, user.uid);

    const client = clientRef.current;
    if (client) {
      await client.setClientRole('host');
      const [audioTrack, videoTrack] = await AgoraRTC.createMicrophoneAndCameraTracks();
      audioTrackRef.current = audioTrack;
      localVideoTrackRef.current = videoTrack;

      // coHostPreviewRef is always mounted (hidden until isCoHost flips) so
      // the ref is attached before we publish — see the JSX below.
      if (coHostPreviewRef.current) {
        videoTrack.play(coHostPreviewRef.current);
        const el = coHostPreviewRef.current.querySelector('video');
        if (el) localVideoElRef.current = el;
      }

      await client.publish([audioTrack, videoTrack]);

      await setCoHostActive(streamId, user.uid);
      setIsCoHost(true);
    }
  };

  const handleDeclineInvite = async () => {
    if (!user) return;
    await declineCoHostInvite(streamId, user.uid);
  };

  const sendChat = async () => {
    const text = chatInput.trim();
    if (!text || !user) return;
    setChatInput('');
    await push(rtdbRef(rtdb, `danmaku/${streamId}`), {
      streamId, authorUid: user.uid, authorUsername: user.username,
      authorAvatarUrl: user.avatarUrl ?? null, text, type: 'chat', sentAt: Date.now(),
    });
  };

  const sendGift = async (gift: GiftType, sponsorship?: Sponsorship) => {
    if (!user || !stream) return;
    // Sponsored gifts may be discounted or free — the viewer is charged the
    // effective price, but the creator still earns the standard diamond yield.
    const cost = sponsorship ? viewerCoinCost(sponsorship, gift.coinCost) : gift.coinCost;
    if (wallet.coins < cost) {
      setInsufficientCoins(cost - wallet.coins);
      return;
    }
    setShowGifts(false);

    const walletRef       = doc(db, 'users', user.uid, 'wallet', 'default');
    const creatorBalRef   = doc(db, 'users', stream.hostUid, 'creatorBalance', 'default');
    const streamRef       = doc(db, 'streams', streamId);
    const giftEventRef    = doc(collection(db, 'streams', streamId, 'gifts'));
    // Per-stream leaderboard aggregate — doc id is the sender's uid.
    const gifterRef       = doc(db, 'streams', streamId, 'gifters', user.uid);

    try {
      await runTransaction(db, async (tx) => {
        const walletSnap = await tx.get(walletRef);
        const current = walletSnap.exists() ? (walletSnap.data().coins as number) : 0;
        if (current < cost) {
          throw new Error('INSUFFICIENT_COINS');
        }

        if (cost > 0) {
          tx.set(walletRef, {
            coins: increment(-cost),
            updatedAt: serverTimestamp(),
          }, { merge: true });
        }

        tx.set(creatorBalRef, {
          diamonds: increment(gift.diamondYield),
          lifetimeDiamonds: increment(gift.diamondYield),
          updatedAt: serverTimestamp(),
        }, { merge: true });

        tx.set(giftEventRef, {
          giftId: gift.id,
          giftName: gift.name,
          giftEmoji: gift.emoji,
          coinCost: cost,
          diamondYield: gift.diamondYield,
          senderUid: user.uid,
          senderUsername: user.username,
          recipientUid: stream.hostUid,
          sponsorshipId: sponsorship?.id ?? null,
          sentAt: serverTimestamp(),
        });

        // Leaderboard ranks coins actually spent, so skip free gifts.
        if (cost > 0) {
          tx.set(gifterRef, {
            senderUid: user.uid,
            username: user.username,
            avatarUrl: user.avatarUrl ?? null,
            totalCoins: increment(cost),
            lastGiftAt: serverTimestamp(),
          }, { merge: true });
        }

        tx.update(streamRef, { totalGifts: increment(cost) });
      });

      // Bill the sponsoring brand for this send (best-effort, after the gift
      // transaction succeeds). Mirrors Flutter SponsorshipService.recordSend.
      if (sponsorship) {
        const perSend = sponsorship.perSendRateUsd ?? sponsorship.creatorPayoutUsd ?? 0;
        const sendRef = doc(collection(db, 'sponsorships', sponsorship.id, 'sends'));
        setDoc(sendRef, {
          streamId, streamerUid: stream.hostUid, senderUid: user.uid,
          brandCostUsd: perSend, sentAt: serverTimestamp(),
        }).catch(() => {});
        updateDoc(doc(db, 'sponsorships', sponsorship.id), {
          totalSendCount: increment(1),
          totalBrandSpendUsd: increment(perSend),
        }).catch(() => {});
      }

      // Fan out to danmaku chat after the transaction succeeds
      await push(rtdbRef(rtdb, `danmaku/${streamId}`), {
        streamId, authorUid: user.uid, authorUsername: user.username,
        text: `sent ${gift.emoji} ${gift.name}`, type: 'gift', sentAt: Date.now(),
      });
    } catch (err) {
      if (err instanceof Error && err.message === 'INSUFFICIENT_COINS') {
        setInsufficientCoins(cost - wallet.coins);
      } else {
        console.error('Gift send failed', err);
      }
    }
  };

  if (!stream) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-3.5rem)]">
        <div className="w-8 h-8 border-2 border-[#FF7043] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Sponsorships that apply to THIS stream — gated by streamer UID and the
  // keywords/categories of any products currently featured (mirrors Flutter's
  // GiftPanel filtering).
  const productKeywords: string[] = [];
  const productCategories: string[] = [];
  for (const p of stream.featuredProducts ?? []) {
    for (const field of [p.brand, p.name]) {
      if (!field) continue;
      productKeywords.push(...field.toLowerCase().split(/[\s,]+/).filter((t) => t.length > 1));
    }
    if (p.category) productCategories.push(p.category);
  }
  const applicableSponsorships = sponsorships.filter((s) =>
    sponsorshipApplies(s, {
      streamerUid: stream.hostUid,
      keywords: productKeywords,
      categories: productCategories,
    }),
  );

  return (
    <div className="flex h-[calc(100vh-3.5rem)] bg-black">
      <div className="flex-1 relative flex flex-col">
        {hasPendingInvite && !isCoHost && (
          <div className="absolute top-0 inset-x-0 z-20 bg-[#FF7043]/90 backdrop-blur px-4 py-3 flex items-center gap-4">
            <span className="text-white font-semibold flex-1">
              🎙 @{stream.hostUsername} invited you to co-host this stream
            </span>
            <button onClick={handleAcceptInvite} className="px-4 py-1.5 bg-white text-[#FF7043] rounded-lg font-bold text-sm hover:bg-white/90 transition">
              Join
            </button>
            <button onClick={handleDeclineInvite} className="px-4 py-1.5 bg-white/20 text-white rounded-lg font-bold text-sm hover:bg-white/30 transition">
              Decline
            </button>
          </div>
        )}

        {/* Host + optional co-host video. Renders 50/50 side-by-side split
            when either a remote co-host is publishing OR this viewer accepted
            the co-host invite. Both right-side slots are always mounted (one
            hidden) so refs are attached before we play any tracks into them. */}
        <div className={`flex-1 bg-zinc-950 ${(cohostActive || isCoHost) ? 'flex flex-row' : ''}`}>
          <div ref={hostVideoRef} className={(cohostActive || isCoHost) ? 'flex-1 min-w-0' : 'w-full h-full'} />
          {(cohostActive || isCoHost) && <div className="w-0.5 bg-white/20 shrink-0" />}
          {/* My own preview when I'm the co-host */}
          <div ref={coHostPreviewRef} className={isCoHost ? 'flex-1 min-w-0' : 'hidden'} />
          {/* Someone else's co-host video when I'm just watching */}
          <div ref={cohostVideoRef} className={(cohostActive && !isCoHost) ? 'flex-1 min-w-0' : 'hidden'} />
          {/* In-stream game: the screen-share track (game + face PiP) shown
              full-screen over everything while the host is playing. Always
              mounted (hidden when idle) so the track can play into it. */}
          <div ref={gameVideoRef} className={stream.gameActive ? 'absolute inset-0 z-20 bg-black' : 'hidden'} />
          {stream.gameActive && (
            <div className="absolute top-4 right-4 z-30 px-3 py-1 rounded-full bg-black/60 backdrop-blur text-[#5BE1FF] text-sm font-bold">
              🎮 {stream.activeGameName ?? 'Playing a game'}
            </div>
          )}
        </div>

        <div className="absolute top-4 left-4 flex items-center gap-3 z-10">
          <span className="px-3 py-1 bg-[#FF7043] text-white text-sm font-bold rounded-full animate-pulse">LIVE</span>
          <span className="px-3 py-1 bg-black/60 backdrop-blur text-white text-sm rounded-full">
            👁 {stream.viewerCount.toLocaleString()}
          </span>
          <span className="px-3 py-1 bg-black/60 backdrop-blur text-yellow-400 text-sm rounded-full">
            🎁 {stream.totalGifts.toLocaleString()}
          </span>
          {stream.roomMode && (
            <span className="px-3 py-1 bg-purple-600/80 text-white text-sm rounded-full">🏠 Room</span>
          )}
        </div>

        {/* Gift goal + top-gifter leaderboard, under the status badges */}
        <div className="absolute top-16 left-4 z-10 space-y-2">
          <GiftGoalBar stream={stream} />
          <TopGiftersBoard streamId={streamId} />
        </div>

        <ProductDrawer products={stream.featuredProducts ?? []} featuredAd={stream.featuredAd} />
        <GiftAnimationOverlay streamId={streamId} />
        <CaptionOverlay streamId={streamId} enabled={captionsOn} />

        {/* CC toggle */}
        <button
          onClick={() => setCaptionsOn(o => !o)}
          className={`absolute top-4 right-4 z-10 px-2.5 py-1 rounded-md text-xs font-bold border transition ${
            captionsOn
              ? 'bg-white/20 border-white/30 text-white'
              : 'bg-black/40 border-white/10 text-white/40 hover:text-white/70'
          }`}
          title={captionsOn ? 'Hide captions' : 'Show captions'}
        >
          CC
        </button>

        <div className="absolute bottom-4 left-4 z-10">
          <p className="text-white font-bold drop-shadow">@{stream.hostUsername}</p>
          <p className="text-white/60 text-sm drop-shadow">{stream.title}</p>
          {cohosts.filter((c) => c.status === 'active').length > 0 && (
            <p className="text-[#FFD166] text-xs mt-1">
              with {cohosts.filter((c) => c.status === 'active').map((c) => `@${c.username}`).join(', ')}
            </p>
          )}
        </div>
      </div>

      <div className="w-80 flex flex-col border-l border-white/10">
        <div className="flex-1 overflow-y-auto p-4 space-y-2">
          {messages.map((msg) => (
            <div key={msg.id} className="text-sm">
              <span className={`font-semibold ${msg.type === 'gift' ? 'text-yellow-400' : msg.type === 'join' ? 'text-[#FFD166]' : 'text-[#FF7043]'}`}>
                {msg.authorUsername}
              </span>{' '}
              <span className="text-white/80">{msg.text}</span>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>

        {showGifts && (
          <div className="border-t border-white/10 p-3 bg-zinc-900">
            <div className="flex items-center justify-between mb-2">
              <p className="text-xs text-white/40 font-semibold uppercase tracking-wider">Send a Gift</p>
              <span className="text-xs text-white/60">🪙 {wallet.coins.toLocaleString()}</span>
            </div>
            <GiftPanel
              catalog={giftCatalog}
              sponsorships={applicableSponsorships}
              coins={wallet.coins}
              onSelect={sendGift}
            />
          </div>
        )}

        {insufficientCoins !== null && (
          <div className="border-t border-white/10 p-3 bg-amber-500/10 flex items-center gap-3">
            <p className="text-xs text-amber-400 flex-1">
              Need {insufficientCoins.toLocaleString()} more coins to send this gift.
            </p>
            <Link href="/wallet" className="px-3 py-1.5 bg-[#FF7043] text-white text-xs font-semibold rounded-full hover:bg-[#e55a2b] transition">
              Top up
            </Link>
            <button onClick={() => setInsufficientCoins(null)} className="text-white/40 hover:text-white text-sm">✕</button>
          </div>
        )}

        {user ? (
          <div className="border-t border-white/10 p-3 flex gap-2">
            <input value={chatInput} onChange={(e) => setChatInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && sendChat()}
              placeholder="Say something..."
              className="flex-1 bg-zinc-800 border border-zinc-600 rounded-full px-4 py-2 text-sm text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
            />
            <button onClick={() => setShowGifts(!showGifts)} className="text-xl hover:scale-110 transition">🎁</button>
            <button onClick={sendChat} className="px-3 py-2 bg-[#FF7043] rounded-full text-sm font-semibold hover:bg-[#e55a2b] transition">Send</button>
          </div>
        ) : (
          <div className="border-t border-white/10 p-3 text-center text-sm text-white/40">
            <a href="/login" className="text-[#FFD166] hover:underline">Sign in</a> to chat
          </div>
        )}
      </div>
    </div>
  );
}
