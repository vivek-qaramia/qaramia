import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/stitch_request.dart';
import '../../models/video.dart';
import '../../providers/providers.dart';
import '../../services/video_trim_service.dart';
import '../../theme/brand.dart';
import '../live/post_stream_editor_screen.dart';

String _fmt(double ms) {
  final d = Duration(milliseconds: ms.toInt());
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Bottom sheet where user A picks the segment of [video] to ask for.
void showRequestStitchSheet(BuildContext context, Video video, Duration total) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RequestStitchSheet(video: video, totalMs: total.inMilliseconds.toDouble()),
  );
}

class _RequestStitchSheet extends ConsumerStatefulWidget {
  final Video video;
  final double totalMs;
  const _RequestStitchSheet({required this.video, required this.totalMs});

  @override
  ConsumerState<_RequestStitchSheet> createState() => _RequestStitchSheetState();
}

class _RequestStitchSheetState extends ConsumerState<_RequestStitchSheet> {
  late RangeValues _range = RangeValues(0, widget.totalMs);
  bool _sending = false;

  Future<void> _send() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(stitchServiceProvider).request(
            requesterUid: me.uid,
            requesterUsername: me.username,
            ownerUid: widget.video.authorUid,
            videoId: widget.video.id,
            startMs: _range.start,
            endMs: _range.end,
          );
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text('Request sent to @${widget.video.authorUsername}.')));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(
          content: Text('Request failed: $e'), backgroundColor: QBrand.love));
    }
  }

  @override
  Widget build(BuildContext context) {
    // RangeSlider needs min < max; a video with unknown length can't be picked.
    final ready = widget.totalMs > 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stitch with @${widget.video.authorUsername}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Pick the part you want to use. They have to approve before you can.'),
          const SizedBox(height: 12),
          if (ready) ...[
            RangeSlider(
              values: _range,
              min: 0,
              max: widget.totalMs,
              onChanged: (v) => setState(() => _range = v),
            ),
            Text('${_fmt(_range.start)} – ${_fmt(_range.end)}  (${_fmt(_range.end - _range.start)} selected)'),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready && !_sending && _range.end > _range.start ? _send : null,
              child: Text(_sending ? 'Sending…' : 'Send request'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Requests sent to me (approve / decline) and requests I've sent (status).
class StitchInboxScreen extends ConsumerWidget {
  const StitchInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Sign in first')));
    final incoming = ref.watch(stitchIncomingProvider(uid)).valueOrNull ?? [];
    final sent = ref.watch(stitchSentProvider(uid)).valueOrNull ?? [];
    final service = ref.read(stitchServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stitch requests')),
      body: ListView(
        children: [
          const _Header('Requests to you'),
          if (incoming.isEmpty) const _Empty('Nothing waiting.'),
          for (final r in incoming)
            ListTile(
              title: Text('@${r.requesterUsername} wants ${_fmt(r.endMs - r.startMs)} of your video'),
              subtitle: Text('${_fmt(r.startMs)} – ${_fmt(r.endMs)} · ${r.status}'),
              trailing: r.isPending
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Decline',
                        icon: const Icon(Icons.close, color: QBrand.love),
                        onPressed: () => service.respond(r.id, approve: false),
                      ),
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check, color: QBrand.primary),
                        onPressed: () => service.respond(r.id, approve: true),
                      ),
                    ])
                  : null,
            ),
          const _Header('Your requests'),
          if (sent.isEmpty) const _Empty('You haven\'t requested any stitches.'),
          for (final r in sent) _SentTile(request: r),
        ],
      ),
    );
  }
}

class _SentTile extends ConsumerWidget {
  final StitchRequest request;
  const _SentTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        title: Text('${_fmt(request.startMs)} – ${_fmt(request.endMs)}'),
        subtitle: Text(request.status),
        leading: Icon(
          request.isApproved ? Icons.check_circle : Icons.hourglass_bottom,
          color: request.isApproved ? QBrand.primary : QBrand.fgMute,
        ),
        trailing: request.isApproved
            ? FilledButton(
                onPressed: () => _buildStitch(context, ref, request),
                child: const Text('Stitch'),
              )
            : null,
      );
}

const _maxStitchMs = 180000;

/// Approved request → pick my clip, download + trim their segment, join them
/// (their segment first, then mine) and open the editor to publish.
Future<void> _buildStitch(BuildContext context, WidgetRef ref, StitchRequest r) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final me = ref.read(currentUserProvider).valueOrNull;
  if (me == null) return;

  final source = await showDialog<ImageSource>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Your clip'),
      children: [
        SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Record')),
        SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Import from gallery')),
      ],
    ),
  );
  if (source == null) return;
  final own = await ImagePicker().pickVideo(source: source);
  if (own == null) return;

  showDialog(
    context: nav.context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final temps = <String>[own.path];
  try {
    // Reject up front if the result would be over 3 minutes.
    final probe = VideoPlayerController.file(File(own.path));
    await probe.initialize();
    final ownMs = probe.value.duration.inMilliseconds;
    await probe.dispose();
    if (ownMs + (r.endMs - r.startMs) > _maxStitchMs) {
      throw Exception('Total length would be over 3 minutes — use a shorter clip.');
    }

    final srcVideo = await ref.read(videoServiceProvider).fetchVideo(r.videoId);
    final tmp = await getTemporaryDirectory();
    final downloaded = '${tmp.path}/stitch_src_${r.id}.mp4';
    temps.add(downloaded);
    await Dio().download(srcVideo.videoUrl, downloaded);

    final service = VideoTrimService();
    final segment = await service.trim(
      inputPath: downloaded,
      start: Duration(milliseconds: r.startMs.toInt()),
      end: Duration(milliseconds: r.endMs.toInt()),
    );
    temps.add(segment);
    final stitched = await service.stitch(inputPaths: [segment, own.path]);

    nav.pop(); // progress dialog
    nav.push(MaterialPageRoute(
      builder: (_) => PostStreamEditorScreen(
        recordingPath: stitched,
        stitchedFrom: [
          {
            'videoId': r.videoId,
            'authorUid': r.ownerUid,
            'authorUsername': srcVideo.authorUsername,
          }
        ],
      ),
    ));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(
        content: Text('Stitch failed: $e'), backgroundColor: QBrand.love));
  } finally {
    for (final p in temps) {
      try { await File(p).delete(); } catch (_) {}
    }
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text, style: const TextStyle(color: QBrand.fgMute)),
      );
}
