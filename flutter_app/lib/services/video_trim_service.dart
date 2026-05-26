import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Trims a video to a [start, end] segment using FFmpeg.
///
/// Re-encodes with libx264 ultrafast so the cut is frame-accurate (stream-copy
/// `-c copy` only cuts at keyframes — off by up to a second on screen
/// recordings). Audio is copied as-is when possible.
class VideoTrimService {
  static const _uuid = Uuid();

  /// Returns the path to the trimmed mp4. Caller is responsible for deleting
  /// it after upload. Throws on FFmpeg failure.
  Future<String> trim({
    required String inputPath,
    required Duration start,
    required Duration end,
  }) async {
    final tmp = await getTemporaryDirectory();
    final outPath = '${tmp.path}/trim_${_uuid.v4()}.mp4';
    final ss = _hhmmss(start);
    final to = _hhmmss(end);

    // -y          overwrite output if it exists
    // -i input    source
    // -ss / -to   trim window
    // -c:v libx264 -preset ultrafast   fast re-encode, frame-accurate
    // -c:a aac    audio re-encode (mic recordings are usually AAC already
    //              but a copy can fail when the cut isn't at a keyframe)
    final cmd =
        '-y -i "$inputPath" -ss $ss -to $to -c:v libx264 -preset ultrafast -c:a aac "$outPath"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg trim failed (code ${code?.getValue()}): $logs');
    }
    final out = File(outPath);
    if (!await out.exists()) {
      throw Exception('FFmpeg returned success but no output file at $outPath');
    }
    return outPath;
  }

  String _hhmmss(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes % 60);
    final s = two(d.inSeconds % 60);
    final ms = three(d.inMilliseconds % 1000);
    return '$h:$m:$s.$ms';
  }
}
