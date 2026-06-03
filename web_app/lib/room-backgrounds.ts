/// Preset room backgrounds — real photographic scenes that the Agora
/// VirtualBackgroundExtension composites behind the host. Mirrors
/// flutter_app/lib/widgets/room_background_selector.dart's kRoomBackgrounds.
/// JPG files live in web_app/public/rooms/ — drop replacements there to
/// re-skin without touching code.
///
/// IMPORTANT: when you replace a JPG with a new image under the SAME
/// filename, bump ASSET_VERSION below. Browsers cache /public files by URL,
/// so without a new query string everyone keeps seeing the old image until
/// their cache expires. Bumping the version changes the URL → fresh fetch.
const ASSET_VERSION = 5;
const v = (path: string) => `${path}?v=${ASSET_VERSION}`;

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
    imageUrl: v('/rooms/modern_studio.jpg'),
    color: '#3a3028',
  },
  {
    id: 'living_room',
    name: 'Living Room',
    imageUrl: v('/rooms/living_room.jpg'),
    color: '#e8d5b7',
  },
  {
    id: 'gaming_den',
    name: 'Gaming Den',
    imageUrl: v('/rooms/gaming_den.jpg'),
    color: '#080810',
  },
  {
    id: 'broadcast_studio',
    name: 'Broadcast Studio',
    imageUrl: v('/rooms/broadcast_studio.jpg'),
    color: '#0a1628',
  },
];
