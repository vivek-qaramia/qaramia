import 'package:flutter/material.dart';
import '../models/gift.dart';

class GiftPanel extends StatelessWidget {
  final void Function(GiftType) onGiftSelected;
  const GiftPanel({super.key, required this.onGiftSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Color(0xEE1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Send a Gift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: GiftType.catalog.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final gift = GiftType.catalog[i];
                return GestureDetector(
                  onTap: () => onGiftSelected(gift),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Text(gift.emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(gift.name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 10)),
                          Text(' ${gift.coinCost}',
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
