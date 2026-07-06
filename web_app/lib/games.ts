// Web game catalog + helpers — parity with the Flutter models/game.dart. IDs
// MUST match the Flutter catalog so viewer challenges resolve on the streamer.

export type GameType = 'tapTargets' | 'fruitSlice' | 'findObject';

export interface Game {
  id: string;
  name: string;
  type: GameType;
  emoji: string;
  description: string;
  timeLimitSec: number;
  difficulty: 'Easy' | 'Medium' | 'Hard';
  attribute: string; // attribute code trained, e.g. 'pwr'
  rewardPoints: number;
  successScore: number;
  challengeCost: number; // coins a viewer pays to dare the streamer
}

export interface GameResult {
  score: number;
  success: boolean;
}

export const ATTRIBUTE_LABELS: Record<string, string> = {
  pwr: 'power',
  cha: 'charisma',
  inf: 'influence',
  for: 'fortune',
  hyp: 'hype',
  agi: 'agility',
};

export const GAMES: Game[] = [
  { id: 'tap_easy', name: 'Target Practice', type: 'tapTargets', emoji: '🎯', description: 'Tap the moving targets before the timer runs out.', timeLimitSec: 20, difficulty: 'Easy', attribute: 'pwr', rewardPoints: 10, successScore: 10, challengeCost: 100 },
  { id: 'tap_medium', name: 'Sharpshooter', type: 'tapTargets', emoji: '🎯', description: 'Faster targets, higher score to clear.', timeLimitSec: 30, difficulty: 'Medium', attribute: 'pwr', rewardPoints: 20, successScore: 22, challengeCost: 100 },
  { id: 'tap_hard', name: 'Bullseye Frenzy', type: 'tapTargets', emoji: '🎯', description: 'Blink and you miss it. For the quick.', timeLimitSec: 30, difficulty: 'Hard', attribute: 'pwr', rewardPoints: 35, successScore: 34, challengeCost: 100 },
  { id: 'fruit_medium', name: 'Fruit Frenzy', type: 'fruitSlice', emoji: '🍉', description: 'Swipe to slice the falling fruit before it drops.', timeLimitSec: 30, difficulty: 'Medium', attribute: 'pwr', rewardPoints: 20, successScore: 18, challengeCost: 100 },
  { id: 'find_medium', name: 'Spot It', type: 'findObject', emoji: '🔎', description: 'Find and tap the matching critter, round after round.', timeLimitSec: 30, difficulty: 'Medium', attribute: 'pwr', rewardPoints: 20, successScore: 12, challengeCost: 100 },
];

export function gameById(id: string): Game | undefined {
  return GAMES.find((g) => g.id === id);
}

export function dayKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Deterministic daily task set: same games for everyone on a given date,
// rotating day to day (own web ordering — need not match the Flutter pick).
export function gamesForDay(d: Date, count = 3): Game[] {
  const enabled = [...GAMES];
  if (enabled.length <= count) return enabled;
  const seed = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
  const hash = (s: string) => {
    let h = seed;
    for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0x7fffffff;
    return h;
  };
  return [...enabled].sort((a, b) => hash(a.id) - hash(b.id)).slice(0, count);
}

// Back-compat aliases for the W3 challenge picker.
export type ChallengeGame = Game;
export const CHALLENGE_GAMES = GAMES;
