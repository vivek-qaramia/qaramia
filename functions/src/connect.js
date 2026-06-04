/**
 * Stripe Connect onboarding for creators.
 *
 * Express accounts: creators redirect to a Stripe-hosted onboarding form
 * (KYC, bank details, identity verification). Once complete, the account
 * is ready to receive diamond-to-USD payouts.
 *
 * Required Firebase secret:
 *   STRIPE_SECRET_KEY — same as web; sk_test_... for dev, sk_live_... for prod
 *
 * Two callables:
 *   createConnectAccount       — creates the account if needed, returns an
 *                                onboarding link
 *   refreshConnectOnboardingLink — fresh link for an existing account
 *                                (used when the previous link expired)
 *
 * The user document at users/{uid} gets a `stripeAccountId` field once the
 * account exists. `stripeAccountStatus` is updated on each callable to one
 * of: not_started, pending, restricted, active.
 */
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

const RETURN_URL = 'https://qaramia.com/connect/return';
const REFRESH_URL = 'https://qaramia.com/connect/refresh';

// Diamond → USD payout floor (5,000 💎 minimum, matches the UI).
const MIN_PAYOUT_DIAMONDS = 5000;

// Tiered creator share: a creator's diamond→USD rate improves with their
// lifetime diamond volume. Mirrored client-side for display in
// flutter_app/lib/models/wallet.dart and web_app/lib/types.ts — keep in sync.
function creatorTier(lifetimeDiamonds) {
  const d = lifetimeDiamonds || 0;
  if (d >= 1000000) return { name: 'Elite', rate: 0.014 };
  if (d >= 100000) return { name: 'Partner', rate: 0.012 };
  return { name: 'Rising', rate: 0.010 };
}

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new functions.https.HttpsError('failed-precondition',
      'STRIPE_SECRET_KEY not configured');
  }
  // Lazy-require so the function still cold-starts if stripe isn't installed
  // in some environments — fail at call time with a clean error instead.
  // eslint-disable-next-line global-require
  return require('stripe')(key);
}

function statusFromAccount(account) {
  if (account.charges_enabled && account.payouts_enabled) return 'active';
  if (account.requirements && account.requirements.disabled_reason) {
    return 'restricted';
  }
  return 'pending';
}

exports.createConnectAccount = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const uid = context.auth.uid;
    const stripe = getStripe();
    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    let accountId = userData.stripeAccountId;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        capabilities: {
          transfers: { requested: true },
        },
        metadata: { qaramiaUid: uid },
        email: context.auth.token.email || undefined,
      });
      accountId = account.id;
      await userRef.set({
        stripeAccountId: accountId,
        stripeAccountStatus: 'pending',
      }, { merge: true });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: REFRESH_URL,
      return_url: RETURN_URL,
      type: 'account_onboarding',
    });

    // Refresh status now we've touched the account
    const account = await stripe.accounts.retrieve(accountId);
    await userRef.update({
      stripeAccountStatus: statusFromAccount(account),
    });

    return {
      accountId,
      onboardingUrl: link.url,
      status: statusFromAccount(account),
    };
  });

exports.refreshConnectOnboardingLink = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const stripe = getStripe();
    const uid = context.auth.uid;
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    const accountId = userDoc.data()?.stripeAccountId;
    if (!accountId) {
      throw new functions.https.HttpsError('failed-precondition',
        'No Stripe Connect account on file — call createConnectAccount first.');
    }
    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: REFRESH_URL,
      return_url: RETURN_URL,
      type: 'account_onboarding',
    });
    const account = await stripe.accounts.retrieve(accountId);
    const status = statusFromAccount(account);
    await userRef.update({ stripeAccountStatus: status });
    return { onboardingUrl: link.url, status };
  });

/**
 * Cash out the creator's FULL diamond balance to their connected Stripe
 * account. Diamonds → USD at the creator's tier rate (see creatorTier), with
 * a MIN_PAYOUT_DIAMONDS floor.
 *
 * Ordering is debit-first so a double-tap / concurrent call can't double-spend:
 *   1. In a Firestore transaction, zero out diamonds and write a `pending`
 *      payouts/{id} ledger row (captures the burned amount).
 *   2. Create the Stripe transfer to the connected account.
 *   3. On success, mark the ledger `paid`; on failure, REFUND the diamonds and
 *      mark the ledger `failed`.
 *
 * The diamond decrement is impossible from the client (creatorBalance rules
 * forbid decreases), so this Admin-SDK path is the only way diamonds leave.
 *
 * Returns: { ok, payoutId, diamondsBurned, usdAmount, transferId }
 */
exports.requestDiamondPayout = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const uid = context.auth.uid;
    const stripe = getStripe();
    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const balRef = userRef.collection('creatorBalance').doc('default');

    const userDoc = await userRef.get();
    const accountId = userDoc.data()?.stripeAccountId;
    if (!accountId) {
      throw new functions.https.HttpsError('failed-precondition',
        'Set up payouts (Stripe Connect) before cashing out.');
    }

    // The connected account must be fully enabled or the transfer would fail.
    const account = await stripe.accounts.retrieve(accountId);
    if (!(account.charges_enabled && account.payouts_enabled)) {
      throw new functions.https.HttpsError('failed-precondition',
        'Your payout account is not active yet — finish Stripe onboarding first.');
    }

    // 1. Debit-first transaction: zero the balance + write a pending ledger row.
    //    The diamond→USD rate is set by the creator's tier (lifetime volume).
    const payoutRef = userRef.collection('payouts').doc();
    let burned = 0;
    let tier = creatorTier(0);
    await db.runTransaction(async (tx) => {
      const balSnap = await tx.get(balRef);
      const bal = balSnap.data() || {};
      const diamonds = bal.diamonds || 0;
      if (diamonds < MIN_PAYOUT_DIAMONDS) {
        throw new functions.https.HttpsError('failed-precondition',
          `Minimum payout is ${MIN_PAYOUT_DIAMONDS} diamonds.`);
      }
      burned = diamonds;
      tier = creatorTier(bal.lifetimeDiamonds || 0);
      tx.update(balRef, {
        diamonds: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(payoutRef, {
        diamondsBurned: burned,
        usdAmount: +(burned * tier.rate).toFixed(2),
        usdRatePerDiamond: tier.rate,
        creatorTier: tier.name,
        stripeAccountId: accountId,
        status: 'pending',
        transferId: null,
        failureReason: null,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        paidAt: null,
      });
    });

    // 2. Move funds platform → connected account. Their payout schedule then
    //    settles to their bank.
    const amountCents = Math.round(burned * tier.rate * 100);
    try {
      const transfer = await stripe.transfers.create({
        amount: amountCents,
        currency: 'usd',
        destination: accountId,
        metadata: { qaramiaUid: uid, payoutId: payoutRef.id },
      });
      await payoutRef.update({
        status: 'paid',
        transferId: transfer.id,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        ok: true,
        payoutId: payoutRef.id,
        diamondsBurned: burned,
        usdAmount: +(burned * tier.rate).toFixed(2),
        creatorTier: tier.name,
        transferId: transfer.id,
      };
    } catch (err) {
      // 3. Refund so the creator never loses diamonds on a failed transfer.
      await balRef.update({
        diamonds: admin.firestore.FieldValue.increment(burned),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await payoutRef.update({
        status: 'failed',
        failureReason: String((err && err.message) || err),
      });
      throw new functions.https.HttpsError('internal',
        `Payout transfer failed: ${(err && err.message) || err}`);
    }
  });
