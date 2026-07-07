import type { ProductInfo } from '@/lib/product-scanner/types';

export type { ProductInfo };

export interface AppUser {
  uid: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  bio?: string;
  followerCount: number;
  followingCount: number;
  likeCount: number;
  isLive: boolean;
  createdAt: Date;
  ageRange?: '18-24' | '25-34' | '35-44' | '45+';
  country?: string;
  estimatedEarningsUsd?: number;
  // Game Zone — earned attribute points (code → points); feed the System panel.
  attributes?: Record<string, number>;
  // Denormalized System XP (updateSystemXp Cloud Function); leaderboard sort key.
  systemXp?: number;
}

export interface LiveStream {
  id: string;
  hostUid: string;
  hostUsername: string;
  hostAvatarUrl?: string;
  title: string;
  thumbnailUrl?: string;
  category: string;
  viewerCount: number;
  peakViewerCount: number;
  totalGifts: number;
  status: 'live' | 'ended' | 'scheduled';
  agoraChannel: string;
  roomMode?: boolean;
  // Gift goal — host-set coin target; progress = totalGifts / giftGoalTarget.
  giftGoalLabel?: string;
  giftGoalTarget?: number;
  startedAt: Date;
  endedAt?: Date;
  featuredProducts?: ProductInfo[];
  featuredAd?: Ad;
  // In-stream game (Game Zone Phase 2/3) — while active, the game+face PiP is
  // published on a second connection under gameScreenUid; viewers render that
  // uid full-screen.
  gameActive?: boolean;
  gameScreenUid?: number;
  activeGameName?: string;
}

export const PRODUCT_CATEGORIES = ['beauty', 'food', 'tech', 'fitness', 'fashion', 'home', 'other'] as const;
export type ProductCategory = typeof PRODUCT_CATEGORIES[number];

export interface Ad {
  id: string;
  advertiserId: string;
  advertiserName: string;
  headline: string;
  imageUrl?: string;
  ctaText: string;
  ctaUrl: string;
  keywords: string[];
  categories?: string[];
  status: 'active' | 'paused';
  impressions: number;
  clicks: number;
  createdAt: Date;
}

/// A single zoom-at-point marker. Mirrors flutter_app's ZoomMarker.
export interface ZoomMarker {
  timeMs: number;
  scale: number;
  durationMs: number;
}

/// Centred text overlay shown over the video between [startMs, endMs].
export interface TextOverlay {
  text: string;
  startMs: number;
  endMs: number;
}

/// Centred emoji sticker shown over the video between [startMs, endMs].
export interface StickerOverlay {
  emoji: string;
  startMs: number;
  endMs: number;
}

export interface Video {
  id: string;
  authorUid: string;
  authorUsername: string;
  authorAvatarUrl?: string;
  videoUrl: string;
  thumbnailUrl?: string;
  caption: string;
  tags: string[];
  likeCount: number;
  commentCount: number;
  shareCount: number;
  viewCount: number;
  audioTitle?: string;
  // Post-stream editor effects. All optional — older docs without these
  // render as untreated video.
  filterId?: string;
  zooms?: ZoomMarker[];
  blurAmount?: number;
  vignetteIntensity?: number;
  textOverlays?: TextOverlay[];
  stickers?: StickerOverlay[];
  // Non-destructive trim window (web). Playback loops within [trimStartMs,
  // trimEndMs]; absent/0 means play the whole clip. (Flutter trims the file
  // itself via FFmpeg, so its published clips don't carry these.)
  trimStartMs?: number;
  trimEndMs?: number;
  createdAt: Date;
}

export interface ChatMessage {
  id: string;
  streamId: string;
  authorUid: string;
  authorUsername: string;
  authorAvatarUrl?: string;
  text: string;
  type: 'chat' | 'gift' | 'join' | 'system';
  sentAt: number; // ms timestamp (RTDB)
}

export type GiftTier = 'standard' | 'premium' | 'whale';

export interface GiftType {
  id: string;
  name: string;
  emoji: string;
  coinCost: number;
  diamondYield: number; // creator's diamond reward; default = 50% of coinCost
  tier: GiftTier;
}

export const GIFT_CATALOG: GiftType[] = [
  // Standard
  { id: 'rose',     name: 'Rose',      emoji: '🌹', coinCost: 1,     diamondYield: 0,    tier: 'standard' },
  { id: 'heart',    name: 'Heart',     emoji: '❤️', coinCost: 5,     diamondYield: 2,    tier: 'standard' },
  { id: 'star',     name: 'Star',      emoji: '⭐', coinCost: 10,    diamondYield: 5,    tier: 'standard' },
  { id: 'lollipop', name: 'Lollipop',  emoji: '🍭', coinCost: 25,    diamondYield: 12,   tier: 'standard' },
  { id: 'rocket',   name: 'Rocket',    emoji: '🚀', coinCost: 50,    diamondYield: 25,   tier: 'standard' },
  // Premium
  { id: 'crown',    name: 'Crown',     emoji: '👑', coinCost: 100,   diamondYield: 50,   tier: 'premium' },
  { id: 'bouquet',  name: 'Bouquet',   emoji: '💐', coinCost: 500,   diamondYield: 250,  tier: 'premium' },
  { id: 'diamond',  name: 'Diamond',   emoji: '💎', coinCost: 500,   diamondYield: 250,  tier: 'premium' },
  { id: 'universe', name: 'Universe',  emoji: '🌌', coinCost: 1000,  diamondYield: 500,  tier: 'premium' },
  { id: 'sportscar',name: 'Sports Car',emoji: '🏎️', coinCost: 2000,  diamondYield: 1000, tier: 'premium' },
  // Whale
  { id: 'yacht',    name: 'Yacht',     emoji: '🛥️', coinCost: 5000,  diamondYield: 2500, tier: 'whale' },
  { id: 'castle',   name: 'Castle',    emoji: '🏰', coinCost: 10000, diamondYield: 5000, tier: 'whale' },
  { id: 'lion',     name: 'Lion',      emoji: '🦁', coinCost: 30000, diamondYield: 15000,tier: 'whale' },
];

