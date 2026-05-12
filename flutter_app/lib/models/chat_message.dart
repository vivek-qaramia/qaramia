class ChatMessage {
  final String id;
  final String streamId;
  final String authorUid;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String text;
  final String type; // 'chat' | 'gift' | 'join' | 'system'
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.streamId,
    required this.authorUid,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.text,
    this.type = 'chat',
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        streamId: json['streamId'] as String? ?? '',
        authorUid: json['authorUid'] as String,
        authorUsername: json['authorUsername'] as String,
        authorAvatarUrl: json['authorAvatarUrl'] as String?,
        text: json['text'] as String,
        type: json['type'] as String? ?? 'chat',
        sentAt: json['sentAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['sentAt'] as int)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'authorUid': authorUid,
        'authorUsername': authorUsername,
        'authorAvatarUrl': authorAvatarUrl,
        'text': text,
        'type': type,
        'sentAt': sentAt.millisecondsSinceEpoch,
      };
}
