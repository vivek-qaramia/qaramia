/**
 * In-app purchase receipt validation for Qaramia coin packs.
 *
 * Two callables — validateApplePurchase and validateGooglePurchase — each
 * verify a receipt with the respective platform, then atomically credit
 * the user's coin wallet. Idempotent: each transaction ID is recorded at
 * users/{uid}/iapTransactions/{platform}_{transactionId} and double-
 * crediting is impossible if the client retries.
 *
 * Required secrets (firebase functions:secrets:set):
 *   APPLE_IAP_SHARED_SECRET       — App Store Connect → App-Specific Shared Secret
 *   GOOGLE_PLAY_SERVICE_ACCOUNT   — base64-encoded JSON of a service account with
 *                                   the androidpublisher.purchases.products scope.
 *                                   Create via Google Cloud Console + grant access
 *                                   in Play Console → Settings → API access.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

const APPLE_VERIFY_PROD    = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt';

// Mirror of Flutter's CoinPack.catalog. Keep in sync — these are the only
// product IDs we'll credit, and the coin amounts viewers actually receive.
const COIN_PACKS = {
  'com.streamr.streamr.coins.starter': { coins:   100 },
  'com.streamr.streamr.coins.casual':  { coins:   550 },
  'com.streamr.streamr.coins.regular': { coins:  1200 },
  'com.streamr.streamr.coins.power':   { coins:  3300 },
  'com.streamr.streamr.coins.whale':   { coins: 14000 },
};

// ── Apple receipt validation ─────────────────────────────────────────────────
async function verifyAppleReceipt(receiptData) {
  const sharedSecret = process.env.APPLE_IAP_SHARED_SECRET;
  if (!sharedSecret) {
    throw new functions.https.HttpsError('failed-precondition',
      'APPLE_IAP_SHARED_SECRET not configured');
  }

  const body = JSON.stringify({
    'receipt-data': receiptData,
    'password': sharedSecret,
    'exclude-old-transactions': true,
  });

  // Apple recommends always trying production first; status 21007 → retry sandbox
  let res = await fetch(APPLE_VERIFY_PROD, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });
  let data = await res.json();
  if (data.status === 21007) {
    res = await fetch(APPLE_VERIFY_SANDBOX, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    });
    data = await res.json();
  }
  return data;
}

exports.validateApplePurchase = functions
  .runWith({ secrets: ['APPLE_IAP_SHARED_SECRET'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const uid = context.auth.uid;
    const { receiptData, productId } = data || {};
    if (!receiptData || !productId) {
      throw new functions.https.HttpsError('invalid-argument',
        'receiptData and productId required.');
    }

    const pack = COIN_PACKS[productId];
    if (!pack) {
      throw new functions.https.HttpsError('invalid-argument',
        `Unknown product: ${productId}`);
    }

    const result = await verifyAppleReceipt(receiptData);
    if (result.status !== 0) {
      throw new functions.https.HttpsError('failed-precondition',
        `Apple verifyReceipt status ${result.status}`);
    }

    // The receipt may contain multiple transactions; pick the one matching
    // this productId. For consumables, latest_receipt_info holds them.
    const transactions = result.latest_receipt_info
      || (result.receipt && result.receipt.in_app)
      || [];
    const tx = transactions.find((t) => t.product_id === productId);
    if (!tx) {
      throw new functions.https.HttpsError('not-found',
        'Matching transaction not in receipt.');
    }

    return creditCoins({
      uid,
      platform: 'apple',
      transactionId: tx.transaction_id,
      productId,
      coins: pack.coins,
    });
  });

// ── Google Play purchase validation ──────────────────────────────────────────
function getAndroidPublisherClient() {
  const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT;
  if (!raw) {
    throw new functions.https.HttpsError('failed-precondition',
      'GOOGLE_PLAY_SERVICE_ACCOUNT not configured');
  }
  // Accept either raw JSON or base64-encoded JSON
  const json = raw.trim().startsWith('{')
    ? raw
    : Buffer.from(raw, 'base64').toString('utf-8');
  const credentials = JSON.parse(json);

  const auth = new google.auth.JWT({
    email: credentials.client_email,
    key: credentials.private_key,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({ version: 'v3', auth });
}

exports.validateGooglePurchase = functions
  .runWith({ secrets: ['GOOGLE_PLAY_SERVICE_ACCOUNT'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const uid = context.auth.uid;
    const { purchaseToken, productId, packageName } = data || {};
    if (!purchaseToken || !productId || !packageName) {
      throw new functions.https.HttpsError('invalid-argument',
        'purchaseToken, productId, packageName required.');
    }

    const pack = COIN_PACKS[productId];
    if (!pack) {
      throw new functions.https.HttpsError('invalid-argument',
        `Unknown product: ${productId}`);
    }

    const publisher = getAndroidPublisherClient();
    let response;
    try {
      response = await publisher.purchases.products.get({
        packageName,
        productId,
        token: purchaseToken,
      });
    } catch (err) {
      throw new functions.https.HttpsError('failed-precondition',
        `Google Play verify failed: ${err.message}`);
    }
    const purchase = response.data;
    // purchaseState: 0 = Purchased, 1 = Cancelled, 2 = Pending
    if (purchase.purchaseState !== 0) {
      throw new functions.https.HttpsError('failed-precondition',
        `Purchase not completed: state=${purchase.purchaseState}`);
    }

    return creditCoins({
      uid,
      platform: 'google',
      transactionId: purchase.orderId,
      productId,
      coins: pack.coins,
    });
  });

// ── Idempotent wallet credit ─────────────────────────────────────────────────
async function creditCoins({ uid, platform, transactionId, productId, coins }) {
  if (!transactionId) {
    throw new functions.https.HttpsError('failed-precondition',
      'Missing transactionId on validated receipt.');
  }
  const db = admin.firestore();
  const txRef = db
    .collection('users').doc(uid)
    .collection('iapTransactions').doc(`${platform}_${transactionId}`);
  const walletRef = db
    .collection('users').doc(uid)
    .collection('wallet').doc('default');

  // Run as a transaction so the existence-check + credit happen atomically.
  return db.runTransaction(async (t) => {
    const existing = await t.get(txRef);
    if (existing.exists) {
      return { alreadyCredited: true, coins };
    }
    t.set(txRef, {
      platform,
      productId,
      transactionId,
      coins,
      purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    t.set(walletRef, {
      coins: admin.firestore.FieldValue.increment(coins),
      lifetimeCoinsPurchased: admin.firestore.FieldValue.increment(coins),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { credited: true, coins };
  });
}
