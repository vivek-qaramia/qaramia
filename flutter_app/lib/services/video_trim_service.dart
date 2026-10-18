import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/video.dart' show ZoomMarker;

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
    // -c:v libx264 -preset fast -crf 21   quality-first re-encode. The old
    //              veryfast+crf 26 stacked visible softness on top of Agora's
    //              own lossy encode; crf 21 keeps detail at a larger file size
    //              (if uploads get too slow, step crf back up toward 23).
    // -movflags +faststart   moves the moov atom to the front so playback can
    //              start before the whole file finishes downloading.
    // -c:a aac    audio re-encode (mic recordings are usually AAC already
    //              but a copy can fail when the cut isn't at a keyframe)
    final cmd =
        '-y -i "$inputPath" -ss $ss -to $to '
        '-c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p -r 30 -movflags +faststart '
        '-c:a aac -b:a 128k "$outPath"';
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

  /// Re-encodes [inputPath] end-to-end with the same upload-friendly settings
  /// as [trim] but without cutting. Used when the creator publishes the full
  /// clip so the raw recording is shrunk before upload instead of sent as-is.
  /// Returns the output path; caller deletes it after upload. Throws on failure.
  Future<String> compress({required String inputPath}) async {
    final tmp = await getTemporaryDirectory();
    final outPath = '${tmp.path}/compress_${_uuid.v4()}.mp4';
    final cmd =
        '-y -i "$inputPath" '
        '-c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p -r 30 -movflags +faststart '
        '-c:a aac -b:a 128k "$outPath"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg compress failed (code ${code?.getValue()}): $logs');
    }
    final out = File(outPath);
    if (!await out.exists()) {
      throw Exception('FFmpeg returned success but no output file at $outPath');
    }
    return outPath;
  }

  /// Joins [inputPaths] (already trimmed segments, in order) into one mp4.
  /// Every segment is first normalised to 1080x1920 (letterboxed, not
  /// stretched), 30fps, yuv420p and 44.1kHz stereo audio so clips from
  /// different phones concatenate cleanly. Output is hard-capped at
  /// [maxSeconds]. Every input must have an audio track. Returns the output
  /// path; caller deletes it. Throws on failure.
  Future<String> stitch({
    required List<String> inputPaths,
    int maxSeconds = 180,
  }) async {
    if (inputPaths.length < 2) {
      throw ArgumentError('stitch needs at least two clips');
    }
    final tmp = await getTemporaryDirectory();
    final outPath = '${tmp.path}/stitch_${_uuid.v4()}.mp4';
    final inputs = inputPaths.map((p) => '-i "$p"').join(' ');
    final parts = StringBuffer();
    final labels = StringBuffer();
    for (var i = 0; i < inputPaths.length; i++) {
      parts.write('[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,'
          'pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[v$i];'
          '[$i:a]aresample=44100,aformat=channel_layouts=stereo[a$i];');
      labels.write('[v$i][a$i]');
    }
    final filter =
        '$parts${labels}concat=n=${inputPaths.length}:v=1:a=1[v][a]';
    final cmd =
        '-y $inputs -filter_complex "$filter" -map "[v]" -map "[a]" '
        '-c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p -movflags +faststart '
        '-c:a aac -b:a 128k -t $maxSeconds "$outPath"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg stitch failed (code ${code?.getValue()}): $logs');
    }
    if (!await File(outPath).exists()) {
      throw Exception('FFmpeg returned success but no output file at $outPath');
    }
    return outPath;
  }

  /// Burns editor effects into [inputPath] (already trimmed, so all times are
  /// relative to its start). Mirrors the preview's layer order: vignette →
  /// blur → colour matrix → zoom → timed overlays (text/stickers).
  ///
  /// [colorMatrix] is Flutter's 4x5 matrix (only the 3x3 RGB part is used —
  /// every preset has zero offsets). [blurSigma] is in video pixels.
  /// [vignettePng] and each overlay PNG must be full-frame ([width]x[height]).
  /// Returns the output path; caller deletes it. Throws on failure.
  Future<String> bakeEffects({
    required String inputPath,
    required int width,
    required int height,
    List<double>? colorMatrix,
    double blurSigma = 0,
    List<ZoomMarker> zooms = const [],
    String? vignettePng,
    List<({String png, double startMs, double endMs})> overlays = const [],
  }) async {
    final tmp = await getTemporaryDirectory();
    final outPath = '${tmp.path}/baked_${_uuid.v4()}.mp4';
    final args = <String>['-y', '-i', inputPath];
    var nextInput = 1;
    final chain = StringBuffer();
    var label = '0:v';
    var n = 0;
    void step(String filter, {String? extraInput}) {
      final out = 'f${n++}';
      chain.write('[$label]${extraInput == null ? '' : '[$extraInput]'}$filter[$out];');
      label = out;
    }

    if (vignettePng != null) {
      args.addAll(['-i', vignettePng]);
      step('overlay=0:0', extraInput: '${nextInput++}:v');
    }
    if (blurSigma > 0) step('gblur=sigma=${blurSigma.toStringAsFixed(2)}');
    if (colorMatrix != null) {
      final m = colorMatrix;
      step('colorchannelmixer=rr=${m[0]}:rg=${m[1]}:rb=${m[2]}'
          ':gr=${m[5]}:gg=${m[6]}:gb=${m[7]}:br=${m[10]}:bg=${m[11]}:bb=${m[12]}');
    }
    final zoomExpr = _zoomExpression(zooms);
    if (zoomExpr != null) {
      // Scale up per-frame, then crop back to the original frame (centred).
      step("scale=w='trunc(iw*($zoomExpr)/2)*2':h='trunc(ih*($zoomExpr)/2)*2':eval=frame");
      step('crop=$width:$height');
    }
    for (final o in overlays) {
      args.addAll(['-i', o.png]);
      final s = (o.startMs / 1000).toStringAsFixed(3);
      final e = (o.endMs / 1000).toStringAsFixed(3);
      step("overlay=0:0:enable='between(t,$s,$e)'", extraInput: '${nextInput++}:v');
    }
    step('setsar=1,format=yuv420p');

    args.addAll([
      '-filter_complex', chain.toString().replaceFirst(RegExp(r';$'), ''),
      '-map', '[$label]', '-map', '0:a?',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
      '-pix_fmt', 'yuv420p', '-r', '30', '-movflags', '+faststart',
      '-c:a', 'copy', outPath,
    ]);
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg bake failed (code ${code?.getValue()}): $logs');
    }
    if (!await File(outPath).exists()) {
      throw Exception('FFmpeg returned success but no output file at $outPath');
    }
    return outPath;
  }

  /// FFmpeg expression (variable `t`, seconds) equivalent to
  /// `scaleAtPosition` in the editor: first marker whose window contains t
  /// wins; ramps up over 30%, holds, ramps down over the last 30%.
  String? _zoomExpression(List<ZoomMarker> zooms) {
    final active = zooms.where((z) => z.scale > 1.0).toList();
    if (active.isEmpty) return null;
    var expr = '1';
    for (final z in active.reversed) {
      final a = z.timeMs / 1000;
      final d = z.durationMs / 1000;
      final s = z.scale;
      final tt = '((t-$a)/$d)';
      final piece = 'if(lt($tt,0.3),1+($s-1)*$tt/0.3,'
          'if(gt($tt,0.7),1+($s-1)*(1-$tt)/0.3,$s))';
      expr = 'if(between(t,$a,${a + d}),$piece,$expr)';
    }
    return expr;
  }

  /// Extract a single JPEG frame from [inputPath] at [atSec] seconds (default
  /// 0.5s — slightly past 0 so we skip a possibly-black first frame). Returns
  /// the output path. Throws on FFmpeg failure.
  Future<String> generateThumbnail({
    required String inputPath,
    double atSec = 0.5,
  }) async {
    final tmp = await getTemporaryDirectory();
    final outPath = '${tmp.path}/thumb_${_uuid.v4()}.jpg';
    final ss = atSec.toStringAsFixed(2);
    // -ss before -i is the fast seek path; -frames:v 1 grabs exactly one
    // frame; -q:v 2 sets JPEG quality (2 = visually lossless-ish).
    final cmd = '-y -ss $ss -i "$inputPath" -frames:v 1 -q:v 2 "$outPath"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg thumbnail failed (code ${code?.getValue()}): $logs');
    }
    final out = File(outPath);
    if (!await out.exists()) {
      throw Exception('FFmpeg returned success but no thumbnail at $outPath');
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
