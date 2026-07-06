'use client';
import type { Game, GameResult } from '@/lib/games';
import { TapTargetsGame } from './tap-targets-game';
import { FruitSliceGame } from './fruit-slice-game';
import { FindObjectGame } from './find-object-game';

// Single dispatch (parity with the Flutter buildGameWidget) — add an engine
// here and the Game Zone renders it.
export function GamePlayer({ game, onFinish }: { game: Game; onFinish: (r: GameResult) => void }) {
  switch (game.type) {
    case 'tapTargets':
      return <TapTargetsGame game={game} onFinish={onFinish} />;
    case 'fruitSlice':
      return <FruitSliceGame game={game} onFinish={onFinish} />;
    case 'findObject':
      return <FindObjectGame game={game} onFinish={onFinish} />;
  }
}
