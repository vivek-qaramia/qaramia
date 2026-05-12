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
  startedAt: Date;
  endedAt?: Date;
  featuredProducts?: ProductInfo[];
  featuredAd?: Ad;
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
