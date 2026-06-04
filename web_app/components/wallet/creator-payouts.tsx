'use client';
import { useEffect, useState } from 'react';
import { doc, onSnapshot, collection, query, orderBy, limit, Timestamp } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '@/lib/firebase';
import { useCreatorBalance } from '@/hooks/use-wallet';
import { creatorTierName, creatorUsdRatePerDiamond } from '@/lib/types';

const MIN_PAYOUT_DIAMONDS = 5000;

interface PayoutRecord {
  id: string;
  usdAmount?: number;
  diamondsBurned?: number;
  status?: string;
  creatorTier?: string;
  requestedAt?: Timestamp;
}

/**
 * Creator Payouts — Stripe Connect onboarding + diamond → USD cash-out for the
 * web wallet. Mirrors the Flutter PayoutsScreen; calls the same Cloud
 * Functions (createConnectAccount / refreshConnectOnboardingLink /
 * requestDiamondPayout).
 */
export function CreatorPayouts({ uid }: { uid: string }) {
  const balance = useCreatorBalance(uid);
  const [status, setStatus] = useState('not_started');
  const [hasAccount, setHasAccount] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [payouts, setPayouts] = useState<PayoutRecord[]>([]);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'users', uid), (snap) => {
      const d = snap.data() ?? {};
      setStatus((d.stripeAccountStatus as string) ?? 'not_started');
      setHasAccount(!!d.stripeAccountId);
    });
    return unsub;
  }, [uid]);

  useEffect(() => {
    const q = query(
      collection(db, 'users', uid, 'payouts'),
      orderBy('requestedAt', 'desc'),
      limit(20),
    );
    const unsub = onSnapshot(
      q,
      (snap) => setPayouts(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<PayoutRecord, 'id'>) }))),
      () => {},
    );
    return unsub;
  }, [uid]);

  const diamonds = balance.diamonds;
  const rate = creatorUsdRatePerDiamond(balance.lifetimeDiamonds);
  const tier = creatorTierName(balance.lifetimeDiamonds);
  const canCashOut = status === 'active' && diamonds >= MIN_PAYOUT_DIAMONDS;

  const onboard = async () => {
    setBusy(true); setError(null);
    try {
      const fn = httpsCallable(functions, hasAccount ? 'refreshConnectOnboardingLink' : 'createConnectAccount');
      const res = await fn({});
      const url = (res.data as { onboardingUrl?: string })?.onboardingUrl;
      if (!url) throw new Error('No onboarding URL returned');
      window.location.href = url;
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  const cashOut = async () => {
    if (!window.confirm(`Cash out all ${diamonds.toLocaleString()} 💎 for ~$${(diamonds * rate).toFixed(2)}? Funds transfer to your bank via Stripe.`)) return;
    setBusy(true); setError(null); setSuccess(null);
    try {
      const res = await httpsCallable(functions, 'requestDiamondPayout')({});
      const d = res.data as { usdAmount?: number; diamondsBurned?: number };
      setSuccess(`Paid out $${(d.usdAmount ?? diamonds * rate).toFixed(2)} (${(d.diamondsBurned ?? diamonds).toLocaleString()} 💎). Funds are on the way to your bank.`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  const statusBadge = {
    active: ['Active', 'text-emerald-400 bg-emerald-500/15'],
    pending: ['Pending', 'text-[#FFD166] bg-[#FFD166]/15'],
    restricted: ['Restricted', 'text-red-400 bg-red-500/15'],
  }[status] ?? ['Not set up', 'text-white/50 bg-white/10'];

  const ctaLabel = { active: 'Update payout details', restricted: 'Resolve payout issues', pending: 'Continue Stripe onboarding' }[status] ?? 'Set up payouts';

  return (
    <div className="bg-zinc-900 border border-white/10 rounded-xl p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-bold text-white">Creator Payouts</h2>
        <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${statusBadge[1]}`}>{statusBadge[0]}</span>
      </div>

      <div className="flex items-baseline gap-3">
        <span className="text-2xl">💎</span>
        <span className="text-2xl font-bold text-white">{diamonds.toLocaleString()}</span>
        <span className="text-sm text-white/50">≈ ${(diamonds * rate).toFixed(2)}</span>
      </div>
      <p className="text-[11px] text-white/40">
        {tier} tier: 1 💎 = ${rate.toFixed(3)}. Minimum payout {MIN_PAYOUT_DIAMONDS.toLocaleString()} 💎.
        Higher lifetime volume unlocks Partner & Elite rates.
      </p>

      {success && (
        <div className="bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs rounded-lg p-3">{success}</div>
      )}
      {error && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-400 text-xs rounded-lg p-3">{error}</div>
      )}

      {canCashOut ? (
        <button onClick={cashOut} disabled={busy}
          className="w-full py-3 bg-green-600 hover:bg-green-700 disabled:opacity-50 rounded-xl font-bold text-sm transition">
          {busy ? 'Processing…' : `Cash out ${diamonds.toLocaleString()} 💎 → $${(diamonds * rate).toFixed(2)}`}
        </button>
      ) : status === 'active' ? (
        <p className="text-xs text-white/40">
          Reach {MIN_PAYOUT_DIAMONDS.toLocaleString()} 💎 to cash out — {(MIN_PAYOUT_DIAMONDS - diamonds).toLocaleString()} to go.
        </p>
      ) : (
        <button onClick={onboard} disabled={busy}
          className="w-full py-3 bg-[#FF7043] hover:bg-[#e55a2b] disabled:opacity-50 rounded-xl font-bold text-sm transition">
          {busy ? 'Opening Stripe…' : ctaLabel}
        </button>
      )}

      {status === 'active' && hasAccount && (
        <button onClick={onboard} disabled={busy}
          className="w-full text-[11px] text-white/40 hover:text-white/70 transition">
          Update payout details
        </button>
      )}

      {payouts.length > 0 && (
        <div className="pt-2 border-t border-white/10">
          <p className="text-[10px] font-semibold text-white/40 uppercase tracking-wider mb-2">Payout history</p>
          <div className="space-y-2">
            {payouts.map((p) => {
              const s = p.status ?? 'pending';
              const sc = s === 'paid' ? 'text-emerald-400' : s === 'failed' ? 'text-red-400' : 'text-[#FFD166]';
              const when = p.requestedAt?.toDate?.().toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) ?? '—';
              return (
                <div key={p.id} className="flex items-center justify-between text-sm">
                  <div>
                    <span className="text-white font-semibold">${(p.usdAmount ?? 0).toFixed(2)}</span>
                    <span className="text-white/40"> · {(p.diamondsBurned ?? 0).toLocaleString()} 💎</span>
                    <span className="block text-[11px] text-white/40">{when}</span>
                  </div>
                  <span className={`text-[11px] font-bold capitalize ${sc}`}>{s}</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
