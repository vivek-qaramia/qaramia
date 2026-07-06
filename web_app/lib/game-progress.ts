import { db } from '@/lib/firebase';
import { doc, updateDoc, increment } from 'firebase/firestore';
import { dayKey, type Game } from '@/lib/games';

// Web port of the Flutter GameService.completeTask — award a successful play's
// points to its attribute and mark it done for today, on the user's own doc.
export async function completeGameTask(opts: {
  uid: string;
  game: Game;
  doneToday: string[];
}): Promise<void> {
  const { uid, game, doneToday } = opts;
  const newDone = Array.from(new Set([...doneToday, game.id]));
  await updateDoc(doc(db, 'users', uid), {
    [`attributes.${game.attribute}`]: increment(game.rewardPoints),
    gameTasksDate: dayKey(new Date()),
    gameTasksDone: newDone,
  });
}
