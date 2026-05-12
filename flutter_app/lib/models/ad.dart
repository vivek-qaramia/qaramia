import 'package:cloud_firestore/cloud_firestore.dart';

enum AdStatus { active, paused }

class Ad {
  final String id;
  final String advertiserId;
  final String advertiserName;
  final String headline;
  final String? imageUrl;
  final String ctaText;
  final String ctaUrl;
  final List<String> keywords;
  final List<String> categories;
  final AdStatus status;
  final int impressions;
  final int clicks;
  final DateTime createdAt;

  const Ad({
    required this.id,
    required this.advertiserId,
    required this.advertiserName,
    required this.headline,
    this.imageUrl,
    this.ctaText = 'Shop Now',
    required this.ctaUrl,
    this.keywords = const [],
    this.categories = const [],
    this.status = AdStatus.active,
    this.impressions = 0,
    this.clicks = 0,
    required this.createdAt,
  });

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
        id: json['id'] as String,
        advertiserId: json['advertiserId'] as String,
        advertiserName: json['advertiserName'] as String? ?? '',
        headline: json['headline'] as String,
        imageUrl: json['imageUrl'] as String?,
        ctaText: json['ctaText'] as String? ?? 'Shop Now',
        ctaUrl: json['ctaUrl'] as String,
        keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        status: AdStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AdStatus.active,
        ),
        impressions: (json['impressions'] as num?)?.toInt() ?? 0,
        clicks: (json['clicks'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'advertiserId': advertiserId,
        'advertiserName': advertiserName,
        'headline': headline,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'ctaText': ctaText,
        'ctaUrl': ctaUrl,
        'keywords': keywords,
        if (categories.isNotEmpty) 'categories': categories,
        'status': status.name,
        'impressions': impressions,
        'clicks': clicks,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  double get ctr => impressions > 0 ? clicks / impressions : 0;
}
