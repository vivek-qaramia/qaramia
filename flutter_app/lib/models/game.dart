// Game Zone — definitions for the lightweight mini-games streamers play to
// earn attribute points (which feed the System status panel).
//
// v1 ships a single game engine (tap moving targets) exposed as a few
// difficulty variants, plus a static [catalog]. This is the registry: adding
// a game later = add an entry here (and, when authoring moves server-side, a
// `games/{id}` Firestore doc). The daily task list is picked from [catalog].

enum GameType { tapTargets, fruitSlice, findObject }

/// Human labels for attribute codes stored in `users/{uid}.attributes`.
const Map<String, String> kAttributeLabels = {
  'pwr': 'power',
  'cha': 'charisma',
  'inf': 'influence',
  'for': 'fortune',
  'hyp': 'hype',
  'agi': 'agility',
};

class Game {
  final String id;
  final String name;
  final GameType type;
  final String emoji;
  final String description;
  final int timeLimitSec;
  final String difficulty; // 'Easy' | 'Medium' | 'Hard'
  final String attribute; // attribute code this game trains, e.g. 'pwr'
  final int rewardPoints; // points awarded on success
  final int successScore; // score needed to pass
  final bool enabled;

  const Game({
    required this.id,
    required this.name,
    required this.type,
    required this.emoji,
    required this.description,
    required this.timeLimitSec,
    required this.difficulty,
    required this.attribute,
    required this.rewardPoints,
    required this.successScore,
    this.enabled = true,
  });

  /// Static v1 catalog. One engine (tapTargets), three difficulty tiers so the
  /// daily task list feels populated while we add more engines later.
  static const List<Game> catalog = [
    Game(
      id: 'tap_easy',
      name: 'Target Practice',
      type: GameType.tapTargets,
      emoji: '🎯',
      description: 'Tap the moving targets before the timer runs out.',
      timeLimitSec: 20,
      difficulty: 'Easy',
      attribute: 'pwr',
      rewardPoints: 10,
      successScore: 10,
    ),
    Game(
      id: 'tap_medium',
      name: 'Sharpshooter',
      type: GameType.tapTargets,
      emoji: '🎯',
      description: 'Faster targets, higher score to clear.',
      timeLimitSec: 30,
      difficulty: 'Medium',
      attribute: 'pwr',
      rewardPoints: 20,
      successScore: 22,
    ),
    Game(
      id: 'tap_hard',
      name: 'Bullseye Frenzy',
      type: GameType.tapTargets,
      emoji: '🎯',
      description: 'Blink and you miss it. For the quick.',
      timeLimitSec: 30,
      difficulty: 'Hard',
      attribute: 'pwr',
      rewardPoints: 35,
      successScore: 34,
    ),
    Game(
      id: 'fruit_medium',
      name: 'Fruit Frenzy',
      type: GameType.fruitSlice,
      emoji: '🍉',
      description: 'Swipe to slice the falling fruit before it drops.',
      timeLimitSec: 30,
      difficulty: 'Medium',
      attribute: 'pwr',
      rewardPoints: 20,
      successScore: 18,
    ),
    Game(
      id: 'find_medium',
      name: 'Spot It',
      type: GameType.findObject,
      emoji: '🔎',
      description: 'Find and tap the matching critter, round after round.',
      timeLimitSec: 30,
      difficulty: 'Medium',
      attribute: 'pwr',
      rewardPoints: 20,
      successScore: 12,
    ),
  ];

  static Game? byId(String id) {
    for (final g in catalog) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Outcome of one play-through.
class GameResult {
  final int score;
  final bool success;
  const GameResult({required this.score, required this.success});
}
