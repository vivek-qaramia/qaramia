import 'package:cloud_firestore/cloud_firestore.dart';

enum GiftTier { standard, premium, whale }

class GiftType {
  final String id;
  final String name;
  final String emoji;
  final int coinCost;
  final int diamondYield; // creator's diamond reward — 50% of coinCost by default
  final GiftTier tier;
  final String animationAsset;

  const GiftType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinCost,
    required this.diamondYield,
    required this.tier,
    required this.animationAsset,
  });

  static const List<GiftType> catalog = [
    // Standard tier
    GiftType(id: 'rose',      name: 'Rose',      emoji: '🌹', coinCost: 1,     diamondYield: 0,     tier: GiftTier.standard, animationAsset: 'rose'),
    GiftType(id: 'heart',     name: 'Heart',     emoji: '❤️', coinCost: 5,     diamondYield: 2,     tier: GiftTier.standard, animationAsset: 'heart'),
    GiftType(id: 'star',      name: 'Star',      emoji: '⭐', coinCost: 10,    diamondYield: 5,     tier: GiftTier.standard, animationAsset: 'star'),
    GiftType(id: 'lollipop',  name: 'Lollipop',  emoji: '🍭', coinCost: 25,    diamondYield: 12,    tier: GiftTier.standard, animationAsset: 'lollipop'),
    GiftType(id: 'rocket',    name: 'Rocket',    emoji: '🚀', coinCost: 50,    diamondYield: 25,    tier: GiftTier.standard, animationAsset: 'rocket'),
    // Premium tier
    GiftType(id: 'crown',     name: 'Crown',     emoji: '👑', coinCost: 100,   diamondYield: 50,    tier: GiftTier.premium,  animationAsset: 'crown'),
    GiftType(id: 'bouquet',   name: 'Bouquet',   emoji: '💐', coinCost: 500,   diamondYield: 250,   tier: GiftTier.premium,  animationAsset: 'bouquet'),
    GiftType(id: 'diamond',   name: 'Diamond',   emoji: '💎', coinCost: 500,   diamondYield: 250,   tier: GiftTier.premium,  animationAsset: 'diamond'),
    GiftType(id: 'universe',  name: 'Universe',  emoji: '🌌', coinCost: 1000,  diamondYield: 500,   tier: GiftTier.premium,  animationAsset: 'universe'),
    GiftType(id: 'sportscar', name: 'Sports Car',emoji: '🏎️', coinCost: 2000,  diamondYield: 1000,  tier: GiftTier.premium,  animationAsset: 'sportscar'),
    // Whale tier
    GiftType(id: 'yacht',     name: 'Yacht',     emoji: '🛥️', coinCost: 5000,  diamondYield: 2500,  tier: GiftTier.whale,    animationAsset: 'yacht'),
    GiftType(id: 'castle',    name: 'Castle',    emoji: '🏰', coinCost: 10000, diamondYield: 5000,  tier: GiftTier.whale,    animationAsset: 'castle'),
    GiftType(id: 'lion',      name: 'Lion',      emoji: '🦁', coinCost: 30000, diamondYield: 15000, tier: GiftTier.whale,    animationAsset: 'lion'),
  ];
}

class GiftEvent {
  final String id;
  final String streamId;
  final String senderUid;
  final String senderUsername;
  final String giftTypeId;
  final int quantity;
  final int totalCoins;
  final int totalDiamondYield;
  final DateTime sentAt;

  const GiftEvent({
    required this.id,
    required this.streamId,
    required this.senderUid,
    required this.senderUsername,
    required this.giftTypeId,
    this.quantity = 1,
    required this.totalCoins,
    this.totalDiamondYield = 0,
    required this.sentAt,
  });

  factory GiftEvent.fromJson(Map<String, dynamic> json) => GiftEvent(
        id: json['id'] as String,
        streamId: json['streamId'] as String,
        senderUid: json['senderUid'] as String,
        senderUsername: json['senderUsername'] as String,
        giftTypeId: json['giftTypeId'] as String? ?? json['giftId'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        totalCoins: (json['totalCoins'] as num?)?.toInt() ?? (json['coinCost'] as num?)?.toInt() ?? 0,
        totalDiamondYield: (json['totalDiamondYield'] as num?)?.toInt() ?? (json['diamondYield'] as num?)?.toInt() ?? 0,
        sentAt: (json['sentAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'senderUid': senderUid,
        'senderUsername': senderUsername,
        'giftTypeId': giftTypeId,
        'quantity': quantity,
        'totalCoins': totalCoins,
        'totalDiamondYield': totalDiamondYield,
        'sentAt': Timestamp.fromDate(sentAt),
      };

  GiftType? get giftType =>
      GiftType.catalog.where((g) => g.id == giftTypeId).firstOrNull;
}
