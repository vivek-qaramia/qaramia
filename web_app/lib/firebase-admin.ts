import { initializeApp, cert, getApps, App } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';

let adminApp: App | null = null;

export function getAdminApp(): App | null {
  if (adminApp) return adminApp;
  if (getApps().length > 0) {
    adminApp = getApps()[0];
    return adminApp;
  }

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (!raw) {
    // No credentials configured — caller must handle this case
    return null;
  }

  try {
    // Accept either raw JSON or base64-encoded JSON
    const json = raw.trim().startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf-8');
    const serviceAccount = JSON.parse(json);
    adminApp = initializeApp({ credential: cert(serviceAccount) });
    return adminApp;
  } catch (err) {
    console.error('Failed to initialise Firebase Admin SDK:', err);
    return null;
  }
}

export function getAdminDb(): Firestore | null {
  const app = getAdminApp();
  return app ? getFirestore(app) : null;
}
