'use client';
import { useEffect, useState } from 'react';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { Sponsorship } from '@/lib/types';

/**
 * Live list of currently-active sponsorships. The gift panel filters these
 * further per-stream via sponsorshipApplies() (streamer UID + visible
 * products). Mirrors the Flutter activeSponsorshipsProvider.
 */
export function useActiveSponsorships(): Sponsorship[] {
  const [list, setList] = useState<Sponsorship[]>([]);

  useEffect(() => {
    const q = query(collection(db, 'sponsorships'), where('status', '==', 'active'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setList(snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            brandId: x.brandId as string,
            brandName: (x.brandName as string) ?? 'Brand',
            brandLogoUrl: x.brandLogoUrl as string | undefined,
            giftTypeId: x.giftTypeId as string,
            pricingModel: (x.pricingModel as Sponsorship['pricingModel']) ?? 'premium',
            perSendRateUsd: x.perSendRateUsd as number | undefined,
            monthlyRetainerUsd: x.monthlyRetainerUsd as number | undefined,
            viewerDiscount: x.viewerDiscount as number | undefined,
            creatorPayoutUsd: x.creatorPayoutUsd as number | undefined,
            allowedStreamerUids: (x.allowedStreamerUids as string[]) ?? [],
            gateOnKeywords: (x.gateOnKeywords as string[]) ?? [],
            gateOnCategories: (x.gateOnCategories as string[]) ?? [],
            status: (x.status as Sponsorship['status']) ?? 'active',
            totalSendCount: (x.totalSendCount as number) ?? 0,
            totalBrandSpendUsd: (x.totalBrandSpendUsd as number) ?? 0,
            startsAt: x.startsAt?.toDate?.() ?? new Date(0),
            endsAt: x.endsAt?.toDate?.(),
            createdAt: x.createdAt?.toDate?.() ?? new Date(0),
          };
        }));
      },
      () => setList([]),
    );
    return unsub;
  }, []);

  return list;
}
