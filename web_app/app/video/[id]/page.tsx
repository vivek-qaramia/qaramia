'use client';
import { use, useEffect, useState } from 'react';
import Link from 'next/link';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { ComposedVideo } from '@/components/feed/composed-video';
import type { Video } from '@/lib/types';

/// Full-screen single-video viewer. Reached by clicking a tile in the feed
/// grid or on a profile. Renders the post-stream editor effects (filter,
/// zoom, blur, vignette, text overlays, stickers) via ComposedVideo so
/// the playback experience matches the Flutter feed.
export default function VideoPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [video, setVideo] = useState<Video | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      const snap = await getDoc(doc(db, 'videos', id));
      if (snap.exists()) {
        const data = snap.data();
        setVideo({
          ...data,
          id: snap.id,
          createdAt: data.createdAt?.toDate(),
        } as Video);
      }
      setLoading(false);
    };
    load();
  }, [id]);

  if (loading) {
    return (
      <div className="min-h-[calc(100vh-3.5rem)] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#FF7043] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!video) {
    return (
      <div className="min-h-[calc(100vh-3.5rem)] flex items-center justify-center text-white/60">
        Video not found.
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 space-y-4">
      <Link href="/" className="text-white/60 hover:text-white text-sm">← Back</Link>
      <div className="aspect-[9/16] max-h-[80vh] bg-black rounded-xl overflow-hidden">
        <ComposedVideo video={video} />
      </div>
      <div className="flex gap-3 items-center">
        <div className="w-10 h-10 rounded-full bg-zinc-700 overflow-hidden flex-shrink-0">
          {video.authorAvatarUrl && (
            <img src={video.authorAvatarUrl} alt="" className="w-full h-full object-cover" />
          )}
        </div>
        <div>
          <p className="font-semibold">{video.caption || '(no caption)'}</p>
          <p className="text-white/40 text-sm">@{video.authorUsername}</p>
        </div>
      </div>
    </div>
  );
}
