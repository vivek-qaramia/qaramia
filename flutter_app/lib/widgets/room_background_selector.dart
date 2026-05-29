import 'package:flutter/material.dart';

import '../theme/brand.dart';

class RoomBackgroundOption {
  final String id;
  final String name;
  final List<Color> gradient;
  // Agora backgroundColor RGB int (no alpha). Used as the fallback when the
  // bundled JPG fails to load, so the host still gets a noticeable change.
  final int agoraColor;
  // Bundled asset path — the real photographic background composited behind
  // the host via Agora's virtual-background segmentation. Files live in
  // flutter_app/assets/rooms/ and are listed in pubspec.yaml.
  final String assetPath;

  const RoomBackgroundOption({
    required this.id,
    required this.name,
    required this.gradient,
    required this.agoraColor,
    required this.assetPath,
  });
}

const kRoomBackgrounds = [
  RoomBackgroundOption(
    id: 'modern_studio',
    name: 'Modern Studio',
    gradient: [Color(0xFF3a3028), Color(0xFF111010)],
    agoraColor: 0x3a3028,
    assetPath: 'assets/rooms/modern_studio.jpg',
  ),
  RoomBackgroundOption(
    id: 'living_room',
    name: 'Living Room',
    gradient: [Color(0xFFe8d5b7), Color(0xFF5c3d20)],
    agoraColor: 0xe8d5b7,
    assetPath: 'assets/rooms/living_room.jpg',
  ),
  RoomBackgroundOption(
    id: 'gaming_den',
    name: 'Gaming Den',
    gradient: [Color(0xFF080810), Color(0xFF1a0033)],
    agoraColor: 0x080810,
    assetPath: 'assets/rooms/gaming_den.jpg',
  ),
  RoomBackgroundOption(
    id: 'broadcast_studio',
    name: 'Broadcast Studio',
    gradient: [Color(0xFF0a1628), Color(0xFF050b12)],
    agoraColor: 0x0a1628,
    assetPath: 'assets/rooms/broadcast_studio.jpg',
  ),
];

class RoomBackgroundSelector extends StatelessWidget {
  final String selectedId;
  final ValueChanged<RoomBackgroundOption> onSelect;

  const RoomBackgroundSelector({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Room Background',
          style: TextStyle(color: QBrand.fgMute, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kRoomBackgrounds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final bg = kRoomBackgrounds[i];
              final selected = bg.id == selectedId;
              return GestureDetector(
                onTap: () => onSelect(bg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 110,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    // Gradient is rendered as a fallback under the image so
                    // the tile still has visible colour while the JPG is
                    // loading (or if the file is missing in dev).
                    gradient: LinearGradient(
                      colors: bg.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    image: DecorationImage(
                      image: AssetImage(bg.assetPath),
                      fit: BoxFit.cover,
                      onError: (_, _) {/* fallback to gradient */},
                    ),
                    border: Border.all(
                      color: selected ? const Color(0xFF3830CC) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 6,
                        left: 6,
                        right: 6,
                        child: Text(
                          bg.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3830CC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
