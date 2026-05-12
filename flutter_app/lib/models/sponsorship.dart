import 'package:cloud_firestore/cloud_firestore.dart';

/// How a brand pays for a sponsored gift.
///
///   - premium       — brand pays a flat setup fee + per-send fee. Viewer
///                     pays the standard coin price; creator earns standard
///                     diamond yield. Brand gets visibility.
///   - free          — brand pays a monthly retainer; viewer pays 0 coins;
///                     creator receives a fixed cash amount from the brand.
///                     Used for activation campaigns tied to a streamer.
///   - discounted    — brand subsidises a portion of the coin price; viewer
///                     pays a reduced amount; creator earns standard yield.
enum SponsorshipPricingModel { premium, free, discounted }

enum SponsorshipStatus { active, paused, ended }

class Sponsorship {
  final String id;
  final String brandId;
  final String brandName;
  final String? brandLogoUrl;
  final String giftTypeId;
  final SponsorshipPricingModel pricingModel;
  /// USD the brand pays per-send (premium / free models).
  final double? perSendRateUsd;
  /// USD the brand pays per month (free model).
  final double? monthlyRetainerUsd;
  /// Percent off coin price for viewers (discounted model, 0–1).
  final double? viewerDiscount;
  /// USD-per-send paid directly to the creator in the "free" model.
  final double? creatorPayoutUsd;
  /// Streamer UIDs this sponsorship is restricted to. Empty list = platform-wide.
  final List<String> allowedStreamerUids;
  /// Product keywords/categories that gate when this gift becomes selectable
  /// (e.g. only show "Coca-Cola Bottle" gift if a Coca-Cola product is detected).
  final List<String> gateOnKeywords;
  final List<String> gateOnCategories;
  final SponsorshipStatus status;
  final int totalSendCount;
  final double totalBrandSpendUsd;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  const Sponsorship({
    required this.id,
    required this.brandId,
    required this.brandName,
    this.brandLogoUrl,
    required this.giftTypeId,
    required this.pricingModel,
    this.perSendRateUsd,
    this.monthlyRetainerUsd,
    this.viewerDiscount,
    this.creatorPayoutUsd,
    this.allowedStreamerUids = const [],
    this.gateOnKeywords = const [],
    this.gateOnCategories = const [],
    this.status = SponsorshipStatus.active,
    this.totalSendCount = 0,
    this.totalBrandSpendUsd = 0,
    required this.startsAt,
    this.endsAt,
    required this.createdAt,
  });

  factory Sponsorship.fromJson(Map<String, dynamic> json) => Sponsorship(
        id: json['id'] as String,
        brandId: json['brandId'] as String,
        brandName: json['brandName'] as String,
        brandLogoUrl: json['brandLogoUrl'] as String?,
        giftTypeId: json['giftTypeId'] as String,
        pricingModel: SponsorshipPricingModel.values.firstWhere(
          (m) => m.name == json['pricingModel'],
          orElse: () => SponsorshipPricingModel.premium,
        ),
        perSendRateUsd: (json['perSendRateUsd'] as num?)?.toDouble(),
        monthlyRetainerUsd: (json['monthlyRetainerUsd'] as num?)?.toDouble(),
        viewerDiscount: (json['viewerDiscount'] as num?)?.toDouble(),
        creatorPayoutUsd: (json['creatorPayoutUsd'] as num?)?.toDouble(),
        allowedStreamerUids:
            (json['allowedStreamerUids'] as List?)?.cast<String>() ?? const [],
        gateOnKeywords:
            (json['gateOnKeywords'] as List?)?.cast<String>() ?? const [],
        gateOnCategories:
            (json['gateOnCategories'] as List?)?.cast<String>() ?? const [],
        status: SponsorshipStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SponsorshipStatus.active,
        ),
        totalSendCount: (json['totalSendCount'] as num?)?.toInt() ?? 0,
        totalBrandSpendUsd: (json['totalBrandSpendUsd'] as num?)?.toDouble() ?? 0,
        startsAt: (json['startsAt'] as Timestamp).toDate(),
        endsAt: json['endsAt'] != null ? (json['endsAt'] as Timestamp).toDate() : null,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'brandId': brandId,
        'brandName': brandName,
        if (brandLogoUrl != null) 'brandLogoUrl': brandLogoUrl,
        'giftTypeId': giftTypeId,
        'pricingModel': pricingModel.name,
        if (perSendRateUsd != null) 'perSendRateUsd': perSendRateUsd,
        if (monthlyRetainerUsd != null) 'monthlyRetainerUsd': monthlyRetainerUsd,
        if (viewerDiscount != null) 'viewerDiscount': viewerDiscount,
        if (creatorPayoutUsd != null) 'creatorPayoutUsd': creatorPayoutUsd,
        if (allowedStreamerUids.isNotEmpty)
          'allowedStreamerUids': allowedStreamerUids,
        if (gateOnKeywords.isNotEmpty) 'gateOnKeywords': gateOnKeywords,
        if (gateOnCategories.isNotEmpty) 'gateOnCategories': gateOnCategories,
        'status': status.name,
        'totalSendCount': totalSendCount,
        'totalBrandSpendUsd': totalBrandSpendUsd,
        'startsAt': Timestamp.fromDate(startsAt),
        if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// True if this sponsorship currently applies to the given streamer + the
  /// products visible on their stream (if any gating keywords are set).
  bool appliesTo({
    required String streamerUid,
    List<String> streamProductKeywords = const [],
    List<String> streamProductCategories = const [],
  }) {
    if (status != SponsorshipStatus.active) return false;
    if (allowedStreamerUids.isNotEmpty &&
        !allowedStreamerUids.contains(streamerUid)) {
      return false;
    }
    if (gateOnKeywords.isNotEmpty &&
        !gateOnKeywords.any(streamProductKeywords.contains)) {
      return false;
    }
    if (gateOnCategories.isNotEmpty &&
        !gateOnCategories.any(streamProductCategories.contains)) {
      return false;
    }
    return true;
  }

  /// What the viewer pays in coins for this gift, applying any discount.
  /// Falls back to the un-discounted price if pricing is premium.
  int viewerCoinCost(int standardCoinCost) {
    if (pricingModel == SponsorshipPricingModel.free) return 0;
    if (pricingModel == SponsorshipPricingModel.discounted &&
        viewerDiscount != null) {
      return (standardCoinCost * (1 - viewerDiscount!)).round();
    }
    return standardCoinCost;
  }
}
