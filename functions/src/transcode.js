/**
 * Transcode web-recorded clips (.webm, VP8/VP9) to .mp4 (H.264/AAC) so they
 * play everywhere — iOS Safari and the Flutter iOS app (AVPlayer) can't decode
 * webm. Mobile already publishes mp4; this unifies the feed.
 *
 * Trigger: Storage finalize on videos/{id}.webm (the web publishClip upload).
 *   1. download the webm to /tmp
 *   2. ffmpeg → mp4 (faststart for streaming)
 *   3. upload videos/{id}.mp4 (with a Firebase download token)
 *   4. point videos/{id}.videoUrl at the mp4, then delete the webm
 *
 * Filters to .webm only, so the mp4 it writes never re-triggers it.
 */
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const os = require('os');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { spawn } = require('child_process');

function runFfmpeg(args) {
  // Lazy-require so the deploy's 10s source analysis doesn't load the binary
  // path at module top-level (firebase "avoid deployment timeouts" guidance —
  // same reason connect.js lazy-requires stripe).
  // eslint-disable-next-line global-require
  const ffmpegPath = require('ffmpeg-static');
  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegPath, args);
    let stderr = '';
    proc.stderr.on('data', (d) => { stderr += d.toString(); });
    proc.on('error', reject);
    proc.on('close', (code) =>
      code === 0 ? resolve() : reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(-800)}`)));
  });
}

// The videos/{id} doc is created by the client just after the webm upload, so
// it usually exists by the time transcoding finishes — but retry briefly in
// case this trigger wins the race.
async function waitForDoc(ref, tries = 6) {
  for (let i = 0; i < tries; i++) {
    if ((await ref.get()).exists) return true;
    await new Promise((r) => setTimeout(r, 1500));
  }
  return false;
}

exports.transcodeClipToMp4 = functions
  .runWith({ memory: '1GB', timeoutSeconds: 300 })
  .storage.object()
  .onFinalize(async (object) => {
    const name = object.name || '';
    if (!name.startsWith('videos/') || !name.endsWith('.webm')) return null;

    const id = path.basename(name, '.webm');
    const bucket = admin.storage().bucket(object.bucket);
    const tmpIn = path.join(os.tmpdir(), `${id}.webm`);
    const tmpOut = path.join(os.tmpdir(), `${id}.mp4`);
    const destPath = `videos/${id}.mp4`;

    try {
      await bucket.file(name).download({ destination: tmpIn });
      await runFfmpeg([
        '-y', '-i', tmpIn,
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '128k',
        '-movflags', '+faststart',
        tmpOut,
      ]);

      const token = crypto.randomUUID();
      await bucket.upload(tmpOut, {
        destination: destPath,
        metadata: {
          contentType: 'video/mp4',
          metadata: { firebaseStorageDownloadTokens: token },
        },
      });
      const mp4Url =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(destPath)}?alt=media&token=${token}`;

      // Extract a thumbnail server-side (best-effort). This is more reliable
      // than the browser, where a tainted canvas can block client thumbnails.
      let thumbnailUrl = null;
      const thumbOut = path.join(os.tmpdir(), `${id}_thumb.jpg`);
      const thumbPath = `videos/${id}_thumb.jpg`;
      try {
        await runFfmpeg(['-y', '-i', tmpOut, '-ss', '0.5', '-vframes', '1', '-q:v', '3', thumbOut]);
        const thumbToken = crypto.randomUUID();
        await bucket.upload(thumbOut, {
          destination: thumbPath,
          metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: thumbToken } },
        });
        thumbnailUrl =
          `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
          `${encodeURIComponent(thumbPath)}?alt=media&token=${thumbToken}`;
      } catch (e) {
        console.warn('thumbnail extract failed', e.message);
      }

      // Point the feed doc at the mp4 BEFORE removing the webm so the URL is
      // never dangling.
      const ref = admin.firestore().collection('videos').doc(id);
      if (await waitForDoc(ref)) {
        await ref.update({
          videoUrl: mp4Url,
          transcoded: true,
          ...(thumbnailUrl ? { thumbnailUrl } : {}),
        });
      } else {
        console.warn(`videos/${id} not found; uploaded mp4 but left doc untouched`);
      }
      try { await bucket.file(name).delete(); } catch (e) { console.warn('webm delete failed', e.message); }
    } finally {
      for (const f of [tmpIn, tmpOut, path.join(os.tmpdir(), `${id}_thumb.jpg`)]) {
        try { fs.unlinkSync(f); } catch (_) { /* not written */ }
      }
    }
    return null;
  });
