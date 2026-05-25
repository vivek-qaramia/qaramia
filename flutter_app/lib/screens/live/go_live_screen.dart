import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import '../../models/live_stream.dart';
import '../../providers/providers.dart';
import '../../services/cohost_service.dart';
import '../../models/video_filter.dart';
import '../../theme/brand.dart';
import 'post_stream_editor_screen.dart';
import '../../widgets/broadcast_scan_button.dart';
import '../../widgets/captions_controller.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/filter_picker.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/product_drawer.dart';
import '../../widgets/room_background_selector.dart';
import '../../widgets/session_earnings_card.dart';
import '../../providers/session_stats_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _starting = false;
  bool _roomMode = false;
  String _selectedBgId = 'modern_studio';
  String _filterId = 'none';
  LiveStream? _activeStream;
  RtcEngine? _engine;
  bool _isRecording = false;
  String? _recordingPath;
  final _cohostService = CoHostService();

  static const _categories = ['General', 'Gaming', 'Music', 'IRL', 'Sports', 'Cooking', 'Education'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    if (_isStreaming && _activeStream != null) {
      _stopStream();
    } else if (_engine != null) {
      // Engine was created but stream never went live (e.g. failure mid-start);
      // release it so the next Go Live attempt starts clean.
      _engine?.release();
      _engine = null;
    }
    super.dispose();
  }

  Future<void> _startStream() async {
    if (_starting) return;
    FocusScope.of(context).unfocus(); // close keyboard so SnackBars are visible
    debugPrint('[GoLive] tap');

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showError('Enter a stream title');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      _showError('Not signed in');
      return;
    }
    if (currentUser == null) {
      _showError('User profile not loaded. Pull-to-refresh on Profile, then try again.');
      return;
    }
    if (_agoraAppId == 'YOUR_AGORA_APP_ID' || _agoraAppId.isEmpty) {
      _showError(
        'AGORA_APP_ID not set. In Android Studio: Run > Edit Configurations > '
        'Additional run args: --dart-define-from-file=dart_defines.json, then '
        'STOP the app and re-run (hot-reload will not pick this up).',
      );
      return;
    }

    setState(() => _starting = true);
    try {
      debugPrint('[GoLive] creating Firestore stream doc');
      final stream = await ref.read(streamServiceProvider).startStream(
        hostUid: user.uid,
        hostUsername: currentUser.username,
        hostAvatarUrl: currentUser.avatarUrl,
        title: title,
        category: _category,
      );
      debugPrint('[GoLive] stream doc created id=${stream.id}');

      debugPrint('[GoLive] initialising Agora engine (App ID ${_agoraAppId.length} chars)');
      // Defensive: if a previous attempt left an engine alive, fully tear it
      // down before creating a new one. createAgoraRtcEngine returns a shared
      // singleton, so re-initialising over a live one is what triggers -17.
      if (_engine != null) {
        try { await _engine!.leaveChannel(); } catch (_) {}
        try { await _engine!.release(sync: true); } catch (_) {}
        _engine = null;
      }
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: _agoraAppId));
      debugPrint('[GoLive] engine initialised');

      await _engine!.enableVideo();
      debugPrint('[GoLive] enableVideo done (camera permission prompt may have shown)');
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      if (_roomMode) {
        await _applyVirtualBackground(_selectedBgId);
      }

      await _engine!.startPreview();
      debugPrint('[GoLive] startPreview done');

      // Beauty options require the video pipeline to be running, so this must
      // happen AFTER startPreview. Failures are non-fatal — better to go live
      // without the filter than to abort the broadcast.
      await _applyFilterToEngine(VideoFilter.byId(_filterId));

      // Kick off local recording only after onJoinChannelSuccess — the channel
      // isn't truly joined when joinChannel's future resolves, and the
      // recorder rejects with -4 (NOT_SUPPORTED) if started before then.
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
            debugPrint('[GoLive] onJoinChannelSuccess uid=${conn.localUid} elapsed=${elapsed}ms');
            if (mounted && !_isRecording) _startRecording(stream);
          },
        ),
      );

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
      debugPrint('[GoLive] joinChannel returned — waiting for onJoinChannelSuccess');

      if (!mounted) return;
      setState(() {
        _activeStream = stream;
        _isStreaming = true;
        _starting = false;
      });
    } catch (e, stack) {
      debugPrint('[GoLive] FAILED: $e\n$stack');
      // Release the engine so a retry doesn't trip Agora -17 (JOIN_REJECTED)
      // — the native engine remembers the half-completed previous attempt.
      try {
        await _engine?.leaveChannel();
      } catch (_) {}
      try {
        await _engine?.release();
      } catch (_) {}
      _engine = null;
      if (mounted) setState(() => _starting = false);
      _showError('Go Live failed: $e');
    }
  }

  void _showError(String msg) {
    debugPrint('[GoLive] error: $msg');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade900,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  /// Start screen recording of the live stream so the host can edit + publish
  /// after ending. We use Android MediaProjection (via flutter_screen_recording)
  /// rather than Agora's MediaRecorder because the latter returns -4
  /// NOT_SUPPORTED on this SDK build. The plugin will trigger a one-time
  /// system permission dialog before capture starts.
  Future<void> _startRecording(LiveStream stream) async {
    try {
      // The plugin writes the file itself (Android Movies dir on Android);
      // we just give it a stable name based on the stream id.
      final filename = 'qaramia_${stream.id}';
      final started = await FlutterScreenRecording.startRecordScreen(filename);
      if (!started) {
        debugPrint('[GoLive] startRecordScreen returned false (user denied?)');
        return;
      }
      _isRecording = true;
      // Path is only known at stop time on Android — keep filename as a
      // placeholder so existing `_recordingPath != null` checks still work.
      _recordingPath = filename;
      debugPrint('[GoLive] screen recording started (filename=$filename)');
    } catch (e) {
      debugPrint('[GoLive] startRecording failed: $e');
      _isRecording = false;
      _recordingPath = null;
    }
  }

  /// Stops the active screen recorder. Safe to call when nothing is recording.
  /// Updates `_recordingPath` to the final file location returned by the
  /// plugin. Does NOT delete the file.
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      final path = await FlutterScreenRecording.stopRecordScreen;
      _recordingPath = path;
      debugPrint('[GoLive] recording stopped, file at $path');
    } catch (e) {
      debugPrint('[GoLive] stopRecording failed: $e');
    } finally {
      _isRecording = false;
    }
  }

  /// Apply a filter's native beauty options to the Agora engine. Color-grading
  /// (Warm/Cool/Noir/Cinema) is rendered in the widget tree via ColorFiltered.
  Future<void> _applyFilterToEngine(VideoFilter filter) async {
    if (_engine == null) return;
    try {
      if (filter.hasBeauty) {
        await _engine!.setBeautyEffectOptions(
          enabled: true,
          options: filter.beautyOptions!,
        );
      } else {
        // Always disable explicitly — if you switch from Beauty → Warm we don't
        // want the smoothing to persist underneath the color overlay.
        await _engine!.setBeautyEffectOptions(
          enabled: false,
          options: const BeautyOptions(),
        );
      }
    } catch (e) {
      debugPrint('[GoLive] setBeautyEffectOptions failed (non-fatal): $e');
    }
  }

  /// Called by the FilterToggleButton on the broadcast view when the host
  /// picks a new filter mid-stream. Engine update is fire-and-forget; the
  /// setState rebuild applies the new ColorFilter overlay immediately.
  void _changeFilter(VideoFilter filter) {
    setState(() => _filterId = filter.id);
    _applyFilterToEngine(filter);
  }

  Future<void> _stopStream() async {
    if (_activeStream == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final streamId = _activeStream!.id;

    // Stop the recorder BEFORE leaving the channel so the trailing frames
    // get flushed into the mp4 container. Capture the path locally because
    // _recordingPath is cleared by setState below.
    await _stopRecording();
    final recordingPath = _recordingPath;

    // Commit estimated session earnings to the user doc before tearing down.
    if (user != null) {
      final stats = ref.read(sessionStatsProvider(streamId));
      if (stats.estimatedEarningsUsd > 0) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'estimatedEarningsUsd':
              FieldValue.increment(stats.estimatedEarningsUsd),
        }).catchError((_) {});
      }
      ref.read(sessionStatsProvider(streamId).notifier).reset();
      await ref.read(streamServiceProvider).endStream(streamId, user.uid);
    }
    await _engine?.leaveChannel();
    // sync: true blocks until the native engine has fully torn down. Without
    // this, an immediate retry of Go Live can race the still-releasing native
    // singleton and fail with -17 (JOIN_REJECTED).
    await _engine?.release(sync: true);
    _engine = null;
    setState(() {
      _isStreaming = false;
      _activeStream = null;
      _recordingPath = null;
    });

    // If we recorded successfully, hand the file off to the post-stream
    // editor (Phase 1: stub). Otherwise just back out.
    final hasRecording =
        recordingPath != null && await File(recordingPath).exists();
    if (!mounted) return;
    if (hasRecording) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PostStreamEditorScreen(recordingPath: recordingPath),
        ),
      );
    } else {
      Navigator.pop(context);
    }
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
        filterId: _filterId,
        onFilterChange: _changeFilter,
        onInvite: _inviteCoHost,
        onEnd: _stopStream,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Go Live')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stream Title', style: TextStyle(color: QBrand.fgMute, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: QBrand.fg),
              decoration: InputDecoration(
                hintText: "What's your stream about?",
                hintStyle: const TextStyle(color: QBrand.fgDim),
                filled: true,
                fillColor: QBrand.cardAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Category', style: TextStyle(color: QBrand.fgMute, fontSize: 12)),
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
                      color: sel ? QBrand.primary : QBrand.cardAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          color: sel ? Colors.white : QBrand.fg,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Room Mode toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _roomMode ? QBrand.primaryDim : QBrand.cardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _roomMode ? QBrand.primary : QBrand.hairline),
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
                            Text('🏠 Room Mode',
                                style: TextStyle(color: QBrand.fg, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Co-hosts appear in the same virtual space',
                                style: TextStyle(color: QBrand.fgMute, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _roomMode,
                        onChanged: (v) => setState(() => _roomMode = v),
                        activeThumbColor: QBrand.primary,
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
            const SizedBox(height: 20),

            // Filters
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Filters',
                style: TextStyle(color: QBrand.fgMute, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            FilterPicker(
              selectedId: _filterId,
              onSelected: (f) => setState(() => _filterId = f.id),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startStream,
                icon: _starting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.videocam),
                label: Text(
                  _starting ? 'Going live…' : 'Go Live',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
class _BroadcastView extends ConsumerStatefulWidget {
  final LiveStream stream;
  final RtcEngine engine;
  final bool roomMode;
  final CoHostService cohostService;
  final String filterId;
  final ValueChanged<VideoFilter> onFilterChange;
  final VoidCallback onInvite;
  final VoidCallback onEnd;

  const _BroadcastView({
    required this.stream,
    required this.engine,
    required this.roomMode,
    required this.cohostService,
    required this.filterId,
    required this.onFilterChange,
    required this.onInvite,
    required this.onEnd,
  });

  @override
  ConsumerState<_BroadcastView> createState() => _BroadcastViewState();
}

class _BroadcastViewState extends ConsumerState<_BroadcastView> {
  // The video controller is held in state so it survives parent rebuilds
  // (viewer-count tick, danmaku delivery, screen-recording display events).
  // Constructing a fresh controller inside build() leaves the camera preview
  // surface unrendered.
  late final VideoViewController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoViewController(
      rtcEngine: widget.engine,
      canvas: const VideoCanvas(uid: 0),
      // Render via Flutter Texture rather than Android SurfaceView. The
      // default SurfaceView path can be obscured (or Z-ordered behind the
      // window background) when MediaProjection's virtual display is active
      // for screen recording, producing a black preview even though the
      // camera is actively capturing.
      useFlutterTexture: true,
    );
  }

  // Convenience getters so the build method below stays close to the original.
  LiveStream get stream => widget.stream;
  RtcEngine get engine => widget.engine;
  bool get roomMode => widget.roomMode;
  CoHostService get cohostService => widget.cohostService;
  String get filterId => widget.filterId;
  ValueChanged<VideoFilter> get onFilterChange => widget.onFilterChange;
  VoidCallback get onInvite => widget.onInvite;
  VoidCallback get onEnd => widget.onEnd;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(danmakuMessagesProvider(stream.id));
    final streamAsync = ref.watch(singleStreamProvider(stream.id));
    final liveStream = streamAsync.valueOrNull ?? stream;
    final filter = VideoFilter.byId(filterId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview, optionally wrapped in a color-grading filter.
          // Beauty preset uses Agora's native skin smoothing (applied to the
          // ENCODED stream so viewers see it too); color-grading presets are
          // local-only via ColorFiltered (viewers see the unfiltered feed).
          if (filter.hasColorOverlay)
            ColorFiltered(
              colorFilter: ColorFilter.matrix(filter.colorMatrix!),
              child: AgoraVideoView(controller: _videoController),
            )
          else
            AgoraVideoView(controller: _videoController),
          DanmakuOverlay(messages: messages),
          GiftAnimationOverlay(streamId: stream.id),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: QBrand.love, borderRadius: BorderRadius.circular(999)),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: QBrand.primary, borderRadius: BorderRadius.circular(999)),
                        child: const Text('🏠 ROOM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const Spacer(),
                    // Invite co-host button
                    GestureDetector(
                      onTap: onInvite,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(children: [
                          Icon(Icons.person_add, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Invite', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: QBrand.love, borderRadius: BorderRadius.circular(999)),
                        child: const Text('End', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
          // Live captions toggle (top right, below the End/Invite row).
          // Pushed to y=120 because devices with display cutouts have a
          // SafeArea > 40px, which made the previous top:64 collide with
          // the End button row.
          Positioned(
            right: 16, top: 120,
            child: CaptionsController(streamId: stream.id),
          ),
          // Filter picker chip (top right, stacked under the CC pill).
          Positioned(
            right: 16, top: 196,
            child: FilterToggleButton(
              currentFilterId: filterId,
              onFilterChange: onFilterChange,
            ),
          ),
          // Session earnings card (left side, above the chat overlay)
          Positioned(
            left: 12, top: 64,
            child: SessionEarningsCard(streamId: stream.id),
          ),
          // ProductDrawer — host sees the same surface viewers see, with a
          // dismiss-from-anywhere callback that clears the published products.
          ProductDrawer(
            products: liveStream.featuredProducts,
            featuredAd: liveStream.featuredAd,
            onClose: () =>
                ref.read(streamServiceProvider).dismissProducts(stream.id),
            onAffiliateClick: () => ref
                .read(sessionStatsProvider(stream.id).notifier)
                .onAffiliateClick(),
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
              style: ElevatedButton.styleFrom(backgroundColor: QBrand.primary),
              child: const Text('Invite'),
            ),
          )),
        ],
      ),
    );
  }
}
