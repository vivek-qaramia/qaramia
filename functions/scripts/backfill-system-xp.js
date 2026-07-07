/**
 * One-time backfill: compute `systemXp` for every existing user so the
 * leaderboard is populated immediately, instead of waiting for organic writes
 * to fire the updateSystemXp trigger. Idempotent — safe to re-run (skips docs
 * whose value already matches, and the trigger's own guard makes the resulting
 * re-writes no-ops).
 *
 * Formula MUST match systemXp.js / StreamerStats:
 *   xp = followerCount*12 + likeCount + sum(attributes)*5
 *
 * Run once, AFTER deploying updateSystemXp:
 *   cd functions
 *   # Application Default Credentials must be available. If not already set:
 *   #   gcloud auth application-default login
 *   # (or point GOOGLE_APPLICATION_CREDENTIALS at a service-account key)
 *   node scripts/backfill-system-xp.js
 */
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'qaramia-4c405' });
const db = admin.firestore();

function systemXpOf(d) {
  const attributes = d.attributes || {};
  const earned = Object.values(attributes).reduce((s, v) => s + (Number(v) || 0), 0);
  return (d.followerCount || 0) * 12 + (d.likeCount || 0) + earned * 5;
}

(async () => {
  const snap = await db.collection('users').get();
  let updated = 0;
  let batch = db.batch();
  let pending = 0;
  for (const doc of snap.docs) {
    const xp = systemXpOf(doc.data());
    if (doc.data().systemXp === xp) continue; // already correct
    batch.update(doc.ref, { systemXp: xp });
    updated++;
    pending++;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  console.log(`Backfilled systemXp for ${updated}/${snap.size} users.`);
  process.exit(0);
})().catch((e) => {
  console.error('Backfill failed:', e.message || e);
  process.exit(1);
});
