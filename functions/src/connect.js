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
