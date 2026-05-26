import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/video.dart' show StickerOverlay, TextOverlay, ZoomMarker;
import '../../models/video_filter.dart';
import '../../providers/providers.dart';
import '../../services/video_trim_service.dart';
import '../../services/video_upload_service.dart';
import '../../theme/brand.dart';
import '../../widgets/filter_picker.dart';

/// Wraps the raw [player] widget in every visual edit layer the editor and
/// feed support: vignette → blur → color filter → zoom. Pure presentation,
/// no listeners — caller is responsible for re-invoking it when [positionMs]
/// changes (typically inside a `ValueListenableBuilder`).
Widget composeVideo({
  required Widget player,
  required String filterId,
  required List<ZoomMarker> zooms,
  required double blurAmount,
  required double vignetteIntensity,
  required double positionMs,
  List<TextOverlay> textOverlays = const [],
  List<StickerOverlay> stickers = const [],
}) {
  Widget result = player;

  if (vignetteIntensity > 0) {
    result = Stack(
      fit: StackFit.expand,
      children: [
        result,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: vignetteIntensity),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  if (blurAmount > 0) {
    result = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
      child: result,
    );
  }

  final filter = VideoFilter.byId(filterId);
  if (filter.hasColorOverlay) {
    result = ColorFiltered(
      colorFilter: ColorFilter.matrix(filter.colorMatrix!),
      child: result,
    );
  }

  final scale = scaleAtPosition(positionMs: positionMs, zooms: zooms);
  if (scale != 1.0) {
    result = Transform.scale(scale: scale, child: result);
  }

  // Text and sticker overlays render OUTSIDE the zoom/blur/filter layers
  // so they stay crisp and unaffected — viewers should always see them
  // clearly. Stickers are drawn ABOVE text so a sticker visually rests on
  // top of any concurrent text overlay.
  final visibleTexts = textOverlays
      .where((t) => positionMs >= t.startMs && positionMs <= t.endMs)
      .toList();
  final visibleStickers = stickers
      .where((s) => positionMs >= s.startMs && positionMs <= s.endMs)
      .toList();
  if (visibleTexts.isNotEmpty || visibleStickers.isNotEmpty) {
    result = Stack(
      fit: StackFit.expand,
      children: [
        result,
        for (final t in visibleTexts)
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  t.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1.5),
                        blurRadius: 4,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        for (final s in visibleStickers)
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                s.emoji,
                style: const TextStyle(fontSize: 80),
              ),
            ),
          ),
      ],
    );
  }

  return result;
}

/// Piecewise-linear zoom curve evaluated against a list of zoom markers.
/// Returns the scale from the FIRST marker whose window contains the
/// current position (markers are expected to be sorted by timeMs so this
/// is deterministic when windows overlap). Returns 1.0 if no marker covers
/// the position. Pure function so the feed can apply the same animation.
double scaleAtPosition({
  required double positionMs,
  required List<ZoomMarker> zooms,
}) {
  for (final z in zooms) {
    if (z.scale <= 1.0) continue;
    final delta = positionMs - z.timeMs;
    if (delta < 0 || delta > z.durationMs) continue;
    final t = delta / z.durationMs;
    if (t < 0.3) return 1.0 + (z.scale - 1.0) * (t / 0.3);
    if (t > 0.7) return 1.0 + (z.scale - 1.0) * ((1.0 - t) / 0.3);
    return z.scale;
  }
  return 1.0;
}

/// Post-stream editor (v1): preview the recorded clip, then either discard it
/// or publish it as-is to the public feed. Trim, filter, and music are
/// deferred to a later phase to avoid pulling in the discontinued FFmpegKit.
class PostStreamEditorScreen extends ConsumerStatefulWidget {
  final String recordingPath;
  const PostStreamEditorScreen({super.key, required this.recordingPath});

  @override
  ConsumerState<PostStreamEditorScreen> createState() => _PostStreamEditorScreenState();
}

