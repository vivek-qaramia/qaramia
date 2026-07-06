import type { AppUser, LiveStream } from '@/lib/types';

// Web port of the Flutter StreamerStats (models/streamer_stats.dart). Keep the
// formulas in sync so a streamer's level/stats read the same on both clients.

export interface SystemStat {
  code: string; // e.g. 'CHA'
  label: string; // e.g. 'charisma'
  fill: number; // 0..1, drives the segmented bar
  display: string; // e.g. '1.2K'
}

export interface StreamerStats {
  level: number;
  title: string;
  expProgress: number; // 0..1 within the current level
  stats: SystemStat[];
}

const attributeLabels: Record<string, string> = {
  pwr: 'power',
  cha: 'charisma',
  inf: 'influence',
  for: 'fortune',
  hyp: 'hype',
  agi: 'agility',
};

const clamp01 = (n: number) => Math.max(0, Math.min(1, n));

// Smooth saturating curve: 0 → 0, ~soft → ~0.5, large → ~1.
function sat(v: number, soft: number): number {
  return v <= 0 ? 0 : clamp01(1 - 1 / (1 + v / soft));
}

function short(v: number): string {
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(v % 1_000_000 === 0 ? 0 : 1)}M`;
  if (v >= 1_000) return `${(v / 1_000).toFixed(v % 1_000 === 0 ? 0 : 1)}K`;
  return `${v}`;
}

function titleFor(lv: number): string {
  if (lv >= 50) return 'Legend';
  if (lv >= 35) return 'Master';
  if (lv >= 20) return 'Elite';
  if (lv >= 10) return 'Veteran';
  if (lv >= 5) return 'Rising Star';
  return 'Novice';
}

/// Derive a streamer's System stats from their profile (+ live stream, if any).
export function streamerStats(user: AppUser, stream?: LiveStream | null): StreamerStats {
  const attributes = user.attributes ?? {};
  const earnedTotal = Object.values(attributes).reduce((a, b) => a + b, 0);
  const xp = user.followerCount * 12 + user.likeCount + earnedTotal * 5;
  const level = Math.max(1, Math.floor(Math.sqrt(xp / 50)));
  const curBase = 50 * level * level;
  const nextBase = 50 * (level + 1) * (level + 1);
  const expProgress = nextBase > curBase ? clamp01((xp - curBase) / (nextBase - curBase)) : 0;

  const stats: SystemStat[] = [
    { code: 'CHA', label: 'charisma', fill: sat(user.likeCount, 800), display: short(user.likeCount) },
    { code: 'INF', label: 'influence', fill: sat(user.followerCount, 1500), display: short(user.followerCount) },
  ];

  if (stream) {
    const hypeFill = stream.peakViewerCount > 0
      ? clamp01(stream.viewerCount / stream.peakViewerCount)
      : stream.viewerCount > 0 ? 1 : 0;
    stats.push({ code: 'FOR', label: 'fortune', fill: sat(stream.totalGifts, 500), display: short(stream.totalGifts) });
    stats.push({ code: 'HYP', label: 'hype', fill: hypeFill, display: `${Math.round(hypeFill * 100)}%` });
  }

  // Game-earned attributes (e.g. PWR) as extra lines, biggest first.
  for (const [code, value] of Object.entries(attributes).filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1])) {
    stats.push({ code: code.toUpperCase(), label: attributeLabels[code] ?? code, fill: sat(value, 200), display: short(value) });
  }

  return { level, title: titleFor(level), expProgress, stats };
}
