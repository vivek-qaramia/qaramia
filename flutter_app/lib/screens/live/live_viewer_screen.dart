import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/live_stream.dart';
import '../../models/chat_message.dart';
import '../../models/gift.dart';
import '../../models/sponsorship.dart';
import '../../providers/providers.dart';
import '../../providers/sponsorship_providers.dart';
import '../../services/cohost_service.dart';
import '../../services/stream_service.dart' show InsufficientCoinsException;
import '../../theme/brand.dart';
import '../../widgets/caption_overlay.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/gift_panel.dart';
import '../../widgets/product_drawer.dart';
import '../../widgets/room_background_selector.dart';
import '../wallet/wallet_screen.dart';

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
    setState(() { _pendingInvite = null; });
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

  Future<void> _sendGift(GiftType gift, {Sponsorship? sponsorship}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    try {
      // If this is a sponsored gift, the viewer's coin cost may be discounted
      // or zero. Construct a runtime GiftType with the adjusted price so the
      // transaction debits the right amount.
      final effectiveGift = sponsorship == null
          ? gift
          : GiftType(
              id: gift.id,
              name: gift.name,
              emoji: gift.emoji,
              coinCost: sponsorship.viewerCoinCost(gift.coinCost),
              diamondYield: gift.diamondYield,
              tier: gift.tier,
              animationAsset: gift.animationAsset,
            );

      await ref.read(streamServiceProvider).sendGift(
        streamId: widget.stream.id,
        senderUid: user.uid,
        senderUsername: currentUser?.username ?? 'viewer',
        recipientUid: widget.stream.hostUid,
        giftType: effectiveGift,
      );

      // Bill the sponsoring brand for this send (best-effort, doesn't block UX)
      if (sponsorship != null) {
        ref.read(sponsorshipServiceProvider).recordSend(
          sponsorship: sponsorship,
          streamId: widget.stream.id,
          streamerUid: widget.stream.hostUid,
          senderUid: user.uid,
        ).catchError((_) {});
      }

      // Fanout to danmaku chat
      await ref.read(danmakuServiceProvider).sendMessage(
        streamId: widget.stream.id,
        authorUid: user.uid,
        authorUsername: currentUser?.username ?? 'viewer',
        text: 'sent ${gift.emoji} ${gift.name}',
        type: 'gift',
      );
    } on InsufficientCoinsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Need ${e.shortfall} more coins'),
            action: SnackBarAction(
              label: 'TOP UP',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _showGiftPanel = false);
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

          // Gift animation — floating emoji per new gift
          GiftAnimationOverlay(streamId: widget.stream.id),

          // Closed-caption overlay (read-only — host controls broadcast)
          CaptionOverlay(streamId: widget.stream.id),

          // CC toggle (viewer preference; persisted to SharedPreferences)
          Positioned(
            top: 0, right: 12,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.all(8),
              child: const CaptionToggleButton(),
            )),
          ),

          // Live-commerce surface — floating bag + slide-up drawer
          ProductDrawer(
            products: liveStream.featuredProducts,
            featuredAd: liveStream.featuredAd,
          ),

          // Co-host invite banner
          if (_pendingInvite != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3830CC),
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
                        child: const Text('Join', style: TextStyle(color: Color(0xFF3830CC), fontWeight: FontWeight.bold)),
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

          // Top bar — template-aligned: avatar w/ Live tag + name + Follow + viewers + close
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _TopBar(
                  hostUid: widget.stream.hostUid,
                  hostUsername: widget.stream.hostUsername,
                  hostAvatarUrl: widget.stream.hostAvatarUrl,
                  viewerCount: liveStream.viewerCount,
                  onClose: () => Navigator.pop(context),
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
                _ChatList(messages: messages.take(6).toList(), hostUid: widget.stream.hostUid),

                // Bottom action row — template-aligned
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
                            hintText: 'What do you think...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.10),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendChat(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => setState(() => _showGiftPanel = !_showGiftPanel),
                        icon: const Text('🎁', style: TextStyle(fontSize: 22)),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.favorite, color: Colors.white, size: 22),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
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
              child: GiftPanel(
                stream: liveStream,
                onGiftSelected: (gift, {sponsorship}) => _sendGift(gift, sponsorship: sponsorship),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<ChatMessage> messages;
  final String hostUid;
  const _ChatList({required this.messages, required this.hostUid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messages.reversed
          .map((m) => _ChatBubble(message: m, isHost: m.authorUid == hostUid))
          .toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isHost;
  const _ChatBubble({required this.message, required this.isHost});

  @override
  Widget build(BuildContext context) {
    final isGift = message.type == 'gift';
    final isJoin = message.type == 'join';
    final textColor = isGift
        ? const Color(0xFFFFD700)
        : isJoin
            ? const Color(0xFFFFD166)
            : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: _avatarColor(message.authorUsername),
            child: Text(
              _initial(message.authorUsername),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHost) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: QBrand.seller,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Seller',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        message.authorUsername,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initial(String s) => s.isEmpty ? '?' : s.substring(0, 1).toUpperCase();

  static Color _avatarColor(String s) {
    const palette = [QBrand.primary, QBrand.love, QBrand.seller, QBrand.gold, QBrand.deep];
    return palette[s.hashCode.abs() % palette.length];
  }
}

/// Top bar: avatar + "Live" tag + name + +Follow pill + viewers + close.
class _TopBar extends ConsumerStatefulWidget {
  final String hostUid;
  final String hostUsername;
  final String? hostAvatarUrl;
  final int viewerCount;
  final VoidCallback onClose;
  const _TopBar({
    required this.hostUid,
    required this.hostUsername,
    required this.hostAvatarUrl,
    required this.viewerCount,
    required this.onClose,
  });

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  bool _toggling = false;

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    final me = ref.read(authStateProvider).valueOrNull?.uid;
    if (me == null || me == widget.hostUid || _toggling) return;
    setState(() => _toggling = true);
    final svc = ref.read(userServiceProvider);
    try {
      if (currentlyFollowing) {
        await svc.unfollowUser(me, widget.hostUid);
      } else {
        await svc.followUser(me, widget.hostUid);
      }
      ref.invalidate(isFollowingProvider);
    } catch (_) {}
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isSelf = myUid != null && myUid == widget.hostUid;
    final followingAsync = (myUid != null && !isSelf)
        ? ref.watch(isFollowingProvider((currentUid: myUid, targetUid: widget.hostUid)))
        : null;
    final isFollowing = followingAsync?.valueOrNull ?? false;

    // Pill content: dark glass bg with avatar + name + Follow inside, plus
    // a tiny red "Live" tag overlapping the avatar's bottom.
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.hostAvatarUrl != null
                        ? NetworkImage(widget.hostAvatarUrl!)
                        : null,
                  ),
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: QBrand.love,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Live',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.hostUsername,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 11),
                      const SizedBox(width: 3),
                      Text('${widget.viewerCount} Viewers',
                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              if (!isSelf) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _toggling ? null : () => _toggleFollow(isFollowing),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFollowing ? Colors.white.withValues(alpha: 0.15) : QBrand.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : '+ Follow',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

