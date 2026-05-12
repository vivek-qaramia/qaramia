import 'package:cloud_firestore/cloud_firestore.dart';

class GiftType {
  final String id;
  final String name;
  final String emoji;
  final int coinCost;
  final String animationAsset;

  const GiftType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinCost,
    required this.animationAsset,
  });

  static const List<GiftType> catalog = [
    GiftType(id: 'rose', name: 'Rose', emoji: '🌹', coinCost: 1, animationAsset: 'rose'),
    GiftType(id: 'heart', name: 'Heart', emoji: '❤️', coinCost: 5, animationAsset: 'heart'),
    GiftType(id: 'star', name: 'Star', emoji: '⭐', coinCost: 10, animationAsset: 'star'),
    GiftType(id: 'rocket', name: 'Rocket', emoji: '🚀', coinCost: 50, animationAsset: 'rocket'),
    GiftType(id: 'crown', name: 'Crown', emoji: '👑', coinCost: 100, animationAsset: 'crown'),
    GiftType(id: 'diamond', name: 'Diamond', emoji: '💎', coinCost: 500, animationAsset: 'diamond'),
    GiftType(id: 'universe', name: 'Universe', emoji: '🌌', coinCost: 1000, animationAsset: 'universe'),
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
  final DateTime sentAt;

  const GiftEvent({
    required this.id,
    required this.streamId,
    required this.senderUid,
    required this.senderUsername,
    required this.giftTypeId,
    this.quantity = 1,
    required this.totalCoins,
    required this.sentAt,
  });

  factory GiftEvent.fromJson(Map<String, dynamic> json) => GiftEvent(
        id: json['id'] as String,
        streamId: json['streamId'] as String,
        senderUid: json['senderUid'] as String,
        senderUsername: json['senderUsername'] as String,
        giftTypeId: json['giftTypeId'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
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
        'sentAt': Timestamp.fromDate(sentAt),
      };

  GiftType? get giftType =>
      GiftType.catalog.where((g) => g.id == giftTypeId).firstOrNull;
}
