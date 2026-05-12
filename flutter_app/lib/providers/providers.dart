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

// Services
final authServiceProvider = Provider((ref) => AuthService());
final streamServiceProvider = Provider((ref) => StreamService());
final videoServiceProvider = Provider((ref) => VideoService());
final userServiceProvider = Provider((ref) => UserService());
final danmakuServiceProvider = Provider((ref) => DanmakuService());

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
