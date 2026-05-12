import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_info.dart';
import 'ad.dart';

enum StreamStatus { live, ended, scheduled }

class LiveStream {
  final String id;
  final String hostUid;
  final String hostUsername;
  final String? hostAvatarUrl;
  final String title;
  final String? thumbnailUrl;
  final String category;
  final int viewerCount;
  final int peakViewerCount;
  final int totalGifts;
  final StreamStatus status;
  final String agoraChannel;
  final bool roomMode;
  final DateTime startedAt;
  final DateTime? endedAt;
  // ── Live commerce surface (multimodal product detection) ──────────────────
  final List<ProductInfo> featuredProducts;
  final Ad? featuredAd;

  const LiveStream({
    required this.id,
    required this.hostUid,
    required this.hostUsername,
    this.hostAvatarUrl,
    required this.title,
    this.thumbnailUrl,
    required this.category,
    this.viewerCount = 0,
    this.peakViewerCount = 0,
    this.totalGifts = 0,
    this.status = StreamStatus.live,
    required this.agoraChannel,
    this.roomMode = false,
    required this.startedAt,
    this.endedAt,
    this.featuredProducts = const [],
    this.featuredAd,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) => LiveStream(
        id: json['id'] as String,
        hostUid: json['hostUid'] as String,
        hostUsername: json['hostUsername'] as String,
        hostAvatarUrl: json['hostAvatarUrl'] as String?,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        category: json['category'] as String? ?? 'General',
        viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
        peakViewerCount: (json['peakViewerCount'] as num?)?.toInt() ?? 0,
        totalGifts: (json['totalGifts'] as num?)?.toInt() ?? 0,
        status: StreamStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => StreamStatus.live,
        ),
        agoraChannel: json['agoraChannel'] as String,
        roomMode: json['roomMode'] as bool? ?? false,
        startedAt: (json['startedAt'] as Timestamp).toDate(),
        endedAt: json['endedAt'] != null
            ? (json['endedAt'] as Timestamp).toDate()
            : null,
        featuredProducts: (json['featuredProducts'] as List?)
                ?.map((p) => ProductInfo.fromJson(p as Map<String, dynamic>))
                .toList() ??
            const [],
        featuredAd: json['featuredAd'] is Map<String, dynamic>
            ? Ad.fromJson({
                ...json['featuredAd'] as Map<String, dynamic>,
                'id': (json['featuredAd'] as Map<String, dynamic>)['id'] ?? '',
              })
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostUid': hostUid,
        'hostUsername': hostUsername,
        'hostAvatarUrl': hostAvatarUrl,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'viewerCount': viewerCount,
        'peakViewerCount': peakViewerCount,
        'totalGifts': totalGifts,
        'status': status.name,
        'agoraChannel': agoraChannel,
        'roomMode': roomMode,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'featuredProducts': featuredProducts.map((p) => p.toJson()).toList(),
        if (featuredAd != null) 'featuredAd': featuredAd!.toJson(),
      };

  bool get isLive => status == StreamStatus.live;
}
