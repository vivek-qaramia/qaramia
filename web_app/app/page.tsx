import { LiveFeedSection } from '@/components/feed/live-feed-section';
import { VideoGrid } from '@/components/feed/video-grid';

export default function HomePage() {
  return (
    <div className="max-w-7xl mx-auto px-4 py-8 space-y-12">
      <LiveFeedSection />
      <VideoGrid />
    </div>
  );
}
