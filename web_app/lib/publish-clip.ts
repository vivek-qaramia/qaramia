import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { storage, db } from '@/lib/firebase';
import type { ZoomMarker, TextOverlay, StickerOverlay } from '@/lib/types';

export interface ClipAuthor {
  uid: string;
  username: string;
  avatarUrl?: string | null;
}

/** Post-stream editor effects, all stored as metadata (mirrors Flutter). */
export interface ClipEffects {
  filterId?: string;
  zooms?: ZoomMarker[];
  blurAmount?: number;
  vignetteIntensity?: number;
  textOverlays?: TextOverlay[];
  stickers?: StickerOverlay[];
  trimStartMs?: number;
  trimEndMs?: number;
}

/**
 * Upload a recorded broadcast clip + thumbnail to Storage and create the
 * matching videos/{id} doc so it appears in the feed. Web equivalent of the
 * Flutter VideoUploadService.uploadAndPublish (minus the post-stream editor).
 * Returns the new video id.
 */
export async function publishClip(opts: {
  videoBlob: Blob;
  thumbBlob?: Blob | null;
  author: ClipAuthor;
  caption: string;
  effects?: ClipEffects;
}): Promise<string> {
  const { videoBlob, thumbBlob, author, caption, effects = {} } = opts;
  const id = crypto.randomUUID();

  const videoRef = ref(storage, `videos/${id}.webm`);
  await uploadBytes(videoRef, videoBlob, { contentType: videoBlob.type || 'video/webm' });
  const videoUrl = await getDownloadURL(videoRef);

  // Thumbnail is best-effort — the feed/profile fall back to a placeholder.
  let thumbnailUrl: string | null = null;
  if (thumbBlob) {
    try {
      const thumbRef = ref(storage, `videos/${id}_thumb.jpg`);
      await uploadBytes(thumbRef, thumbBlob, { contentType: 'image/jpeg' });
      thumbnailUrl = await getDownloadURL(thumbRef);
    } catch {
      /* skip thumbnail */
    }
  }

  await setDoc(doc(db, 'videos', id), {
    authorUid: author.uid,
    authorUsername: author.username,
    authorAvatarUrl: author.avatarUrl ?? null,
    videoUrl,
    thumbnailUrl,
    caption,
    tags: [],
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    viewCount: 0,
    audioTitle: null,
    // Post-stream editor effects (metadata, applied at playback).
    filterId: effects.filterId ?? 'none',
    zooms: effects.zooms ?? [],
    blurAmount: effects.blurAmount ?? 0,
    vignetteIntensity: effects.vignetteIntensity ?? 0,
    textOverlays: effects.textOverlays ?? [],
    stickers: effects.stickers ?? [],
    trimStartMs: effects.trimStartMs ?? 0,
    trimEndMs: effects.trimEndMs ?? 0,
    createdAt: serverTimestamp(),
  });

  return id;
}
