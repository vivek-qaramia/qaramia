const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

/**
 * Canonical gift catalog. Must match
 * flutter_app/lib/models/gift.dart's GiftType.catalog so the in-app static
 * fallback stays in lockstep with whatever this seeds into Firestore.
 *
 * When you want to add / change / remove a gift in production:
 *   1. Update this list AND the Flutter static fallback in lockstep
 *   2. Deploy this function: `firebase deploy --only functions:seedGiftCatalog`
 *   3. Call it from the Firebase Console "Test" tab (or an admin tool)
 *   4. Release a Flutter build so offline / Firestore-unreachable clients
 *      see the new gift
 */
const SEED = [
  // Standard tier
  { id: 'rose',      name: 'Rose',      emoji: '🌹', coinCost: 1,     diamondYield: 0,     tier: 'standard', animationAsset: 'rose' },
  { id: 'heart',     name: 'Heart',     emoji: '❤️', coinCost: 5,     diamondYield: 2,     tier: 'standard', animationAsset: 'heart' },
  { id: 'star',      name: 'Star',      emoji: '⭐', coinCost: 10,    diamondYield: 5,     tier: 'standard', animationAsset: 'star' },
  { id: 'lollipop',  name: 'Lollipop',  emoji: '🍭', coinCost: 25,    diamondYield: 12,    tier: 'standard', animationAsset: 'lollipop' },
  { id: 'rocket',    name: 'Rocket',    emoji: '🚀', coinCost: 50,    diamondYield: 25,    tier: 'standard', animationAsset: 'rocket' },
  // Premium tier
  { id: 'crown',     name: 'Crown',     emoji: '👑', coinCost: 100,   diamondYield: 50,    tier: 'premium', animationAsset: 'crown' },
  { id: 'bouquet',   name: 'Bouquet',   emoji: '💐', coinCost: 500,   diamondYield: 250,   tier: 'premium', animationAsset: 'bouquet' },
  { id: 'diamond',   name: 'Diamond',   emoji: '💎', coinCost: 500,   diamondYield: 250,   tier: 'premium', animationAsset: 'diamond' },
  { id: 'universe',  name: 'Universe',  emoji: '🌌', coinCost: 1000,  diamondYield: 500,   tier: 'premium', animationAsset: 'universe' },
  { id: 'sportscar', name: 'Sports Car',emoji: '🏎️', coinCost: 2000,  diamondYield: 1000,  tier: 'premium', animationAsset: 'sportscar' },
  // Whale tier
  { id: 'yacht',     name: 'Yacht',     emoji: '🛥️', coinCost: 5000,  diamondYield: 2500,  tier: 'whale', animationAsset: 'yacht' },
  { id: 'castle',    name: 'Castle',    emoji: '🏰', coinCost: 10000, diamondYield: 5000,  tier: 'whale', animationAsset: 'castle' },
  { id: 'lion',      name: 'Lion',      emoji: '🦁', coinCost: 30000, diamondYield: 15000, tier: 'whale', animationAsset: 'lion' },
];

/**
 * Idempotently writes the SEED above into Firestore `giftCatalog/{giftId}`.
 * Safe to call repeatedly — uses `set` (not `update`) so each call fully
 * resets every doc to the canonical state above.
 *
 * Currently ungated to unblock the initial seed (the auth context wasn't
 * being parsed correctly on a v1 callable invoked from Flutter
 * cloud_functions ^5.1.3 — got UNAUTHENTICATED despite signed-in user).
 *
 * Worst-case "attack" is a stranger re-writing the same canonical data.
 * Low risk; deterministic blast radius. TODO production: gate on a
 * `role === 'admin'` custom claim from a proper admin-tool deployment.
 */
exports.seedGiftCatalog = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  const batch = db.batch();
  for (const gift of SEED) {
    const ref = db.collection('giftCatalog').doc(gift.id);
    batch.set(ref, {
      name: gift.name,
      emoji: gift.emoji,
      coinCost: gift.coinCost,
      diamondYield: gift.diamondYield,
      tier: gift.tier,
      animationAsset: gift.animationAsset,
      seededAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return { written: SEED.length };
});
