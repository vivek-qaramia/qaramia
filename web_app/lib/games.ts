// Web-side game catalog for viewer challenges (Game Zone 3c parity, W3). IDs
// MUST match the Flutter Game.catalog (models/game.dart) so the streamer's app
// can resolve the challenged game by id. The web only needs the display fields
// + challengeCost here; the playable engines live on the streamer (Flutter).

export interface ChallengeGame {
  id: string;
  name: string;
  emoji: string;
  difficulty: string;
  timeLimitSec: number;
  challengeCost: number; // coins the viewer pays to dare the streamer
}

export const CHALLENGE_GAMES: ChallengeGame[] = [
  { id: 'tap_easy', name: 'Target Practice', emoji: '🎯', difficulty: 'Easy', timeLimitSec: 20, challengeCost: 100 },
  { id: 'tap_medium', name: 'Sharpshooter', emoji: '🎯', difficulty: 'Medium', timeLimitSec: 30, challengeCost: 100 },
  { id: 'tap_hard', name: 'Bullseye Frenzy', emoji: '🎯', difficulty: 'Hard', timeLimitSec: 30, challengeCost: 100 },
  { id: 'fruit_medium', name: 'Fruit Frenzy', emoji: '🍉', difficulty: 'Medium', timeLimitSec: 30, challengeCost: 100 },
  { id: 'find_medium', name: 'Spot It', emoji: '🔎', difficulty: 'Medium', timeLimitSec: 30, challengeCost: 100 },
];
