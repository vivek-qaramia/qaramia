import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../theme/brand.dart';

/// Stub editor surface shown after a host ends their live stream.
///
/// v1 of this screen only loops the recorded file and lets the host discard
/// it. Phase 2 will add the trim slider, filter row, music picker, and the
/// "Save & Publish" pipeline that re-encodes via FFmpeg and uploads to
/// Firebase Storage.
class PostStreamEditorScreen extends ConsumerStatefulWidget {
  final String recordingPath;
  const PostStreamEditorScreen({super.key, required this.recordingPath});

  @override
  ConsumerState<PostStreamEditorScreen> createState() => _PostStreamEditorScreenState();
}

class _PostStreamEditorScreenState extends ConsumerState<PostStreamEditorScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  String? _initError;

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

  void _continue() {
    // Phase 2: replace this with the trim + filter + music + publish flow.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trim + filter + music editor coming in the next commit.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _discard),
        title: const Text('Edit & Publish'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _initError != null
                ? _ErrorState(message: _initError!, path: widget.recordingPath)
                : !_initialized
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _ctrl.value.aspectRatio == 0
                                ? 9 / 16
                                : _ctrl.value.aspectRatio,
                            child: VideoPlayer(_ctrl),
                          ),
                        ),
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
                      onPressed: _initialized ? _continue : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Continue'),
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
