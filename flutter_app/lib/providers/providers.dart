import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/live_stream.dart';
import '../models/video.dart';
import '../models/chat_message.dart';
import '../models/gift.dart';
import '../services/auth_service.dart';
import '../services/stream_service.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../services/danmaku_service.dart';
import '../services/gift_catalog_service.dart';

// Services
final authServiceProvider = Provider((ref) => AuthService());
final streamServiceProvider = Provider((ref) => StreamService());
final videoServiceProvider = Provider((ref) => VideoService());
final userServiceProvider = Provider((ref) => UserService());
final danmakuServiceProvider = Provider((ref) => DanmakuService());
final giftCatalogServiceProvider = Provider((ref) => GiftCatalogService());

/// Which bottom-nav tab is currently active. The feed video player watches
/// this and pauses when the user navigates away from the Home tab so audio
/// doesn't keep playing in the background. 0=Home, 1=Discover, 2=Live,
/// 3=Profile (mirrors home_screen.dart's `_tabs` list).
final homeTabIndexProvider = StateProvider<int>((_) => 0);

/// Live gift catalog. Streams from Firestore so ops can add gifts at
/// runtime; falls back to the static [GiftType.catalog] when the
/// collection is empty (pre-seed) or the stream is still loading, so the
/// UI never shows an empty gift panel.
final giftCatalogProvider = Provider<List<GiftType>>((ref) {
  final remote = ref.watch(_remoteGiftCatalogProvider).valueOrNull;
  if (remote == null || remote.isEmpty) return GiftType.catalog;
  return remote;
});

final _remoteGiftCatalogProvider = StreamProvider<List<GiftType>>((ref) {
  return ref.watch(giftCatalogServiceProvider).watchCatalog();
});

// Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(authServiceProvider).getUser(user.uid);
});

// Live streams
final liveStreamsProvider = StreamProvider<List<LiveStream>>((ref) {
  return ref.watch(streamServiceProvider).watchLiveStreams();
});

final singleStreamProvider =
    StreamProvider.family<LiveStream?, String>((ref, streamId) {
  return ref.watch(streamServiceProvider).watchStream(streamId);
});

// Danmaku / chat
final danmakuProvider =
    StreamProvider.family<ChatMessage, String>((ref, streamId) {
  return ref.watch(danmakuServiceProvider).watchMessages(streamId);
});

// Gifts
final giftsProvider =
    StreamProvider.family<List<GiftEvent>, String>((ref, streamId) {
  return ref.watch(streamServiceProvider).watchGifts(streamId);
});

// Top-gifter leaderboard
final topGiftersProvider =
    StreamProvider.family<List<TopGifter>, String>((ref, streamId) {
  return ref.watch(streamServiceProvider).watchTopGifters(streamId);
});

// Video feed
final videoFeedProvider = StreamProvider<List<Video>>((ref) {
  return ref.watch(videoServiceProvider).watchFeed();
});

final userVideosProvider =
    FutureProvider.family<List<Video>, String>((ref, uid) {
  return ref.watch(videoServiceProvider).fetchUserVideos(uid);
});

// User profile
final userProfileProvider =
    StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userServiceProvider).watchUser(uid);
});

final isFollowingProvider =
    FutureProvider.family<bool, ({String currentUid, String targetUid})>(
        (ref, ids) {
  return ref
      .watch(userServiceProvider)
      .isFollowing(ids.currentUid, ids.targetUid);
});

// Danmaku messages list (accumulated in notifier)
class DanmakuNotifier extends StateNotifier<List<ChatMessage>> {
  DanmakuNotifier() : super([]);

  void addMessage(ChatMessage message) {
    // Keep last 100 messages
    state = [...state.takeLast(99), message];
  }

  void clear() => state = [];
}

final danmakuMessagesProvider =
    StateNotifierProvider.family<DanmakuNotifier, List<ChatMessage>, String>(
        (ref, streamId) {
  final notifier = DanmakuNotifier();
  ref.listen(danmakuProvider(streamId), (_, next) {
    next.whenData(notifier.addMessage);
  });
  return notifier;
});

extension on List<ChatMessage> {
  List<ChatMessage> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}
