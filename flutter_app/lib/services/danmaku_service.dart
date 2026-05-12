import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

// Firebase Realtime Database for high-frequency danmaku messages
class DanmakuService {
  final _rtdb = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  DatabaseReference _roomRef(String streamId) =>
      _rtdb.ref('danmaku/$streamId');

  Stream<ChatMessage> watchMessages(String streamId) {
    return _roomRef(streamId)
        .orderByChild('sentAt')
        .limitToLast(200)
        .onChildAdded
        .map((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return ChatMessage.fromJson({...data, 'id': event.snapshot.key ?? ''});
    });
  }

  Future<void> sendMessage({
    required String streamId,
    required String authorUid,
    required String authorUsername,
    String? authorAvatarUrl,
    required String text,
    String type = 'chat',
  }) async {
    final id = _uuid.v4();
    await _roomRef(streamId).child(id).set(ChatMessage(
          id: id,
          streamId: streamId,
          authorUid: authorUid,
          authorUsername: authorUsername,
          authorAvatarUrl: authorAvatarUrl,
          text: text,
          type: type,
          sentAt: DateTime.now(),
        ).toJson());
  }

  Future<void> cleanupRoom(String streamId) async {
    await _roomRef(streamId).remove();
  }
}
