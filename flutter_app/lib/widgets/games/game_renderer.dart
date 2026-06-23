import 'package:flutter/widgets.dart';

import '../../models/game.dart';
import 'find_object_game.dart';
import 'fruit_slice_game.dart';
import 'tap_targets_game.dart';

/// Maps a [Game] to its engine widget. Single source of truth so both the Game
/// Zone screen and the in-stream (Phase 2) overlay render every game type —
/// add a new engine here and it appears in both places.
Widget buildGameWidget(Game game, {required void Function(GameResult) onFinish}) {
  switch (game.type) {
    case GameType.tapTargets:
      return TapTargetsGame(game: game, onFinish: onFinish);
    case GameType.fruitSlice:
      return FruitSliceGame(game: game, onFinish: onFinish);
    case GameType.findObject:
      return FindObjectGame(game: game, onFinish: onFinish);
  }
}
