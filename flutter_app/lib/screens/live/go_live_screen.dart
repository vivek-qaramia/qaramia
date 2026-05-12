import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/live_stream.dart';
import '../../models/cohost.dart';
import '../../providers/providers.dart';
import '../../services/cohost_service.dart';
import '../../widgets/broadcast_scan_button.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/product_drawer.dart';
import '../../widgets/room_background_selector.dart';

const _agoraAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: 'YOUR_AGORA_APP_ID');

class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _titleCtrl = TextEditingController();
  String _category = 'General';
  bool _isStreaming = false;
  bool _roomMode = false;
  String _selectedBgId = 'modern_studio';
  LiveStream? _activeStream;
  RtcEngine? _engine;
  final _cohostService = CoHostService();

  static const _categories = ['General', 'Gaming', 'Music', 'IRL', 'Sports', 'Cooking', 'Education'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    if (_isStreaming && _activeStream != null) _stopStream();
    super.dispose();
  }

  Future<void> _startStream() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a stream title')));
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (user == null || currentUser == null) return;

    final stream = await ref.read(streamServiceProvider).startStream(
      hostUid: user.uid,
      hostUsername: currentUser.username,
      hostAvatarUrl: currentUser.avatarUrl,
      title: title,
      category: _category,
    );

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: _agoraAppId));
    await _engine!.enableVideo();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Apply virtual background if room mode is on
    if (_roomMode) {
      await _applyVirtualBackground(_selectedBgId);
    }

    await _engine!.startPreview();
    await _engine!.joinChannel(
      token: '',
      channelId: stream.agoraChannel,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );

    setState(() {
      _activeStream = stream;
      _isStreaming = true;
    });
  }

  Future<void> _applyVirtualBackground(String bgId) async {
    if (_engine == null) return;
    final bg = kRoomBackgrounds.firstWhere((b) => b.id == bgId,
        orElse: () => kRoomBackgrounds.first);
    await _engine!.enableVirtualBackground(
      enabled: true,
      backgroundSource: VirtualBackgroundSource(
        backgroundSourceType: BackgroundSourceType.backgroundColor,
        color: bg.agoraColor,
      ),
      segproperty: const SegmentationProperty(
        modelType: SegModelType.segModelAi,
        greenCapacity: 0.5,
      ),
    );
  }

  Future<void> _disableVirtualBackground() async {
    await _engine?.enableVirtualBackground(
      enabled: false,
      backgroundSource: const VirtualBackgroundSource(),
      segproperty: const SegmentationProperty(),
    );
  }

  Future<void> _stopStream() async {
    if (_activeStream == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      await ref.read(streamServiceProvider).endStream(_activeStream!.id, user.uid);
    }
    await _engine?.leaveChannel();
    await _engine?.release();
    setState(() { _isStreaming = false; _activeStream = null; });
    if (mounted) Navigator.pop(context);
  }

  void _inviteCoHost() {
    if (_activeStream == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CoHostInviteSheet(
        streamId: _activeStream!.id,
        hostUsername: ref.read(currentUserProvider).valueOrNull?.username ?? '',
        cohostService: _cohostService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isStreaming && _activeStream != null) {
      return _BroadcastView(
        stream: _activeStream!,
        engine: _engine!,
        roomMode: _roomMode,
        cohostService: _cohostService,
        onInvite: _inviteCoHost,
        onEnd: _stopStream,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Go Live')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stream Title', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's your stream about?",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.map((cat) {
                final sel = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFFF7043) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat, style: TextStyle(color: sel ? Colors.white : Colors.white70)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Room Mode toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _roomMode ? const Color(0xFF1A0A2E) : Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _roomMode ? const Color(0xFFFF7043) : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏠 Room Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Co-hosts appear in the same virtual space',
                                style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _roomMode,
                        onChanged: (v) => setState(() => _roomMode = v),
                        activeColor: const Color(0xFFFF7043),
                      ),
                    ],
                  ),
                  if (_roomMode) ...[
                    const SizedBox(height: 16),
                    RoomBackgroundSelector(
                      selectedId: _selectedBgId,
                      onSelect: (bg) => setState(() => _selectedBgId = bg.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startStream,
                icon: const Icon(Icons.videocam),
                label: const Text('Start Streaming', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Broadcast view ───────────────────────────────────────────────────────────
class _BroadcastView extends ConsumerWidget {
  final LiveStream stream;
  final RtcEngine engine;
  final bool roomMode;
  final CoHostService cohostService;
  final VoidCallback onInvite;
  final VoidCallback onEnd;

  const _BroadcastView({
    required this.stream,
    required this.engine,
    required this.roomMode,
    required this.cohostService,
    required this.onInvite,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(danmakuMessagesProvider(stream.id));
    final streamAsync = ref.watch(singleStreamProvider(stream.id));
    final liveStream = streamAsync.valueOrNull ?? stream;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoView(
            controller: VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0)),
          ),
          DanmakuOverlay(messages: messages),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Row(children: [
                      const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('${liveStream.viewerCount}', style: const TextStyle(color: Colors.white)),
                    ]),
                    if (roomMode) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                        child: const Text('🏠 ROOM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    // Invite co-host button
                    GestureDetector(
                      onTap: onInvite,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.person_add, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Invite', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: const Text('End', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12, right: 60, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages.take(5).toList().reversed.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13), children: [
                  TextSpan(
                    text: '${m.authorUsername} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: m.type == 'gift' ? const Color(0xFFFFD700) : const Color(0xFFFFD166),
                    ),
                  ),
                  TextSpan(text: m.text, style: const TextStyle(color: Colors.white)),
                ])),
              )).toList(),
            ),
          ),
          // Host-side scan button (bottom right)
          Positioned(
            right: 16, bottom: 24,
            child: BroadcastScanButton(engine: engine, streamId: stream.id),
          ),
          // ProductDrawer — host sees the same surface viewers see, with a
          // dismiss-from-anywhere callback that clears the published products.
          ProductDrawer(
            products: liveStream.featuredProducts,
            featuredAd: liveStream.featuredAd,
            onClose: () =>
                ref.read(streamServiceProvider).dismissProducts(stream.id),
          ),
        ],
      ),
    );
  }
}

// ─── Co-host invite bottom sheet ──────────────────────────────────────────────
class _CoHostInviteSheet extends ConsumerStatefulWidget {
  final String streamId;
  final String hostUsername;
  final CoHostService cohostService;

  const _CoHostInviteSheet({
    required this.streamId,
    required this.hostUsername,
    required this.cohostService,
  });

  @override
  ConsumerState<_CoHostInviteSheet> createState() => _CoHostInviteSheetState();
}

class _CoHostInviteSheetState extends ConsumerState<_CoHostInviteSheet> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final users = await ref.read(userServiceProvider).searchUsers(q);
    setState(() { _results = users; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invite Co-Host', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: _searching
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search, color: Colors.white38),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          ..._results.map((user) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[800],
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
            ),
            title: Text('@${user.username}', style: const TextStyle(color: Colors.white)),
            subtitle: Text(user.displayName, style: const TextStyle(color: Colors.white54)),
            trailing: ElevatedButton(
              onPressed: () async {
                await widget.cohostService.inviteCoHost(
                  streamId: widget.streamId,
                  hostUsername: widget.hostUsername,
                  targetUid: user.uid,
                  targetUsername: user.username,
                  targetAvatarUrl: user.avatarUrl,
                );
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7043)),
              child: const Text('Invite'),
            ),
          )).toList(),
        ],
      ),
    );
  }
}
