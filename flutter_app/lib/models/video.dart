import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String authorUid;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final String? audioTitle;
  final DateTime createdAt;

  const Video({
    required this.id,
    required this.authorUid,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.audioTitle,
    required this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'] as String,
        authorUid: json['authorUid'] as String,
        authorUsername: json['authorUsername'] as String,
        authorAvatarUrl: json['authorAvatarUrl'] as String?,
        videoUrl: json['videoUrl'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        caption: json['caption'] as String? ?? '',
        tags: List<String>.from(json['tags'] as List? ?? []),
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        audioTitle: json['audioTitle'] as String?,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorUid': authorUid,
        'authorUsername': authorUsername,
        'authorAvatarUrl': authorAvatarUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'tags': tags,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'shareCount': shareCount,
        'viewCount': viewCount,
        'audioTitle': audioTitle,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
