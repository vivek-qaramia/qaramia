/// Preset room backgrounds — real photographic scenes that the Agora
/// VirtualBackgroundExtension composites behind the host. Mirrors
/// flutter_app/lib/widgets/room_background_selector.dart's kRoomBackgrounds.
/// JPG files live in web_app/public/rooms/ — drop replacements there to
/// re-skin without touching code.
export interface RoomBackground {
  id: string;
  name: string;
  /// Public URL of the room photo (served from /public).
  imageUrl: string;
  /// Fallback solid colour used while the image is still loading or if the
  /// fetch fails. Picker also tints the thumbnail with this if the image
  /// 404s in dev.
  color: string;
}

export const ROOM_BACKGROUNDS: RoomBackground[] = [
  {
    id: 'modern_studio',
    name: 'Modern Studio',
    imageUrl: '/rooms/modern_studio.jpg',
    color: '#3a3028',
  },
  {
    id: 'living_room',
    name: 'Living Room',
    imageUrl: '/rooms/living_room.jpg',
    color: '#e8d5b7',
  },
  {
    id: 'gaming_den',
    name: 'Gaming Den',
    imageUrl: '/rooms/gaming_den.jpg',
    color: '#080810',
  },
  {
    id: 'broadcast_studio',
    name: 'Broadcast Studio',
    imageUrl: '/rooms/broadcast_studio.jpg',
    color: '#0a1628',
  },
];
