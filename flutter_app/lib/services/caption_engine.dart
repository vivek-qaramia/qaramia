import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// One transcript update from the speech recogniser.
class CaptionResult {
  final String text;
  final bool isFinal;
  const CaptionResult({required this.text, required this.isFinal});
}

/// Wraps `speech_to_text` for continuous live captioning.
///
/// Native session length is platform-capped (Android ~30s, iOS ~60s) and
/// both stop after a stretch of silence. We restart automatically on
/// done / not-listening status so transcription appears continuous for as
/// long as [start] is in effect.
class CaptionEngine {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final void Function(CaptionResult) onResult;
  String _localeId;
  bool _shouldRun = false;
  bool _initialized = false;

  CaptionEngine({
    required this.onResult,
    String localeId = 'en_US',
  }) : _localeId = localeId;

  Future<bool> isSupported() async {
    if (_initialized) return true;
    try {
      _initialized = await _stt.initialize(
        onStatus: _onStatus,
        onError: (err) => debugPrint('Caption engine error: $err'),
      );
      return _initialized;
    } catch (e) {
      debugPrint('Caption engine init failed: $e');
      return false;
    }
  }

  /// Begin continuous listening. Safe to call repeatedly; idempotent.
  Future<bool> start() async {
    final ok = await isSupported();
    if (!ok) return false;
    _shouldRun = true;
    _listenOnce();
    return true;
  }

  /// Stop listening; further restarts are suppressed until [start] is called.
  Future<void> stop() async {
    _shouldRun = false;
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  void setLanguage(String localeId) {
    if (_localeId == localeId) return;
    _localeId = localeId;
    if (_shouldRun) {
      _stt.stop().then((_) => _listenOnce());
    }
  }

  bool get isRunning => _shouldRun;

  // ── Internal ────────────────────────────────────────────────────────────────
  void _listenOnce() {
    if (!_shouldRun) return;
    _stt.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        onResult(CaptionResult(text: text, isFinal: result.finalResult));
      },
      localeId: _localeId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
      ),
      pauseFor: const Duration(seconds: 4),
      // No listenFor → use platform default (capped natively); restart on done
    );
  }

  void _onStatus(String status) {
    // Both platforms surface 'done' / 'notListening' when a session ends —
    // restart it so the host gets continuous transcription.
    if ((status == 'done' || status == 'notListening') && _shouldRun) {
      Future.delayed(const Duration(milliseconds: 150), _listenOnce);
    }
  }
}
