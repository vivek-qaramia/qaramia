'use client';
import Link from 'next/link';
import { useLiveStreams } from '@/hooks/use-live-stream';

export default function LivePage() {
  const { streams, loading } = useLiveStreams();

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
          <h1 className="text-2xl font-bold">Live Streams</h1>
          {!loading && <span className="text-white/40">{streams.length} live</span>}
        </div>
        <Link
          href="/studio"
          className="px-5 py-2 bg-[#FF7043] hover:bg-[#e55a2b] rounded-lg font-semibold text-sm transition flex items-center gap-2"
        >
          <span>📡</span> Go Live
        </Link>
      </div>

      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {[...Array(8)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="aspect-video bg-white/10 rounded-xl mb-3" />
              <div className="h-4 bg-white/10 rounded w-3/4 mb-2" />
              <div className="h-3 bg-white/10 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : streams.length === 0 ? (
        <div className="text-center py-24 space-y-4">
          <div className="text-6xl">📡</div>
          <h2 className="text-xl font-semibold text-white/60">No live streams right now</h2>
          <p className="text-white/30">Be the first to go live!</p>
          <Link href="/studio" className="inline-block mt-4 px-6 py-3 bg-[#FF7043] rounded-xl font-bold hover:bg-[#e55a2b] transition">
            Start Streaming
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {streams.map((stream) => (
            <Link key={stream.id} href={`/live/${stream.id}`} className="group block">
              <div className="relative aspect-video bg-zinc-900 rounded-xl overflow-hidden mb-3">
                {stream.thumbnailUrl ? (
                  <img src={stream.thumbnailUrl} alt="" className="w-full h-full object-cover group-hover:scale-105 transition duration-300" />
                ) : (
                  <div className="w-full h-full bg-gradient-to-br from-purple-900 to-indigo-900 flex items-center justify-center text-4xl font-bold text-white/20">
                    {stream.hostUsername[0].toUpperCase()}
                  </div>
                )}
                <span className="absolute top-2 left-2 px-2 py-0.5 bg-[#FF7043] text-white text-xs font-bold rounded">LIVE</span>
                <span className="absolute top-2 right-2 px-2 py-0.5 bg-black/60 text-white text-xs rounded flex items-center gap-1">
                  👁 {stream.viewerCount.toLocaleString()}
                </span>
                <div className="absolute bottom-2 left-2 px-2 py-0.5 bg-black/60 text-white text-xs rounded">
                  {stream.category}
                </div>
              </div>
              <div className="flex gap-3">
                <div className="w-9 h-9 rounded-full bg-zinc-700 overflow-hidden flex-shrink-0">
                  {stream.hostAvatarUrl && <img src={stream.hostAvatarUrl} alt="" className="w-full h-full object-cover" />}
                </div>
                <div>
                  <p className="font-semibold text-sm line-clamp-1">{stream.title}</p>
                  <p className="text-white/40 text-xs">@{stream.hostUsername}</p>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
