'use client';
import dynamic from 'next/dynamic';

const LiveView = dynamic(() => import('./live-view'), { ssr: false });

export default function LiveClient({ streamId }: { streamId: string }) {
  return <LiveView streamId={streamId} />;
}
