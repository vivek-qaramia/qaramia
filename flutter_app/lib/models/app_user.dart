import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int likeCount;
  final bool isLive;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeCount = 0,
    this.isLive = false,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
        followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        isLive: json['isLive'] as bool? ?? false,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'followerCount': followerCount,
        'followingCount': followingCount,
        'likeCount': likeCount,
        'isLive': isLive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? followerCount,
    int? followingCount,
    int? likeCount,
    bool? isLive,
  }) =>
      AppUser(
        uid: uid,
        username: username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount ?? this.followingCount,
        likeCount: likeCount ?? this.likeCount,
        isLive: isLive ?? this.isLive,
        createdAt: createdAt,
      );
}
