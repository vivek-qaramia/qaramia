import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counters accumulated during a single live-broadcast session.
///
/// Derived dollar estimate: $25 CPM floor on ad matches (impressions × $0.025)
/// + $0.10 per host-side affiliate click. The estimate is what's surfaced to
/// the creator in the earnings widget and written to
/// users/{uid}.estimatedEarningsUsd at stream end.
class SessionStats {
  final int products;
  final int impressions;
  final int affiliateClicks;
  const SessionStats({
    this.products = 0,
    this.impressions = 0,
    this.affiliateClicks = 0,
  });

  double get estimatedEarningsUsd =>
      impressions * 0.025 + affiliateClicks * 0.10;
}

class SessionStatsNotifier extends StateNotifier<SessionStats> {
  SessionStatsNotifier() : super(const SessionStats());

  /// Called whenever publishProducts() fires (visual scan OR spoken match).
  /// `matched` is true if an ad slot was filled — impressions only count
  /// matches, not bare product detections.
  void onProductsPublished({required bool matched}) {
    state = SessionStats(
      products: state.products + 1,
      impressions: state.impressions + (matched ? 1 : 0),
      affiliateClicks: state.affiliateClicks,
    );
  }

  void onAffiliateClick() {
    state = SessionStats(
      products: state.products,
      impressions: state.impressions,
      affiliateClicks: state.affiliateClicks + 1,
    );
  }

  void reset() => state = const SessionStats();
}

/// Family per streamId so multiple in-progress streams (rare but possible in
/// dev tools) don't bleed counters into one another.
final sessionStatsProvider = StateNotifierProvider.family<
    SessionStatsNotifier, SessionStats, String>(
  (_, __) => SessionStatsNotifier(),
);
