import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/video.dart' show StickerOverlay, TextOverlay, ZoomMarker;
import 'video_trim_service.dart';

/// Uploads a trimmed mp4 to Firebase Storage and writes the matching
/// `videos/{id}` Firestore doc that the home feed reads from.
class VideoUploadService {
  final _storage = FirebaseStorage.instance;
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Returns the newly-created videoId. Throws on failure.
  ///
  /// [onProgress] is called with a 0.0–1.0 value during the upload so the UI
  /// can render a progress bar. Phase 2 publishes immediately as public; we
  /// will add a draft / visibility toggle later if needed.
  Future<String> uploadAndPublish({
    required File file,
    required String authorUid,
    required String authorUsername,
    String? authorAvatarUrl,
    String caption = '',
    String filterId = 'none',
    List<ZoomMarker> zooms = const [],
    double blurAmount = 0,
    double vignetteIntensity = 0,
    List<TextOverlay> textOverlays = const [],
    List<StickerOverlay> stickers = const [],
    void Function(double progress)? onProgress,
  }) async {
    final videoId = _uuid.v4();
    final ref = _storage.ref().child('videos/$videoId.mp4');

    // Debug-only: log the compressed size we're about to upload so the shrink
    // can be verified on real footage via `adb logcat | grep Upload`.
    if (kDebugMode) {
      debugPrint('[Upload] publishing ${await file.length()} bytes → videos/$videoId.mp4');
    }

    final task = ref.putFile(file);
    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }
    await task;
    final videoUrl = await ref.getDownloadURL();

    // Best-effort thumbnail. Failures don't block publish — the Profile grid
    // falls back to a placeholder icon when thumbnailUrl is null.
    String? thumbnailUrl;
    File? thumbFile;
    try {
      final thumbPath = await VideoTrimService().generateThumbnail(
        inputPath: file.path,
      );
      thumbFile = File(thumbPath);
      final thumbRef = _storage.ref().child('videos/${videoId}_thumb.jpg');
      await thumbRef.putFile(thumbFile);
      thumbnailUrl = await thumbRef.getDownloadURL();
    } catch (_) {
      // Skip thumbnail; the rest of the publish proceeds normally.
    } finally {
      if (thumbFile != null) {
        try { await thumbFile.delete(); } catch (_) {}
      }
    }

    await _db.collection('videos').doc(videoId).set({
      'authorUid': authorUid,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'tags': const <String>[],
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'viewCount': 0,
      'audioTitle': null,
      'filterId': filterId,
      'zooms': zooms.map((z) => z.toJson()).toList(),
      'blurAmount': blurAmount,
      'vignetteIntensity': vignetteIntensity,
      'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
      'stickers': stickers.map((s) => s.toJson()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return videoId;
  }
}
