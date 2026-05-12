'use client';
import dynamic from 'next/dynamic';

const StudioView = dynamic(() => import('./studio-view'), { ssr: false });

export default function StudioClient() {
  return <StudioView />;
}
