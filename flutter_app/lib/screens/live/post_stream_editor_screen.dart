import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/video_filter.dart';
import '../../providers/providers.dart';
import '../../services/video_upload_service.dart';
import '../../theme/brand.dart';
import '../../widgets/filter_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.recordingPath));
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      _ctrl.setLooping(true);
      _ctrl.play();
    }).catchError((e) {
      if (mounted) setState(() => _initError = '$e');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
      _stage = 'Uploading…';
      _uploadProgress = 0;
    });
    // Pause playback so we're not contending with the upload for IO.
    await _ctrl.pause();

    try {
      final file = File(widget.recordingPath);
      if (!await file.exists()) {
        throw Exception('Recording missing at ${widget.recordingPath}');
      }

      await VideoUploadService().uploadAndPublish(
        file: file,
        authorUid: user.uid,
        authorUsername: currentUser.username,
        authorAvatarUrl: currentUser.avatarUrl,
        caption: '',
        filterId: _filterId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      try { await file.delete(); } catch (_) {}

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

  /// Returns the preview widget, optionally wrapped in a ColorFiltered overlay
  /// matching the chosen color-grading preset. Beauty has no color matrix and
  /// can't be applied to a recorded clip without re-encoding, so it renders
  /// as Normal here — selecting it in the picker is a no-op visually but the
  /// filterId is still saved on the published doc.
  Widget _filteredPreview() {
    final filter = VideoFilter.byId(_filterId);
    final player = VideoPlayer(_ctrl);
    if (!filter.hasColorOverlay) return player;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(filter.colorMatrix!),
      child: player,
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