export interface Wallet {
  coins: number;
  lifetimeCoinsPurchased: number;
  updatedAt?: Date;
}

export interface CreatorBalance {
  diamonds: number;
  lifetimeDiamonds: number;
  updatedAt?: Date;
}

/// Tiered creator share — diamond→USD rate by lifetime volume. Must match
/// creatorTier() in functions/src/connect.js (server is authoritative; these
/// are for display). Rising .010 / Partner .012 / Elite .014.
export function creatorTierName(lifetimeDiamonds: number): string {
  if (lifetimeDiamonds >= 1_000_000) return 'Elite';
  if (lifetimeDiamonds >= 100_000) return 'Partner';
  return 'Rising';
}

export function creatorUsdRatePerDiamond(lifetimeDiamonds: number): number {
  if (lifetimeDiamonds >= 1_000_000) return 0.014;
  if (lifetimeDiamonds >= 100_000) return 0.012;
  return 0.010;
}

export interface CoinPack {
  id: string;
  label: string;
  priceUsd: number;
  coins: number;
  bonusCoins: number;
  stripePriceId?: string; // optional — falls back to ad-hoc Stripe price if unset
  target: string; // human-readable target user description
}

export const COIN_PACKS: CoinPack[] = [
  { id: 'starter', label: 'Starter', priceUsd:  0.99, coins:   100, bonusCoins:    0, target: 'First-time buyer' },
  { id: 'casual',  label: 'Casual',  priceUsd:  4.99, coins:   500, bonusCoins:   50, target: 'Regular viewer' },
  { id: 'regular', label: 'Regular', priceUsd:  9.99, coins:  1000, bonusCoins:  200, target: 'Engaged supporter' },
  { id: 'power',   label: 'Power',   priceUsd: 24.99, coins:  2500, bonusCoins:  800, target: 'Heavy spender' },
  { id: 'whale',   label: 'Whale',   priceUsd: 99.99, coins: 10000, bonusCoins: 4000, target: 'Top supporter' },
];

// ── Sponsored gifts ──────────────────────────────────────────────────────────
// Mirrors flutter_app/lib/models/sponsorship.dart. A brand pays (per-send,
// monthly retainer, or a viewer discount) to have a gift surfaced with brand
// styling, optionally gated to specific streamers / detected products.
export type SponsorshipPricingModel = 'premium' | 'free' | 'discounted';
export type SponsorshipStatus = 'active' | 'paused' | 'ended';

export interface Sponsorship {
  id: string;
  brandId: string;
  brandName: string;
  brandLogoUrl?: string;
  giftTypeId: string;
  pricingModel: SponsorshipPricingModel;
  perSendRateUsd?: number;
  monthlyRetainerUsd?: number;
  /** Fraction off the coin price for viewers (0–1), `discounted` model only. */
  viewerDiscount?: number;
  creatorPayoutUsd?: number;
  /** Restrict to these streamer UIDs; empty = platform-wide. */
  allowedStreamerUids: string[];
  /** Only show when the stream's detected products match these. */
  gateOnKeywords: string[];
  gateOnCategories: string[];
  status: SponsorshipStatus;
  totalSendCount: number;
  totalBrandSpendUsd: number;
  startsAt: Date;
  endsAt?: Date;
  createdAt: Date;
}

/** Whether a sponsorship currently applies to a stream + its visible products. */
export function sponsorshipApplies(
  s: Sponsorship,
  opts: { streamerUid: string; keywords?: string[]; categories?: string[] },
): boolean {
  if (s.status !== 'active') return false;
  if (s.allowedStreamerUids.length > 0 && !s.allowedStreamerUids.includes(opts.streamerUid)) {
    return false;
  }
  const keywords = opts.keywords ?? [];
  const categories = opts.categories ?? [];
  if (s.gateOnKeywords.length > 0 && !s.gateOnKeywords.some((k) => keywords.includes(k))) {
    return false;
  }
  if (s.gateOnCategories.length > 0 && !s.gateOnCategories.some((c) => categories.includes(c))) {
    return false;
  }
  return true;
}

/** What the viewer pays in coins, applying any discount (free → 0). */
export function viewerCoinCost(s: Sponsorship, standardCoinCost: number): number {
  if (s.pricingModel === 'free') return 0;
  if (s.pricingModel === 'discounted' && s.viewerDiscount != null) {
    return Math.round(standardCoinCost * (1 - s.viewerDiscount));
  }
  return standardCoinCost;
}

export interface GiftSendEvent {
  id: string;
  giftId: string;
  giftName: string;
  giftEmoji: string;
  coinCost: number;
  diamondYield: number;
  senderUid: string;
  senderUsername: string;
  recipientUid: string;
  sentAt: Date;
}
