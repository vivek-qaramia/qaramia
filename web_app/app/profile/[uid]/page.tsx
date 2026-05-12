'use client';
import { use, useEffect, useState } from 'react';
import { doc, getDoc, collection, query, where, orderBy, getDocs, updateDoc, setDoc, deleteDoc, increment } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { AppUser, Video } from '@/lib/types';
import { useAuthStore } from '@/store/auth-store';
import { formatDistanceToNow } from 'date-fns';

export default function ProfilePage({ params }: { params: Promise<{ uid: string }> }) {
  const { uid } = use(params);
  const { user: currentUser } = useAuthStore();
  const [profile, setProfile] = useState<AppUser | null>(null);
  const [videos, setVideos] = useState<Video[]>([]);
  const [isFollowing, setIsFollowing] = useState(false);
  const [loading, setLoading] = useState(true);

  const isSelf = currentUser?.uid === uid;

  useEffect(() => {
    const load = async () => {
      const snap = await getDoc(doc(db, 'users', uid));
      if (snap.exists()) {
        setProfile({ ...snap.data(), uid: snap.id, createdAt: snap.data().createdAt?.toDate() } as AppUser);
      }
      const vSnap = await getDocs(
        query(collection(db, 'videos'), where('authorUid', '==', uid), orderBy('createdAt', 'desc'))
      );
      setVideos(vSnap.docs.map((d) => ({ ...d.data(), id: d.id, createdAt: d.data().createdAt?.toDate() })) as Video[]);

      if (currentUser && !isSelf) {
        const fSnap = await getDoc(doc(db, 'users', currentUser.uid, 'following', uid));
        setIsFollowing(fSnap.exists());
      }
      setLoading(false);
    };
    load();
  }, [uid, currentUser, isSelf]);

  const toggleFollow = async () => {
    if (!currentUser || isSelf) return;
    const followRef = doc(db, 'users', currentUser.uid, 'following', uid);
    const followerRef = doc(db, 'users', uid, 'followers', currentUser.uid);
    if (isFollowing) {
      await deleteDoc(followRef);
      await deleteDoc(followerRef);
      await updateDoc(doc(db, 'users', currentUser.uid), { followingCount: increment(-1) });
      await updateDoc(doc(db, 'users', uid), { followerCount: increment(-1) });
      setIsFollowing(false);
    } else {
      await setDoc(followRef, { followedAt: new Date() });
      await setDoc(followerRef, { followedAt: new Date() });
      await updateDoc(doc(db, 'users', currentUser.uid), { followingCount: increment(1) });
      await updateDoc(doc(db, 'users', uid), { followerCount: increment(1) });
      setIsFollowing(true);
    }
  };

  const fmt = (n: number) =>
    n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${(n / 1_000).toFixed(1)}K` : `${n}`;

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-3.5rem)]">
        <div className="w-8 h-8 border-2 border-[#FF7043] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!profile) {
    return <div className="text-center py-24 text-white/40">User not found</div>;
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-10">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-8">
        <div className="w-24 h-24 rounded-full bg-zinc-800 overflow-hidden mb-4">
          {profile.avatarUrl ? (
            <img src={profile.avatarUrl} alt="" className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-white/30">
              {profile.displayName[0]}
            </div>
          )}
        </div>
        <h1 className="text-2xl font-bold">{profile.displayName}</h1>
        <p className="text-white/50 text-sm mb-2">@{profile.username}</p>
        {profile.bio && <p className="text-white/70 text-sm max-w-sm">{profile.bio}</p>}

        <div className="flex gap-8 mt-4">
          <div className="text-center"><p className="font-bold text-lg">{fmt(profile.followingCount)}</p><p className="text-white/40 text-xs">Following</p></div>
          <div className="text-center"><p className="font-bold text-lg">{fmt(profile.followerCount)}</p><p className="text-white/40 text-xs">Followers</p></div>
          <div className="text-center"><p className="font-bold text-lg">{fmt(profile.likeCount)}</p><p className="text-white/40 text-xs">Likes</p></div>
        </div>

        {!isSelf && currentUser && (
          <button
            onClick={toggleFollow}
            className={`mt-4 px-8 py-2 rounded-xl font-bold transition ${
              isFollowing ? 'bg-white/10 hover:bg-white/20 text-white' : 'bg-[#FF7043] hover:bg-[#e55a2b] text-white'
            }`}
          >
            {isFollowing ? 'Following' : 'Follow'}
          </button>
        )}
      </div>

      {/* Videos grid */}
      <div>
        <h2 className="font-bold mb-4 text-white/60 text-sm uppercase tracking-wider">{videos.length} Videos</h2>
        {videos.length === 0 ? (
          <p className="text-center text-white/30 py-16">No videos yet</p>
        ) : (
          <div className="grid grid-cols-3 gap-1">
            {videos.map((video) => (
              <div key={video.id} className="relative aspect-[9/16] bg-zinc-900 overflow-hidden group cursor-pointer">
                {video.thumbnailUrl ? (
                  <img src={video.thumbnailUrl} alt="" className="w-full h-full object-cover group-hover:scale-105 transition duration-300" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-white/10">
                    <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                  </div>
                )}
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition" />
                <div className="absolute bottom-2 left-2 text-xs text-white flex items-center gap-1 opacity-0 group-hover:opacity-100 transition">
                  <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5z"/></svg>
                  {video.viewCount.toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
