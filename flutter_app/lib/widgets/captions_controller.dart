import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_info.dart';
import '../providers/ad_providers.dart';
import '../providers/providers.dart';
import '../providers/session_stats_provider.dart';
import '../services/caption_engine.dart';
import '../theme/brand.dart';

/// Host-side captions controller: a tiny inline UI (toggle pill + live preview)
/// plus the engine that fans transcript out to viewers and feeds the spoken
/// product detector.
///
/// When toggled on:
///   1. CaptionEngine listens continuously to the streamer's mic
///   2. Each interim / final transcript is throttled-written to RTDB at
///      captions/{streamId}/current (max 4/sec, finals always)
///   3. The streamer sees a small live preview of what they just said
///   4. Final transcripts feed a 30-second rolling buffer
///   5. Every 8 seconds at most, the buffer is tokenised + matchAd()
///   6. On match: a synthetic ProductInfo(source: speech) is published via
///      streamService.publishProducts() so viewers see the same drawer they
///      would from a visual scan
class CaptionsController extends ConsumerStatefulWidget {
  final String streamId;
  const CaptionsController({super.key, required this.streamId});

  @override
  ConsumerState<CaptionsController> createState() => _CaptionsControllerState();
}

class _CaptionsControllerState extends ConsumerState<CaptionsController> {
  bool _enabled = false;
  // Default false because CaptionsController is only mounted inside the
  // host's _BroadcastView, and Android's SpeechRecognizer can't open the
  // mic while Agora is broadcasting (the broadcaster role holds AudioRecord
  // exclusively). The disabled-pill UI below renders accordingly and the
  // tap handler is gated by _supported, so _toggle / _start are unreachable
  // — kept around for when Agora's AudioFrameObserver pipeline is wired up.
  bool _supported = false;
  CaptionEngine? _engine;
  String? _currentText;
  int _lastWriteMs = 0;

  // Spoken product detection buffer
  final List<({String text, int t})> _transcriptBuffer = [];
  int _lastSpeechMatchMs = 0;

  DatabaseReference get _captionRef =>
      FirebaseDatabase.instance.ref('captions/${widget.streamId}/current');

  @override
  void dispose() {
    _engine?.stop();
    _captionRef.remove();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_enabled) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    final engine = CaptionEngine(onResult: _handleResult);
    final supported = await engine.isSupported();
    if (!supported) {
      setState(() => _supported = false);
      return;
    }
    await engine.start();
    setState(() {
      _engine = engine;
      _enabled = true;
      _supported = true;
    });
  }

  Future<void> _stop() async {
    await _engine?.stop();
    await _captionRef.remove();
    setState(() {
      _engine = null;
      _enabled = false;
      _currentText = null;
      _transcriptBuffer.clear();
    });
  }

  void _handleResult(CaptionResult r) {
    if (!mounted) return;
    setState(() => _currentText = r.text);

    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle interim writes to 250ms; always send finals
    if (r.isFinal || now - _lastWriteMs >= 250) {
      _lastWriteMs = now;
      _captionRef.set({'text': r.text, 't': now, 'isFinal': r.isFinal})
          .catchError((_) {});
    }

    if (r.isFinal) _tryMatchSpoken(r.text);
  }

  Future<void> _tryMatchSpoken(String newText) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _transcriptBuffer.add((text: newText, t: now));
    _transcriptBuffer.removeWhere((e) => now - e.t > 30000);

    if (now - _lastSpeechMatchMs < 8000) return;

    final combined = _transcriptBuffer.map((e) => e.text).join(' ').toLowerCase();
    final tokens = combined.split(RegExp(r'[\s,.!?;:]+'))
        .where((t) => t.length > 2)
        .toSet()
        .take(10)
        .toList();
    if (tokens.length < 2) return;

    final adService = ref.read(adServiceProvider);
    final streamService = ref.read(streamServiceProvider);

    // Build a probe ProductInfo whose name = the joined tokens. matchAd
    // tokenises name + brand internally, so passing the joined string is
    // equivalent to passing the tokens directly.
    final probe = ProductInfo(name: tokens.join(' '), source: ProductSource.speech);
    final ad = await adService.matchAd([probe]).catchError((_) => null);
    if (ad == null) return;

    final adKeywordSet = ad.keywords.toSet();
    final matching = tokens.where(adKeywordSet.contains).toList();
    if (matching.isEmpty) return;

    _lastSpeechMatchMs = now;
    final displayName = matching
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    await streamService.publishProducts(
      widget.streamId,
      [ProductInfo(name: displayName, source: ProductSource.speech)],
      ad,
    );
    ref.read(sessionStatsProvider(widget.streamId).notifier)
        .onProductsPublished(matched: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live preview of what the host just said (only visible while running)
        if (_enabled && _currentText != null && _currentText!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              _currentText!,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        GestureDetector(
          onTap: _supported ? _toggle : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: !_supported
                  ? Colors.white.withValues(alpha: 0.05)
                  : _enabled
                      ? QBrand.primary.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _enabled ? QBrand.primary : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _enabled ? Icons.closed_caption : Icons.closed_caption_outlined,
                  color: _enabled ? Colors.white : Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  !_supported
                      ? 'CC paused while live'
                      : _enabled ? 'CC' : 'CC',
                  style: TextStyle(
                    color: _enabled ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
