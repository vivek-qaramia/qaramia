import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/live_stream.dart';
import '../../models/chat_message.dart';
import '../../models/gift.dart';
import '../../providers/providers.dart';
import '../../services/cohost_service.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/gift_panel.dart';
import '../../widgets/room_background_selector.dart';

const _agoraAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: 'YOUR_AGORA_APP_ID');

class LiveViewerScreen extends ConsumerStatefulWidget {
  final LiveStream stream;
  const LiveViewerScreen({super.key, required this.stream});

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _showGiftPanel = false;
  bool _isCoHost = false;
  Map<String, dynamic>? _pendingInvite;
  final _chatCtrl = TextEditingController();
  final _cohostService = CoHostService();

  @override
  void initState() {
    super.initState();
    _initAgora();
    _trackJoin();
    _watchInvite();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: _agoraAppId));
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (conn, uid, elapsed) => setState(() => _remoteUid = uid),
      onUserOffline: (conn, uid, reason) => setState(() => _remoteUid = null),
    ));
    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.enableVideo();
    await _engine!.joinChannel(
      token: '',
      channelId: widget.stream.agoraChannel,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );
  }

  void _watchInvite() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    _cohostService.watchPendingInvite(uid).listen((invite) {
      if (!mounted) return;
      if (invite != null && invite['streamId'] == widget.stream.id) {
        setState(() => _pendingInvite = invite);
      } else {
        setState(() => _pendingInvite = null);
      }
    });
  }

  Future<void> _acceptInvite() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _engine == null) return;
    await _cohostService.acceptInvite(widget.stream.id, uid);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableVirtualBackground(
      enabled: true,
      backgroundSource: VirtualBackgroundSource(
        backgroundSourceType: BackgroundSourceType.backgroundColor,
        color: kRoomBackgrounds.first.agoraColor,
      ),
      segproperty: const SegmentationProperty(
        modelType: SegModelType.segModelAi,
        greenCapacity: 0.5,
      ),
    );
    await _engine!.startPreview();
    await _cohostService.setActive(widget.stream.id, uid);
    setState(() { _isCoHost = true; _pendingInvite = null; });
  }

  Future<void> _declineInvite() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _cohostService.declineInvite(widget.stream.id, uid);
    setState(() => _pendingInvite = null);
  }

  void _trackJoin() {
    ref.read(streamServiceProvider).updateViewerCount(widget.stream.id, 1);
    _sendSystemMessage('joined the stream');
  }

  void _sendSystemMessage(String text) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    ref.read(danmakuServiceProvider).sendMessage(
      streamId: widget.stream.id,
      authorUid: user.uid,
      authorUsername: currentUser?.username ?? 'viewer',
      text: text,
      type: 'join',
    );
  }

  void _sendChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    await ref.read(danmakuServiceProvider).sendMessage(
      streamId: widget.stream.id,
      authorUid: user.uid,
      authorUsername: currentUser?.username ?? 'viewer',
      text: text,
    );
  }

  Future<void> _sendGift(GiftType gift) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    await ref.read(streamServiceProvider).sendGift(
      streamId: widget.stream.id,
      senderUid: user.uid,
      senderUsername: currentUser?.username ?? 'viewer',
      giftType: gift,
    );
    // Also send to danmaku
    await ref.read(danmakuServiceProvider).sendMessage(
      streamId: widget.stream.id,
      authorUid: user.uid,
      authorUsername: currentUser?.username ?? 'viewer',
      text: 'sent ${gift.emoji} ${gift.name}',
      type: 'gift',
    );
    setState(() => _showGiftPanel = false);
  }

  @override
  void dispose() {
    ref.read(streamServiceProvider).updateViewerCount(widget.stream.id, -1);
    _engine?.leaveChannel();
    _engine?.release();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(danmakuMessagesProvider(widget.stream.id));
    final streamAsync = ref.watch(singleStreamProvider(widget.stream.id));
    final liveStream = streamAsync.valueOrNull ?? widget.stream;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote video
          if (_remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.stream.agoraChannel),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: widget.stream.hostAvatarUrl != null
                        ? NetworkImage(widget.stream.hostAvatarUrl!)
                        : null,
                    backgroundColor: Colors.grey[800],
                  ),
                  const SizedBox(height: 16),
                  const Text('Waiting for stream...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),

          // Danmaku overlay (floating comments)
          DanmakuOverlay(messages: messages),

          // Co-host invite banner
          if (_pendingInvite != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7043),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '🎙 You\'re invited to co-host!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _acceptInvite,
                        style: TextButton.styleFrom(backgroundColor: Colors.white),
                        child: const Text('Join', style: TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _declineInvite,
                        child: const Text('Decline', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: widget.stream.hostAvatarUrl != null
                          ? NetworkImage(widget.stream.hostAvatarUrl!)
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${widget.stream.hostUsername}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(widget.stream.title,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('${liveStream.viewerCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Chat + bottom actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent messages list
                _ChatList(messages: messages.take(6).toList()),

                // Input row
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Say something...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white12,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendChat(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _showGiftPanel = !_showGiftPanel),
                        icon: const Text('🎁', style: TextStyle(fontSize: 24)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Gift panel
          if (_showGiftPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: GiftPanel(onGiftSelected: _sendGift),
            ),
        ],
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<ChatMessage> messages;
  const _ChatList({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messages.reversed.map((m) => _ChatBubble(message: m)).toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isGift = message.type == 'gift';
    final isJoin = message.type == 'join';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: isGift ? const Color(0xFFFFD700) : isJoin ? const Color(0xFFFFD166) : Colors.white,
          ),
          children: [
            TextSpan(
              text: '${message.authorUsername} ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: message.text),
          ],
        ),
      ),
    );
  }
}
