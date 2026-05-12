import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/caption_providers.dart';

/// Viewer subtitle band. Centred over the stream above the bottom controls;
/// fades to 30% opacity after 5 seconds of silence so it doesn't sit
/// distractingly bright on the screen if the host stops talking.
class CaptionOverlay extends ConsumerStatefulWidget {
  final String streamId;
  const CaptionOverlay({super.key, required this.streamId});

  @override
  ConsumerState<CaptionOverlay> createState() => _CaptionOverlayState();
}

class _CaptionOverlayState extends ConsumerState<CaptionOverlay> {
  static const _staleAfterMs = 5000;
  bool _stale = false;
  Timer? _staleTimer;
  int? _lastT;

  void _scheduleStale(int t) {
    if (_lastT == t) return;
    _lastT = t;
    _stale = false;
    _staleTimer?.cancel();
    final elapsed = DateTime.now().millisecondsSinceEpoch - t;
    final remaining = (_staleAfterMs - elapsed).clamp(0, _staleAfterMs);
    _staleTimer = Timer(Duration(milliseconds: remaining), () {
      if (mounted) setState(() => _stale = true);
    });
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(captionPrefProvider);
    if (!enabled) return const SizedBox.shrink();

    final caption = ref.watch(captionsProvider(widget.streamId)).valueOrNull;
    if (caption == null || caption.text.isEmpty) return const SizedBox.shrink();

    _scheduleStale(caption.t);

    return Positioned(
      left: 16, right: 16, bottom: 96,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _stale ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  caption.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viewer-side CC toggle pill. Reads/writes [captionPrefProvider]. Drop in
/// the top-right of the live viewer chrome.
class CaptionToggleButton extends ConsumerWidget {
  const CaptionToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(captionPrefProvider);
    return GestureDetector(
      onTap: () => ref.read(captionPrefProvider.notifier).toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? Colors.white30 : Colors.white12,
          ),
        ),
        child: Text(
          'CC',
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
