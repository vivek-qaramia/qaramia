const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

admin.initializeApp();

// IAP receipt validation callables (Apple App Store + Google Play)
const iap = require('./iap');
exports.validateApplePurchase  = iap.validateApplePurchase;
exports.validateGooglePurchase = iap.validateGooglePurchase;

// Stripe Connect onboarding for creator payouts
const connect = require('./connect');
exports.createConnectAccount        = connect.createConnectAccount;
exports.refreshConnectOnboardingLink = connect.refreshConnectOnboardingLink;

// Gift catalog seeding (idempotent rewrite of giftCatalog/* from the
// canonical list in giftCatalog.js).
const giftCatalog = require('./giftCatalog');
exports.seedGiftCatalog = giftCatalog.seedGiftCatalog;

// Generate a short-lived Agora RTC token for a channel.
// Called by both Flutter and Next.js clients before joining a stream.
exports.getAgoraToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
  }

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  // If no certificate is set, return empty token (dev mode — works for testing)
  if (!appCertificate) {
    return { token: '', appId };
  }

  const { channelName, uid = 0, role = 'audience' } = data;
  if (!channelName) {
    throw new functions.https.HttpsError('invalid-argument', 'channelName is required.');
  }

  const rtcRole = role === 'host' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  const expireTime = 3600; // 1 hour
  const currentTime = Math.floor(Date.now() / 1000);
  const privilegeExpireTime = currentTime + expireTime;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    rtcRole,
    privilegeExpireTime
  );

  return { token, appId };
});

// Cleanup ended streams older than 7 days (runs daily)
exports.cleanupOldStreams = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const snap = await db
      .collection('streams')
      .where('status', '==', 'ended')
      .where('endedAt', '<', cutoff)
      .get();

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();

    // Also clean up RTDB danmaku rooms for those streams
    const rtdb = admin.database();
    await Promise.all(
      snap.docs.map((d) => rtdb.ref(`danmaku/${d.id}`).remove())
    );

    console.log(`Cleaned up ${snap.size} old streams.`);
  });

// Recalculate peak viewer count when viewer count updates
exports.trackPeakViewers = functions.firestore
  .document('streams/{streamId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (after.viewerCount > (after.peakViewerCount || 0)) {
      await change.after.ref.update({ peakViewerCount: after.viewerCount });
    }
  });
