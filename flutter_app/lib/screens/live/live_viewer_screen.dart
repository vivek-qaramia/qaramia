import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/live_stream.dart';
import '../../models/chat_message.dart';
import '../../models/gift.dart';
import '../../models/sponsorship.dart';
import '../../models/streamer_stats.dart';
import '../../providers/providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/sponsorship_providers.dart';
import '../../services/cohost_service.dart';
import '../../services/stream_service.dart' show InsufficientCoinsException;
import '../../theme/brand.dart';
import '../../widgets/caption_overlay.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/gift_panel.dart';
import '../../widgets/gift_goal_bar.dart';
import '../../widgets/product_drawer.dart';
import '../../widgets/room_background_selector.dart';
import '../../widgets/system_panel.dart';
import '../../widgets/top_gifters_board.dart';
import '../cart/my_bag_screen.dart';
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
  // Agora-session uids of every remote broadcaster currently publishing on
  // this channel. Index 0 is treated as the primary (host); index 1 is the
  // co-host. The viewer renders single-tile when there's 1, split 50/50
  // when there are 2.
  final List<int> _remoteUids = [];
  bool _showGiftPanel = false;
  bool _systemOpen = false; // host "System" status panel slide-up
  bool _shopMode = true; // Shop/Reels top-right toggle (Shop = default)
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
      onUserJoined: (conn, uid, elapsed) {
        if (!mounted) return;
        setState(() {
          if (!_remoteUids.contains(uid) && _remoteUids.length < 2) {
            _remoteUids.add(uid);
          }
        });
      },
      onUserOffline: (conn, uid, reason) {
        if (!mounted) return;
        setState(() => _remoteUids.remove(uid));
      },
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
        senderAvatarUrl: currentUser?.avatarUrl,
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

    // Host's live "System" stats (level + CHA/INF/FOR/HYPE), shown as a Lv badge
    // in the header that opens the slide-up status panel. Null until loaded.
    final hostUser = ref.watch(userByUidProvider(liveStream.hostUid)).valueOrNull;
    final hostStats = hostUser != null
        ? StreamerStats.from(user: hostUser, stream: liveStream)
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote video — split 50/50 side-by-side when both host and
          // co-host are publishing, single-tile otherwise. Each
          // AgoraVideoView is for a specific Agora uid; viewers in audience
          // role get auto-subscribed to all broadcasters on the channel.
          if (_remoteUids.length == 2)
            Row(
              children: [
                Expanded(
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUids[0]),
                      connection: RtcConnection(channelId: widget.stream.agoraChannel),
                    ),
                  ),
                ),
                Container(width: 2, color: Colors.white24),
                Expanded(
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUids[1]),
                      connection: RtcConnection(channelId: widget.stream.agoraChannel),
                    ),
                  ),
                ),
              ],
            )
          else if (_remoteUids.length == 1)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUids[0]),
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
            products: _shopMode ? liveStream.featuredProducts : const [],
            featuredAd: _shopMode ? liveStream.featuredAd : null,
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

          // Top bar — template-aligned: avatar w/ Live tag + name + Follow,
          // Shop/Reels segmented toggle on the right, close X on the far right.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TopBar(
                            hostUid: widget.stream.hostUid,
                            hostUsername: widget.stream.hostUsername,
                            hostAvatarUrl: widget.stream.hostAvatarUrl,
                            viewerCount: liveStream.viewerCount,
                          ),
                        ),
                        if (hostStats != null) ...[
                          const SizedBox(width: 8),
                          SystemLevelBadge(
                            level: hostStats.level,
                            onTap: () => setState(() => _systemOpen = !_systemOpen),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _ShopReelsToggle(
                          selected: _shopMode,
                          onChanged: (v) => setState(() => _shopMode = v),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                    ),
                    // Gift goal progress + top-gifter leaderboard under the bar.
                    if (liveStream.hasGiftGoal) ...[
                      const SizedBox(height: 8),
                      GiftGoalBar(stream: liveStream),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TopGiftersBoard(streamId: widget.stream.id),
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
                      _BagButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyBagScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
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

          // Host "System" status panel — slides up when the Lv badge is tapped.
          if (hostStats != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              left: 12,
              right: 12,
              bottom: _systemOpen ? 24 : -460,
              child: SafeArea(
                top: false,
                child: SystemStatusCard(
                  stats: hostStats,
                  name: hostUser!.displayName,
                  onClose: () => setState(() => _systemOpen = false),
                ),
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

/// Top bar pill: avatar + "Live" tag + name + viewers + +Follow.
/// Wrapped in Expanded by the caller so it pushes the Shop/Reels toggle and
/// close-X to the right edge.
class _TopBar extends ConsumerStatefulWidget {
  final String hostUid;
  final String hostUsername;
  final String? hostAvatarUrl;
  final int viewerCount;
  const _TopBar({
    required this.hostUid,
    required this.hostUsername,
    required this.hostAvatarUrl,
    required this.viewerCount,
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
        Flexible(
          child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hostUsername,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        )),
      ],
    );
  }
}

/// Inline 🛍 button in the bottom action row. Shows an indigo count badge
/// when the cart has items; tapping opens MyBagScreen.
class _BagButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _BagButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Text('🛍', style: TextStyle(fontSize: 24)),
            if (count > 0)
              Positioned(
                top: -4, right: -8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: QBrand.primary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segmented Shop / Reels pill that mirrors the template. Stores selection in
/// caller state so the live-viewer surface can swap content (currently a
/// visual affordance — Reels view is reserved for a future feed integration).
class _ShopReelsToggle extends StatelessWidget {
  final bool selected; // true = Shop, false = Reels
  final ValueChanged<bool> onChanged;

  const _ShopReelsToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(label: 'Shop', active: selected, onTap: () => onChanged(true)),
          _segment(label: 'Reels', active: !selected, onTap: () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? QBrand.fg : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