class _PostStreamEditorScreenState extends ConsumerState<PostStreamEditorScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _processing = false;
  double _uploadProgress = 0; // 0.0–1.0
  String _stage = '';
  String? _initError;
  String _filterId = 'none';
  // Trim window. Both values are in milliseconds. _endMs is initialised to
  // the full duration once the video reports its metadata.
  double _startMs = 0;
  double _endMs = 0;
  // Zero or more zoom markers, sorted by timeMs. Each timestamp is relative
  // to the ORIGINAL recording — on publish we shift them by _startMs so the
  // saved markers line up with the trimmed file's timeline.
  static const double _zoomDurationMs = 2000;
  final List<ZoomMarker> _zooms = [];
  // Effects (5c): blur sigma + vignette opacity. Both 0 = off.
  double _blurAmount = 0;
  double _vignetteIntensity = 0;
  // Text overlays (5d). Each one is centred over the video for a fixed
  // 3-second window starting at the time the user added it.
  static const double _textDurationMs = 3000;
  final List<TextOverlay> _texts = [];
  final TextEditingController _textInputCtrl = TextEditingController();
  // Emoji stickers (5e). Same fixed-duration model as text overlays.
  static const double _stickerDurationMs = 3000;
  final List<StickerOverlay> _stickers = [];
  // Which effect's controls are currently expanded under the tabs. null = no
  // panel is open. Tapping the same tab again collapses it.
  String? _activeEffect;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.recordingPath));
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _endMs = _ctrl.value.duration.inMilliseconds.toDouble();
      });
      // We handle looping manually inside the trim window via the listener
      // below — VideoPlayer's setLooping(true) loops the whole file.
      _ctrl.addListener(_onTick);
      _ctrl.play();
    }).catchError((e) {
      if (mounted) setState(() => _initError = '$e');
    });
  }

  /// Keep playback inside the chosen trim window. When the position reaches
  /// _endMs we seek back to _startMs so the user sees exactly what they'd
  /// publish on each loop.
  void _onTick() {
    if (!_initialized || _processing) return;
    final posMs = _ctrl.value.position.inMilliseconds;
    if (posMs >= _endMs.toInt() - 30) {
      _ctrl.seekTo(Duration(milliseconds: _startMs.toInt()));
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    _textInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard recording?'),
        content: const Text(
            'Your live-stream recording will be permanently deleted and cannot be recovered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: QBrand.love)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final file = File(widget.recordingPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _publish() async {
    if (_processing) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (user == null || currentUser == null) {
      _showError('You need to be signed in to publish.');
      return;
    }

    setState(() {
      _processing = true;
      _stage = 'Trimming…';
      _uploadProgress = 0;
    });
    // Pause playback so we're not contending with the upload for IO.
    await _ctrl.pause();

    File? trimmedFile;
    try {
      final original = File(widget.recordingPath);
      if (!await original.exists()) {
        throw Exception('Recording missing at ${widget.recordingPath}');
      }

      // Trim only if the user actually narrowed the window — saves a slow
      // re-encode pass when they're publishing the full clip.
      final totalMs = _ctrl.value.duration.inMilliseconds;
      final isTrimmed = _startMs > 50 || _endMs < totalMs - 50;
      final fileToUpload = isTrimmed
          ? trimmedFile = File(await VideoTrimService().trim(
              inputPath: widget.recordingPath,
              start: Duration(milliseconds: _startMs.toInt()),
              end: Duration(milliseconds: _endMs.toInt()),
            ))
          : original;

      if (mounted) setState(() => _stage = 'Uploading…');

      // Each zoom marker is captured against the ORIGINAL recording. After
      // trim, the published file starts at _startMs, so shift every marker
      // by -_startMs and drop any whose window now falls outside [0, length].
      final length = _endMs - _startMs;
      final publishedZooms = <ZoomMarker>[];
      for (final z in _zooms) {
        final shifted = z.timeMs - _startMs;
        if (shifted >= 0 && shifted + z.durationMs <= length) {
          publishedZooms.add(ZoomMarker(
            timeMs: shifted,
            scale: z.scale,
            durationMs: z.durationMs,
          ));
        }
      }

      // Translate text overlays the same way as zooms: shift by -_startMs
      // and drop any whose window leaves the trimmed range. Allow partial
      // overlaps to be clamped to the visible window so a text that starts
      // before the trim still shows from the trim point onward.
      final publishedTexts = <TextOverlay>[];
      for (final t in _texts) {
        final shiftedStart = (t.startMs - _startMs).clamp(0.0, length);
        final shiftedEnd = (t.endMs - _startMs).clamp(0.0, length);
        if (shiftedEnd > shiftedStart) {
          publishedTexts.add(TextOverlay(
            text: t.text,
            startMs: shiftedStart,
            endMs: shiftedEnd,
          ));
        }
      }
      final publishedStickers = <StickerOverlay>[];
      for (final s in _stickers) {
        final shiftedStart = (s.startMs - _startMs).clamp(0.0, length);
        final shiftedEnd = (s.endMs - _startMs).clamp(0.0, length);
        if (shiftedEnd > shiftedStart) {
          publishedStickers.add(StickerOverlay(
            emoji: s.emoji,
            startMs: shiftedStart,
            endMs: shiftedEnd,
          ));
        }
      }

      await VideoUploadService().uploadAndPublish(
        file: fileToUpload,
        authorUid: user.uid,
        authorUsername: currentUser.username,
        authorAvatarUrl: currentUser.avatarUrl,
        caption: '',
        filterId: _filterId,
        zooms: publishedZooms,
        blurAmount: _blurAmount,
        vignetteIntensity: _vignetteIntensity,
        textOverlays: publishedTexts,
        stickers: publishedStickers,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      try { await original.delete(); } catch (_) {}
      if (trimmedFile != null) {
        try { await trimmedFile.delete(); } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Published to feed.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        await _ctrl.play();
        _showError('Publish failed: $e');
      }
    }
  }

  /// Returns the preview widget. Layers, innermost out:
  ///   VideoPlayer
  ///     ↓ Stack with vignette radial-gradient overlay (5c)
  ///     ↓ ImageFiltered Gaussian blur (5c)
  ///     ↓ ColorFiltered color-grade matrix (Phase 3)
  ///     ↓ Transform.scale for zoom-at-point (5b)
  ///
  /// The vignette + blur are applied inside the zoom wrapper so they scale
  /// with the zoomed-in pixels. The ValueListenable wires the scale to
  /// controller value changes without setState rebuilds.
  Widget _filteredPreview() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (_, value, _) {
        return composeVideo(
          player: VideoPlayer(_ctrl),
          filterId: _filterId,
          zooms: _zooms,
          blurAmount: _blurAmount,
          vignetteIntensity: _vignetteIntensity,
          textOverlays: _texts,
          stickers: _stickers,
          positionMs: value.position.inMilliseconds.toDouble(),
        );
      },
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: QBrand.love));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _processing ? null : _discard,
        ),
        title: const Text('Edit & Publish'),
      ),
      body: _initError != null
          ? _ErrorState(message: _initError!, path: widget.recordingPath)
          : !_initialized
              ? const Center(child: CircularProgressIndicator())
              : _processing
                  ? _ProgressView(stage: _stage, progress: _uploadProgress)
                  : Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _ctrl.value.aspectRatio == 0
                                    ? 9 / 16
                                    : _ctrl.value.aspectRatio,
                                child: _filteredPreview(),
                              ),
                            ),
                          ),
                        ),
                        _TrimBar(
                          startMs: _startMs,
                          endMs: _endMs,
                          totalMs: _ctrl.value.duration.inMilliseconds.toDouble(),
                          controller: _ctrl,
                          onChanged: (s, e) {
                            setState(() {
                              _startMs = s;
                              _endMs = e;
                            });
                          },
                          onChangeEnd: (s, e) {
                            // After releasing the handle, seek the preview
                            // to the new start so the user lands in the
                            // right spot of the trimmed window.
                            _ctrl.seekTo(Duration(milliseconds: s.toInt()));
                          },
                        ),
                        _EffectsTabs(
                          activeEffect: _activeEffect,
                          zoomActive: _zooms.isNotEmpty,
                          blurActive: _blurAmount > 0,
                          vignetteActive: _vignetteIntensity > 0,
                          textActive: _texts.isNotEmpty,
                          stickerActive: _stickers.isNotEmpty,
                          // Tap the same tab to collapse, otherwise switch
                          // to the chosen one.
                          onTap: (id) => setState(() =>
                              _activeEffect = _activeEffect == id ? null : id),
                        ),
                        if (_activeEffect == 'zoom')
                          _ZoomList(
                            controller: _ctrl,
                            zooms: _zooms,
                            onAdd: () => setState(() {
                              _zooms.add(ZoomMarker(
                                timeMs: _ctrl.value.position.inMilliseconds.toDouble(),
                                scale: 1.5,
                                durationMs: _zoomDurationMs,
                              ));
                              _zooms.sort((a, b) => a.timeMs.compareTo(b.timeMs));
                            }),
                            onScaleChanged: (i, s) => setState(() {
                              _zooms[i] = ZoomMarker(
                                timeMs: _zooms[i].timeMs,
                                scale: s,
                                durationMs: _zooms[i].durationMs,
                              );
                            }),
                            onRemove: (i) => setState(() => _zooms.removeAt(i)),
                          )
                        else if (_activeEffect == 'blur')
                          _SingleEffect(
                            label: 'Blur',
                            value: _blurAmount,
                            min: 0,
                            max: 20,
                            displayValue: _blurAmount > 0
                                ? _blurAmount.toStringAsFixed(0)
                                : 'off',
                            onChanged: (v) => setState(() => _blurAmount = v),
                          )
                        else if (_activeEffect == 'vignette')
                          _SingleEffect(
                            label: 'Vignette',
                            value: _vignetteIntensity,
                            min: 0,
                            max: 1,
                            displayValue: _vignetteIntensity > 0
                                ? '${(_vignetteIntensity * 100).toStringAsFixed(0)}%'
                                : 'off',
                            onChanged: (v) =>
                                setState(() => _vignetteIntensity = v),
                          )
                        else if (_activeEffect == 'text')
                          _TextList(
                            controller: _ctrl,
                            inputController: _textInputCtrl,
                            texts: _texts,
                            onAdd: () {
                              final text = _textInputCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                _texts.add(TextOverlay(
                                  text: text,
                                  startMs: _ctrl.value.position.inMilliseconds.toDouble(),
                                  endMs: _ctrl.value.position.inMilliseconds.toDouble() + _textDurationMs,
                                ));
                                _texts.sort((a, b) => a.startMs.compareTo(b.startMs));
                                _textInputCtrl.clear();
                              });
                            },
                            onRemove: (i) => setState(() => _texts.removeAt(i)),
                          )
                        else if (_activeEffect == 'sticker')
                          _StickerList(
                            controller: _ctrl,
                            stickers: _stickers,
                            onAdd: (emoji) {
                              setState(() {
                                _stickers.add(StickerOverlay(
                                  emoji: emoji,
                                  startMs: _ctrl.value.position.inMilliseconds.toDouble(),
                                  endMs: _ctrl.value.position.inMilliseconds.toDouble() + _stickerDurationMs,
                                ));
                                _stickers.sort((a, b) => a.startMs.compareTo(b.startMs));
                              });
                            },
                            onRemove: (i) => setState(() => _stickers.removeAt(i)),
                          ),
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: FilterPicker(
                            selectedId: _filterId,
                            onSelected: (f) => setState(() => _filterId = f.id),
                            onDark: true,
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _discard,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Discard'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _publish,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Publish'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  final String stage;
  final double progress;
  const _ProgressView({required this.stage, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: QBrand.hairline,
              color: QBrand.primary,
            ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: QBrand.fgMute, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trim control. A labelled RangeSlider with the start/end timestamps at the
/// edges, the selected-length in the middle, and a live "Now playing"
/// indicator above so the user can see where the playhead is — this is the
/// reference for placing a zoom marker.
class _TrimBar extends StatelessWidget {
  final double startMs;
  final double endMs;
  final double totalMs;
  final VideoPlayerController controller;
  final void Function(double startMs, double endMs) onChanged;
  final void Function(double startMs, double endMs) onChangeEnd;

  const _TrimBar({
    required this.startMs,
    required this.endMs,
    required this.totalMs,
    required this.controller,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static String _format(double ms) {
    final total = Duration(milliseconds: ms.toInt());
    final m = total.inMinutes;
    final s = (total.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // RangeSlider crashes when min == max, which happens briefly before the
    // video reports its duration. Bail out until we have a real range.
    if (totalMs <= 0) return const SizedBox.shrink();
    final selected = endMs - startMs;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Trim',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (_, value, _) => Text(
                  '· now ${_format(value.position.inMilliseconds.toDouble())}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Spacer(),
              Text('${_format(selected)} selected',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Text(_format(startMs),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: QBrand.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: QBrand.primary.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: RangeSlider(
                    values: RangeValues(
                        startMs.clamp(0, totalMs), endMs.clamp(0, totalMs)),
                    min: 0,
                    max: totalMs,
                    onChanged: (v) => onChanged(v.start, v.end),
                    onChangeEnd: (v) => onChangeEnd(v.start, v.end),
                  ),
                ),
              ),
              Text(_format(endMs),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Zoom panel: always-visible "Add zoom at X:XX" button (where X:XX is the
/// live playhead position) followed by one row per placed zoom. Each placed
/// zoom row has its own scale slider and remove button. The list scrolls
/// vertically if it overflows so the editor's actions row stays reachable.
class _ZoomList extends StatelessWidget {
  final VideoPlayerController controller;
  final List<ZoomMarker> zooms;
  final VoidCallback onAdd;
  final void Function(int index, double scale) onScaleChanged;
  final void Function(int index) onRemove;

  const _ZoomList({
    required this.controller,
    required this.zooms,
    required this.onAdd,
    required this.onScaleChanged,
    required this.onRemove,
  });

  static String _format(double ms) {
    final total = Duration(milliseconds: ms.toInt());
    return '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (_, value, _) => OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.zoom_in, size: 18),
                label: Text(
                    'Add zoom at ${_format(value.position.inMilliseconds.toDouble())}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
              ),
            ),
          ),
          if (zooms.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 4),
                itemCount: zooms.length,
                itemBuilder: (_, i) => _ZoomRow(
                  zoom: zooms[i],
                  onScaleChanged: (s) => onScaleChanged(i, s),
                  onRemove: () => onRemove(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single placed zoom: timestamp + scale + slider + remove. Used inside
/// [_ZoomList] for every entry the user has added.
class _ZoomRow extends StatelessWidget {
  final ZoomMarker zoom;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onRemove;
  const _ZoomRow({
    required this.zoom,
    required this.onScaleChanged,
    required this.onRemove,
  });

  static String _format(double ms) {
    final total = Duration(milliseconds: ms.toInt());
    return '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.zoom_in, color: Colors.white, size: 16),
        const SizedBox(width: 4),
        Text(
          '${_format(zoom.timeMs)} · ${zoom.scale.toStringAsFixed(1)}x',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: QBrand.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: QBrand.primary.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: zoom.scale.clamp(1.0, 3.0),
              min: 1.0,
              max: 3.0,
              divisions: 20,
              onChanged: onScaleChanged,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.white70),
          onPressed: onRemove,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Tab strip with three chips — Zoom, Blur, Vignette. Tapping a chip selects
/// it (so its panel renders below); tapping the active chip collapses the
/// panel. A small primary-coloured dot appears on the chip when the effect
/// has non-default values, so the user can tell which effects are applied
/// even when the panel is collapsed.
class _EffectsTabs extends StatelessWidget {
  final String? activeEffect;
  final bool zoomActive;
  final bool blurActive;
  final bool vignetteActive;
  final bool textActive;
  final bool stickerActive;
  final ValueChanged<String> onTap;

  const _EffectsTabs({
    required this.activeEffect,
    required this.zoomActive,
    required this.blurActive,
    required this.vignetteActive,
    required this.textActive,
    required this.stickerActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The tab list scrolls horizontally so a fifth/sixth tab (stickers in
    // Phase 5e, etc.) can be added without breaking layout on narrow screens.
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _Tab(
              id: 'zoom',
              label: 'Zoom',
              icon: Icons.zoom_in,
              selected: activeEffect == 'zoom',
              applied: zoomActive,
              onTap: onTap,
            ),
            const SizedBox(width: 8),
            _Tab(
              id: 'blur',
              label: 'Blur',
              icon: Icons.blur_on,
              selected: activeEffect == 'blur',
              applied: blurActive,
              onTap: onTap,
            ),
            const SizedBox(width: 8),
            _Tab(
              id: 'vignette',
              label: 'Vignette',
              icon: Icons.vignette,
              selected: activeEffect == 'vignette',
              applied: vignetteActive,
              onTap: onTap,
            ),
            const SizedBox(width: 8),
            _Tab(
              id: 'text',
              label: 'Text',
              icon: Icons.title,
              selected: activeEffect == 'text',
              applied: textActive,
              onTap: onTap,
            ),
            const SizedBox(width: 8),
            _Tab(
              id: 'sticker',
              label: 'Sticker',
              icon: Icons.emoji_emotions_outlined,
              selected: activeEffect == 'sticker',
              applied: stickerActive,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final bool applied;
  final ValueChanged<String> onTap;
  const _Tab({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.applied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? QBrand.primary : Colors.white12,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? QBrand.primary : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            if (applied && !selected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: QBrand.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic labelled slider used for both the Blur and Vignette panels under
/// the effect tabs. The Zoom panel uses [_ZoomList] instead because it has
/// multiple markers + an Add button.
class _SingleEffect extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SingleEffect({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: QBrand.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: QBrand.primary.withValues(alpha: 0.2),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text-overlay panel. Input field on top, "Add at X:XX" button driven by
/// the live playhead, then a vertically-scrollable list of placed overlays
/// (each with text preview + time range + remove). Style is locked for v1:
/// large bold white text, centred, 3-second duration.
class _TextList extends StatelessWidget {
  final VideoPlayerController controller;
  final TextEditingController inputController;
  final List<TextOverlay> texts;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _TextList({
    required this.controller,
    required this.inputController,
    required this.texts,
    required this.onAdd,
    required this.onRemove,
  });

  static String _format(double ms) {
    final total = Duration(milliseconds: ms.toInt());
    return '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: QBrand.primary,
                  decoration: InputDecoration(
                    hintText: 'Type text',
                    hintStyle: const TextStyle(color: Colors.white38),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: QBrand.primary),
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (_, value, _) => OutlinedButton(
                  onPressed: onAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text('Add at ${_format(value.position.inMilliseconds.toDouble())}'),
                ),
              ),
            ],
          ),
          if (texts.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 6),
                itemCount: texts.length,
                itemBuilder: (_, i) {
                  final t = texts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.title, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '"${t.text}"  ·  ${_format(t.startMs)}–${_format(t.endMs)}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.white70),
                          onPressed: () => onRemove(i),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

/// Emoji-sticker panel: a horizontal palette of common emojis followed by
/// a list of placed stickers. Tap an emoji in the palette to drop it at
/// the current playhead with a fixed 3-second window.
class _StickerList extends StatelessWidget {
  final VideoPlayerController controller;
  final List<StickerOverlay> stickers;
  final ValueChanged<String> onAdd;
  final void Function(int index) onRemove;

  const _StickerList({
    required this.controller,
    required this.stickers,
    required this.onAdd,
    required this.onRemove,
  });

  // Small curated palette. The user can't pick arbitrary emojis in v1 —
  // a full picker would mean integrating a third-party emoji-keyboard
  // plugin. These cover the common reaction set.
  static const _palette = [
    '😀', '😂', '🥰', '😍', '🤩', '😎', '🤔', '😱',
    '👍', '👏', '🙏', '🔥', '💯', '⭐', '✨', '🎉',
    '❤️', '💕', '💔', '🚀', '👀', '💩', '🤡', '🐐',
  ];

  static String _format(double ms) {
    final total = Duration(milliseconds: ms.toInt());
    return '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) => Text(
              'Tap to add at ${_format(value.position.inMilliseconds.toDouble())}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _palette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final emoji = _palette[i];
                return GestureDetector(
                  onTap: () => onAdd(emoji),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
          if (stickers.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 4),
                itemCount: stickers.length,
                itemBuilder: (_, i) {
                  final s = stickers[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_format(s.startMs)}–${_format(s.endMs)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.white70),
                          onPressed: () => onRemove(i),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final String path;
  const _ErrorState({required this.message, required this.path});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text("Couldn't load the recording",
                style: TextStyle(color: QBrand.fg, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: QBrand.fgMute, fontSize: 12)),
            const SizedBox(height: 12),
            Text(path,
                textAlign: TextAlign.center,
                style: const TextStyle(color: QBrand.fgDim, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
