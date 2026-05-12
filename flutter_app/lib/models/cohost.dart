import 'package:cloud_firestore/cloud_firestore.dart';

enum CoHostStatus { invited, accepted, active, declined }

class CoHost {
  final String uid;
  final String username;
  final String? avatarUrl;
  final CoHostStatus status;
  final DateTime invitedAt;

  const CoHost({
    required this.uid,
    required this.username,
    this.avatarUrl,
    required this.status,
    required this.invitedAt,
  });

  factory CoHost.fromJson(Map<String, dynamic> json) => CoHost(
        uid: json['uid'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        status: CoHostStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => CoHostStatus.invited,
        ),
        invitedAt: (json['invitedAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'avatarUrl': avatarUrl,
        'status': status.name,
        'invitedAt': Timestamp.fromDate(invitedAt),
      };
}
