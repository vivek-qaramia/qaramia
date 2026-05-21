# Watch-to-Earn Design Document

**Status:** Design only. No code shipped yet. Revisit after the post-stream editor (CapCut-style) feature lands.

**Author:** v1 draft, 2026-05-21.

---

## 1. Goal

Pay viewers small amounts for engaged watch time + engagement actions on Qaramia, while preserving platform margin. Default flow nudges users to **tip earned coins to creators** rather than cash out — this recycles platform spend back into the creator economy.

## 2. Economic invariant

For every minute of viewer watch-time, the platform must net more in ad + subscription revenue than it pays out:

```
PayoutValue/minute  <  (AdRevenue/min × 0.7) + (SubRevenue/min × 0.5) − InfraCost/min
```

Where:

| Term | Typical value (Qaramia niche) |
|---|---|
| Ad CPM | $1–$10 (live commerce skews higher; depends on geo) |
| Ads per viewer-hour | 6–10 (every 8–10 min) |
| Ad revenue per viewer-hour | $0.05–$0.30 |
| **Sustainable payout ceiling** | **$0.01–$0.05 / viewer-hour** |

Reference points: TikTok pays creators ~$0.02–$0.04 per 1000 views. Honeygain-style passive earn apps pay ~$0.0001–$0.001 per ad viewed. Bigo Live pays viewers indirectly via tournaments and quests, not flat watch-time.

## 3. Currency model

Add a separate ledger so earn-coins can have different cash-out rules than purchased coins.

| Field | Existing? | Meaning |
|---|---|---|
| `wallet.coins` | yes | Purchased coins. 1 coin spends at the same 1:1 in-app rate as earnCoins. Cannot cash out as currency — only via gift-economy diamond conversion for creators. |
| `wallet.earnCoins` | **new** | Coins awarded by the watch-to-earn system. Spend 1:1 in-app (tips, gifts). Cash-out at 100:1 (100 earn-coins = $0.01). |
| `wallet.lifetimeEarnCoins` | **new** | Total ever awarded. Used for tax compliance & cohort analysis. |
| `wallet.lifetimeCashedOutUsd` | **new** | Total $ paid out to this user. Triggers 1099-NEC reporting at $600/yr. |

