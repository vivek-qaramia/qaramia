import { NextRequest, NextResponse } from 'next/server';
import { getStripe } from '@/lib/stripe';
import { getAdminDb } from '@/lib/firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import Stripe from 'stripe';

export async function POST(request: NextRequest) {
  const stripe = getStripe();
  const adminDb = getAdminDb();
  const signature = request.headers.get('stripe-signature');
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!stripe || !adminDb || !signature || !webhookSecret) {
    return NextResponse.json({ error: 'Webhook not configured' }, { status: 503 });
  }

  // Stripe requires the raw request body for signature verification
  const rawBody = await request.text();
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const uid = session.metadata?.uid;
    const coins = Number(session.metadata?.coins ?? 0);
    if (!uid || !coins) {
      return NextResponse.json({ error: 'Missing metadata' }, { status: 400 });
    }

    try {
      const walletRef = adminDb.doc(`users/${uid}/wallet/default`);
      await walletRef.set({
        coins: FieldValue.increment(coins),
        lifetimeCoinsPurchased: FieldValue.increment(coins),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (err) {
      console.error('Failed to credit coins for session', session.id, err);
      return NextResponse.json({ error: 'Credit failed' }, { status: 500 });
    }
  }

  return NextResponse.json({ received: true });
}
