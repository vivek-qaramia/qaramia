const functions = require('firebase-functions/v1');

/**
 * Denormalize a streamer's System XP onto their user doc so the leaderboard can
 * sort by it. `level` is a pure, monotonic function of XP on both clients
 * (StreamerStats), so ordering users by `systemXp` == ordering them by level —
 * and unlike `level` (computed) or `attributes` (a map), a scalar XP field is
 * directly queryable with orderBy.
 *
 * Formula MUST stay in sync with StreamerStats on both clients:
 *   xp = followerCount*12 + likeCount + sum(attributes)*5
 *
 * Recomputed on every user-doc write; writes back only when the value actually
 * changes, so the self-triggered re-run terminates on the next pass (same guard
 * pattern as trackPeakViewers). Self-backfilling: any existing user gains
 * `systemXp` the next time their doc is touched (a follow, like, or game play).
 */
exports.updateSystemXp = functions.firestore
  .document('users/{uid}')
  .onWrite(async (change) => {
    if (!change.after.exists) return; // user deleted — nothing to compute
    const d = change.after.data() || {};
    const attributes = d.attributes || {};
    const earnedTotal = Object.values(attributes).reduce(
      (sum, v) => sum + (Number(v) || 0),
      0
    );
    const xp =
      (d.followerCount || 0) * 12 + (d.likeCount || 0) + earnedTotal * 5;
    if (d.systemXp === xp) return; // unchanged — stop the write loop
    await change.after.ref.update({ systemXp: xp });
  });