**Spend-order precedence** when user sends a gift or buys premium content:
1. Use `earnCoins` first (drains the platform's "debt").
2. Fall back to `coins` (purchased).

This is the key recycling mechanic: most users will spend earn-coins on gifts before they ever accumulate enough to cash out.

## 4. Earn rules (engagement-weighted, with daily caps)

| Action | Base coins | Daily cap | Daily max coins |
|---|---|---|---|
| Foreground+audible watch time | 1 / min | 30 min | 30 |
| Like a video/stream | 2 / like | 5 likes | 10 |
| Substantive comment (>10 chars, not spam-filtered) | 5 / comment | 3 comments | 15 |
| Follow a new creator | 10 / follow | 2 follows | 20 |
| Send a gift (encourages spend, fuels creator) | 5 / gift | 3 gifts | 15 |
| **Daily total cap** | — | — | **90** |

90 coins/day max → in-app value $0.90/day, cash-out value $0.009/day. With $0.05–$0.30/day ad revenue per DAU we keep healthy margin.

**Premium subscriber multiplier (future):** 2× base + 2× engagement bonuses. Daily cap becomes 180. Subscribers don't see ads but the sub MRR exceeds their ad revenue contribution.

## 5. Firestore schema changes

### 5.1 Wallet — modified

```
users/{uid}/wallet/default
{
  coins: number,              // existing — purchased
  lifetimeCoinsPurchased: number,  // existing

  earnCoins: number,           // NEW
  lifetimeEarnCoins: number,   // NEW — never decremented
  lifetimeCashedOutUsd: number, // NEW
  lastEarnHeartbeatAt: Timestamp,  // NEW — anti-replay
  earnSuspendedUntil: Timestamp | null, // NEW — set by fraud flag
}
```

### 5.2 Daily earn buckets — new collection

```
users/{uid}/earnDaily/{YYYY-MM-DD}
{
  watchMin: number,        // 0..30 cap
  likes: number,           // 0..5
  comments: number,        // 0..3
  follows: number,         // 0..2
  giftsSent: number,       // 0..3
  totalCoins: number,      // 0..90 cap
  distinctCreatorsWatched: string[],  // anti-farm: need ≥3 for cap to apply
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

Server reads this doc atomically to enforce caps in a single transaction.

### 5.3 Earn events ledger — new collection (append-only)

```
users/{uid}/earnEvents/{eventId}
{
  type: 'watch' | 'like' | 'comment' | 'follow' | 'gift_sent',
  coinsAwarded: number,
  ref: { kind: 'video'|'stream', id: string, creatorUid: string },
  sessionId: string,       // ties heartbeats to a continuous viewing session
  awardedAt: Timestamp,
  serverIp: string,        // anti-fraud
  deviceFingerprint: string, // anti-fraud
}
```

Purpose: full audit trail. Required for chargeback handling, tax export, dispute resolution.

### 5.4 Heartbeat log — short-lived

```
heartbeats/{uid}/{sessionId}/{beaconIndex}
{
  sentAt: Timestamp,        // server timestamp
  appState: 'foreground' | 'background',
  audioRouted: bool,
  videoOrStreamId: string,
  prevBeaconIndex: number,  // chain validation
  ttl: Timestamp,           // 7 days, deleted by scheduled job
}
```

Stored in Firestore (not RTDB) because we need transactional reads against `earnDaily`. Auto-purged.

### 5.5 Cash-out requests — new collection

```
cashOuts/{requestId}
{
  uid: string,
  earnCoinsBurned: number,
  usdAmount: number,
  stripePayoutId: string,
  status: 'pending'|'paid'|'failed',
  requestedAt: Timestamp,
  paidAt: Timestamp | null,
  failureReason: string | null,
}
```

Same pattern as the existing `creatorPayouts` for diamonds.

## 6. Heartbeat protocol

```
Client                                    Server
──────                                    ──────
  │                                          │
  │  (video / stream playing, foreground)    │
  │                                          │
  ├─── beacon  ─────────────────────────────►│
  │    {                                     │
  │      sessionId: <uuid>,                  │
  │      videoOrStreamId,                    │
  │      appState: 'foreground',             │
  │      audioRouted: true,                  │
  │      beaconIndex: 0                      │
  │    }                                     │
  │                                          │
  │   ◄──── { ok: true, coinsThisBeacon: 1, dailyEarned: 7 }
  │                                          │
  │                                          │
  │  (30 sec passes; client checks            │
  │   visibility + audio state)              │
  │                                          │
  ├─── beacon (beaconIndex: 1) ─────────────►│
  │                                          │
  │                                          │
  ▼                                          ▼
```

Rules:
- **30 sec ± 5 sec** between beacons. Server rejects faster (replay) or slower (gap-fill).
- Server time is truth; client `sentAt` ignored.
- Each beacon awards `1/2` coin (so 2 valid beacons = 1 minute = 1 coin). Avoids the "watch 31 seconds, get a coin" loophole.
- Foreground + audio routed required. If client lies, periodic captcha check catches it.
- Session ID resets when video/stream changes. Beacons across sessions don't chain.

## 7. Engagement bonus award protocol

Each engagement action (like, comment, follow, gift_sent) calls a Cloud Function that:

1. Validates the underlying action exists in Firestore (e.g. `likes/{uid}` doc was just written).
2. Reads `earnDaily/{today}` — checks cap not exceeded.
3. Transactionally increments `earnCoins` + writes an `earnEvents/...` ledger row.
4. Returns the updated balance to the client for toast UI.

If the action is reversed (unlike, unfollow), the awarded coins are NOT clawed back (avoids gaming and refund headaches), but the daily counter is not decremented either — meaning a user can't unlike-then-relike to farm the bonus.

## 8. Cash-out flow

```
User taps "Cash out"
   │
   ▼
Check earnCoins ≥ 10,000  (= $1 min)
   │
   ├── No → show progress toward minimum
   │
   ▼
Check Stripe Connect identity verified
   │
   ├── No → push to existing Connect onboarding flow (already plumbed for creators)
   │
   ▼
Check YTD payout < $600
   │
   ├── ≥ $600 → require W-9 collection before continuing
   │
   ▼
Check cool-down: 30 days since last cash-out
   │
   ├── In cool-down → show next eligible date
   │
   ▼
Transactional decrement of earnCoins + create cashOuts/{id} (status: pending)
   │
   ▼
Stripe Connect payout API → Stripe takes ~2 business days
   │
   ▼
Webhook callback updates cashOuts/{id}.status = 'paid'
```

## 9. Anti-fraud

Layered defense:

| Layer | Mechanism | Defeats |
|---|---|---|
| Client-side hint | Track foreground + audio state for the beacon | Background play, muted play |
| Server beacon validation | Enforce 30s ± 5s spacing, chain index | Replay attacks, sped-up beacons |
| Distinct creator requirement | Need ≥3 distinct creators watched/day to unlock full cap | Single-stream farming |
| Engagement reality check | Likes/comments must exist as actual Firestore docs | Fake event submission |
| Phone verification | Required before first cash-out | Sybil accounts |
| Device fingerprint | Firebase Installation ID + device model + OS version → server-side cap of 1 active earn-account per device | Multi-account on one device |
| Captcha challenge | After 15 min of continuous earn-time, present a "tap the highlighted product" challenge tied to the live stream content | Background bots, AFK farming |
| Behavioral anomaly | ML-style rules: avg session length, time-of-day, scroll velocity. Flag outliers for review | Coordinated farms |
| Suspension | `earnSuspendedUntil` blocks all earn until manual review | Repeated abuse |

## 10. Tax & regulatory

- **US 1099-NEC**: required when total YTD payout to a user ≥ $600. Track `lifetimeCashedOutUsd`. Generate forms via Stripe Tax or a separate flow.
- **W-9 collection**: gather before second cash-out if YTD approaching $600.
- **EU VAT / VAT MOSS**: payouts to EU users may have VAT implications depending on whether earn-coins are treated as services or rewards. Need legal review per jurisdiction before EU launch.
- **DE / KR / specific markets**: pay-for-attention can attract gambling-adjacent scrutiny. Defer launch in these markets until legal review.
- **Minors**: COPPA. Anyone under 18 is blocked from cash-out entirely. Earn-coins can still be earned + spent on gifts.

## 11. Cloud Function API surface (stubs — not yet implemented)

All on `functions/src/watchEarn.js` once we build. CommonJS, `onCall` style to match the existing `getAgoraToken`, `validateApplePurchase`, etc.

```js
// functions/src/watchEarn.js  — STUB, DO NOT WIRE TO index.js YET

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const DAILY_CAP_COINS = 90;
const WATCH_MAX_PER_DAY = 30;          // minutes
const BEACON_INTERVAL_MS = 30_000;
const BEACON_TOLERANCE_MS = 5_000;
const COIN_PER_BEACON = 0.5;           // 2 beacons = 1 coin = 1 minute

/**
 * Client posts a watch-time beacon every 30 seconds while video/stream is
 * foreground+audible. Validates beacon, increments earnCoins atomically,
 * returns updated daily balance.
 *
 * Args: { sessionId, videoOrStreamId, kind: 'video'|'stream', appState, audioRouted, beaconIndex }
 * Returns: { coinsAwarded, dailyEarned, dailyCap, ok: bool, reason?: string }
 *
 * Validation:
 *   - context.auth required
 *   - sentAt within BEACON_TOLERANCE_MS of expected based on prev beacon
 *   - appState === 'foreground' && audioRouted === true
 *   - beaconIndex monotonically increasing
 *   - underlying video/stream exists
 *   - daily watch cap not exceeded
 *   - earnSuspendedUntil not set
 */
exports.recordWatchHeartbeat = functions.https.onCall(async (data, context) => {
  // TODO: implement when feature ships
  throw new functions.https.HttpsError('unimplemented', 'Not yet built.');
});

/**
 * Client calls after the like/comment/follow/gift_sent action is committed.
 * Server re-reads the action doc, awards bonus coins if within cap.
 *
 * Args: { type: 'like'|'comment'|'follow'|'gift_sent', ref: {kind, id, creatorUid} }
 * Returns: { coinsAwarded, dailyEarned, ok: bool, reason?: string }
 */
exports.recordEngagementEarn = functions.https.onCall(async (data, context) => {
  // TODO
  throw new functions.https.HttpsError('unimplemented', 'Not yet built.');
});

/**
 * Burn earnCoins from balance to immediately tip a creator. Atomic.
 *
 * Args: { recipientUid, coinAmount }
 * Returns: { ok: bool, newEarnBalance, newCreatorDiamonds }
 *
 * Differs from regular gift-send because the coins come out of earnCoins
 * directly (no spend-order ambiguity).
 */
exports.tipCreatorWithEarnCoins = functions.https.onCall(async (data, context) => {
  // TODO
  throw new functions.https.HttpsError('unimplemented', 'Not yet built.');
});

/**
 * Initiate a cash-out. Validates threshold, KYC, cool-down, tax form status.
 * Decrements earnCoins, creates cashOuts/{id} doc, kicks off Stripe Connect.
 *
 * Args: {} (everything inferred from auth)
 * Returns: { ok: bool, cashOutId, usdAmount, estimatedArrival, reason?: string }
 */
exports.requestEarnCoinCashOut = functions.https.onCall(async (data, context) => {
  // TODO
  throw new functions.https.HttpsError('unimplemented', 'Not yet built.');
});

/**
 * Scheduled job: purge heartbeat docs older than 7 days, write daily
 * aggregate to earnDaily, run anti-fraud sweep over the prior day's
 * events. Runs every night UTC.
 */
exports.nightlyEarnSweep = functions.pubsub
  .schedule('0 3 * * *')
  .onRun(async () => {
    // TODO
  });
```

## 12. UI surfaces (deferred design)

To be designed when build phase starts. Anticipated touchpoints:

- **Feed / Live viewer**: invisible heartbeat. Optional subtle "+1 coin" toast every ~minute (configurable).
- **Engagement actions**: toast `+5 coins for liking @creator` on like; same for comment/follow.
- **Profile → Earnings card**: today's progress bar (current / 90), lifetime earned, lifetime tipped, lifetime cashed-out.
- **Wallet screen**: new "Earn Coins" balance pill alongside "Coins". Tap → cash-out flow if eligible.
- **Gift panel**: default tab shows "Tip from earn coins (X available)" before "Buy more coins" — recycling-first UX.

## 13. Phased build plan

| Phase | Scope | Effort |
|---|---|---|
| 1 | Schema (wallet field + 3 new collections), heartbeat Cloud Function, daily-cap enforcement | ~3 days |
| 2 | Engagement bonuses (`recordEngagementEarn`) + tip-with-earn (`tipCreatorWithEarnCoins`) | ~2 days |
| 3 | Wallet + profile UI surfaces | ~2 days |
| 4 | Cash-out flow + Stripe Connect wire-up | ~3 days |
| 5 | Anti-fraud: captcha challenge, device fingerprint, behavioural rules | ~1 week |
| 6 | Tax compliance (1099-NEC, W-9 collection) | ~3 days |
| 7 | Subscription multiplier (depends on subs being built first) | ~2 days |

## 14. Open questions

1. **Earn-coin cash-out rate** — 100:1 ($0.01 per 100 coins) is the default proposal. Should we run an A/B test of 50:1 vs 100:1 vs 200:1 on tip-rate behaviour?
2. **Daily cap structure** — 90 hard cap vs. soft cap with sharply diminishing returns past 60? Soft cap encourages more usage without runaway payouts.
3. **Anti-fraud severity** — start permissive (low friction, accept more fraud) or strict (more friction, fewer real users blocked)?
4. **Cash-out floor** — $1 min ($0.01 × 10,000 coins) is generous. Industry norm is $5–$10 to keep float on platform. Worth A/B-ing.
5. **Subscription multiplier** — 2× is what's modelled. Could be 1.5× to keep margins safer. Decide after subscription LTV is known.
6. **Geographic launch order** — start US-only? Add Canada/UK after? EU/DE/KR require legal review before launch.

---

**Next checkpoint**: revisit after the post-stream editor (Phases 2-5 of that feature) lands. At that point, walk through this doc, lock the open questions, and start Phase 1 of the build.
