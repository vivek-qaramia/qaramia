'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { collection, query, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { Video } from '@/lib/types';
import { formatDistanceToNow } from 'date-fns';

export function VideoGrid() {
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'videos'), orderBy('createdAt', 'desc'), limit(24));
    const unsub = onSnapshot(q, (snap) => {
      setVideos(snap.docs.map((d) => ({
        ...d.data(),
        id: d.id,
        createdAt: d.data().createdAt?.toDate(),
      })) as Video[]);
      setLoading(false);
    });
    return unsub;
  }, []);

  return (
    <section>
      <h2 className="text-xl font-bold mb-4">Videos For You</h2>

      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
          {[...Array(12)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="aspect-[9/16] bg-white/10 rounded-lg mb-2" />
              <div className="h-3 bg-white/10 rounded w-3/4 mb-1" />
              <div className="h-3 bg-white/10 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : videos.length === 0 ? (
        <p className="text-white/40">No videos yet.</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
          {videos.map((video) => (
            <VideoCard key={video.id} video={video} />
          ))}
        </div>
      )}
    </section>
  );
}

function VideoCard({ video }: { video: Video }) {
  const fmt = (n: number) =>
    n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${(n / 1_000).toFixed(1)}K` : `${n}`;

  return (
    <Link href={`/video/${video.id}`} className="group cursor-pointer block">
      <div className="relative aspect-[9/16] bg-zinc-900 rounded-lg overflow-hidden mb-2">
        {video.thumbnailUrl ? (
          <img src={video.thumbnailUrl} alt="" className="w-full h-full object-cover group-hover:scale-105 transition duration-300" />
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-zinc-800 to-zinc-900 flex items-center justify-center">
            <svg className="w-8 h-8 text-white/20" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </div>
        )}
        <div className="absolute bottom-2 left-2 flex items-center gap-1 text-white text-xs">
          <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/></svg>
          {fmt(video.viewCount)}
        </div>
      </div>
      <div className="flex gap-2">
        <div className="w-8 h-8 rounded-full bg-zinc-700 flex-shrink-0 overflow-hidden">
          {video.authorAvatarUrl && <img src={video.authorAvatarUrl} alt="" className="w-full h-full object-cover" />}
        </div>
        <div className="overflow-hidden">
          <p className="text-sm font-medium truncate">{video.caption || '(no caption)'}</p>
          <p className="text-xs text-white/40">@{video.authorUsername} · {video.createdAt ? formatDistanceToNow(video.createdAt, { addSuffix: true }) : ''}</p>
        </div>
      </div>
      <div className="flex gap-3 mt-1 text-xs text-white/40">
        <span>❤️ {fmt(video.likeCount)}</span>
        <span>💬 {fmt(video.commentCount)}</span>
      </div>
    </Link>
  );
}
