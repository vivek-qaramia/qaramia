import { NextRequest, NextResponse } from 'next/server';
import { getStripe } from '@/lib/stripe';
import { COIN_PACKS } from '@/lib/types';

export async function POST(request: NextRequest) {
  const { packId, uid } = await request.json() as { packId: string; uid: string };

  const pack = COIN_PACKS.find(p => p.id === packId);
  if (!pack || !uid) {
    return NextResponse.json({ error: 'Invalid packId or uid' }, { status: 400 });
  }

  const stripe = getStripe();
  if (!stripe) {
    return NextResponse.json({
      error: 'Stripe not configured. Set STRIPE_SECRET_KEY in .env.local.',
    }, { status: 503 });
  }

  const origin = request.headers.get('origin') ?? request.nextUrl.origin;
  const totalCoins = pack.coins + pack.bonusCoins;

  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        quantity: 1,
        price_data: {
          currency: 'usd',
          unit_amount: Math.round(pack.priceUsd * 100),
          product_data: {
            name: `${pack.label} Coin Pack`,
            description: pack.bonusCoins > 0
              ? `${pack.coins.toLocaleString()} coins + ${pack.bonusCoins.toLocaleString()} bonus = ${totalCoins.toLocaleString()} total`
              : `${pack.coins.toLocaleString()} coins`,
          },
        },
      }],
      success_url: `${origin}/wallet?status=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url:  `${origin}/wallet?status=cancel`,
      metadata: {
        uid,
        packId: pack.id,
        coins: String(totalCoins),
        priceUsd: String(pack.priceUsd),
      },
    });
    return NextResponse.json({ url: session.url, sessionId: session.id });
  } catch (err) {
    console.error('Stripe checkout session creation failed', err);
    return NextResponse.json({ error: 'Checkout creation failed' }, { status: 500 });
  }
}
