import 'package:cloud_firestore/cloud_firestore.dart';

/// Viewer-side coin balance.
class Wallet {
  final int coins;
  final int lifetimeCoinsPurchased;
  final DateTime? updatedAt;

  const Wallet({
    this.coins = 0,
    this.lifetimeCoinsPurchased = 0,
    this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        lifetimeCoinsPurchased: (json['lifetimeCoinsPurchased'] as num?)?.toInt() ?? 0,
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );
}

/// Creator-side diamond balance — redeemable for cash via Stripe Connect.
class CreatorBalance {
  final int diamonds;
  final int lifetimeDiamonds;
  final DateTime? updatedAt;

  const CreatorBalance({
    this.diamonds = 0,
    this.lifetimeDiamonds = 0,
    this.updatedAt,
  });

  factory CreatorBalance.fromJson(Map<String, dynamic> json) => CreatorBalance(
        diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
        lifetimeDiamonds: (json['lifetimeDiamonds'] as num?)?.toInt() ?? 0,
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );

  /// At the default Standard creator tier (1 Diamond = $0.01 USD).
  double get estimatedCashoutUsd => diamonds * 0.01;
}

/// A coin pack purchasable via IAP (App Store / Google Play) or Stripe (web).
class CoinPack {
  final String id;
  final String label;
  final double priceUsd;
  final int coins;
  final int bonusCoins;
  final String target;

  /// Platform-specific product IDs configured in App Store Connect / Play Console.
  final String? iosProductId;
  final String? androidProductId;

  const CoinPack({
    required this.id,
    required this.label,
    required this.priceUsd,
    required this.coins,
    required this.bonusCoins,
    required this.target,
    this.iosProductId,
    this.androidProductId,
  });

  int get totalCoins => coins + bonusCoins;

  static const List<CoinPack> catalog = [
    CoinPack(id: 'starter', label: 'Starter', priceUsd:  0.99, coins:   100, bonusCoins:    0, target: 'First-time buyer'),
    CoinPack(id: 'casual',  label: 'Casual',  priceUsd:  4.99, coins:   500, bonusCoins:   50, target: 'Regular viewer'),
    CoinPack(id: 'regular', label: 'Regular', priceUsd:  9.99, coins:  1000, bonusCoins:  200, target: 'Engaged supporter'),
    CoinPack(id: 'power',   label: 'Power',   priceUsd: 24.99, coins:  2500, bonusCoins:  800, target: 'Heavy spender'),
    CoinPack(id: 'whale',   label: 'Whale',   priceUsd: 99.99, coins: 10000, bonusCoins: 4000, target: 'Top supporter'),
  ];
}
