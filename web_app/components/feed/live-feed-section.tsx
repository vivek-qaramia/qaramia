'use client';
import Link from 'next/link';
import { useLiveStreams } from '@/hooks/use-live-stream';

export function LiveFeedSection() {
  const { streams, loading } = useLiveStreams();

  return (
    <section>
      <div className="flex items-center gap-3 mb-4">
        <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
        <h2 className="text-xl font-bold">Live Now</h2>
        {!loading && <span className="text-white/40 text-sm">{streams.length} streams</span>}
      </div>

      {loading ? (
        <div className="flex gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="w-40 animate-pulse">
              <div className="w-40 h-40 rounded-full bg-white/10 mb-2" />
              <div className="h-3 bg-white/10 rounded w-24 mx-auto" />
            </div>
          ))}
        </div>
      ) : streams.length === 0 ? (
        <p className="text-white/40">No live streams right now.</p>
      ) : (
        <div className="flex gap-6 overflow-x-auto pb-2 scrollbar-hide">
          {streams.map((stream) => (
            <Link
              key={stream.id}
              href={`/live/${stream.id}`}
              className="flex-shrink-0 flex flex-col items-center gap-2 group"
            >
              <div className="relative">
                <div className="w-20 h-20 rounded-full overflow-hidden ring-2 ring-[#FF7043] ring-offset-2 ring-offset-black">
                  {stream.hostAvatarUrl ? (
                    <img src={stream.hostAvatarUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-br from-purple-700 to-indigo-900 flex items-center justify-center text-2xl font-bold">
                      {stream.hostUsername[0].toUpperCase()}
                    </div>
                  )}
                </div>
                <span className="absolute -bottom-1 left-1/2 -translate-x-1/2 px-2 py-0.5 bg-[#FF7043] text-white text-[10px] font-bold rounded uppercase">
                  live
                </span>
              </div>
              <div className="text-center">
                <p className="text-xs font-semibold truncate w-24 text-center">@{stream.hostUsername}</p>
                <p className="text-[10px] text-white/40">{stream.viewerCount.toLocaleString()} watching</p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </section>
  );
}
