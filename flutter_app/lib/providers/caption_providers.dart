import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One snapshot of the current caption for a stream.
class CaptionState {
  final String text;
  final int t;
  final bool isFinal;
  const CaptionState({required this.text, required this.t, required this.isFinal});

  factory CaptionState.fromJson(Map<dynamic, dynamic> json) => CaptionState(
        text: json['text'] as String? ?? '',
        t: (json['t'] as num?)?.toInt() ?? 0,
        isFinal: json['isFinal'] as bool? ?? false,
      );
}

/// Real-time stream of the latest caption for a given live stream.
final captionsProvider =
    StreamProvider.family<CaptionState?, String>((ref, streamId) {
  final ref0 = FirebaseDatabase.instance.ref('captions/$streamId/current');
  return ref0.onValue.map((event) {
    final raw = event.snapshot.value;
    if (raw is! Map) return null;
    return CaptionState.fromJson(raw);
  });
});

/// Viewer-side preference for showing captions on streams. Default ON.
class CaptionPrefNotifier extends StateNotifier<bool> {
  static const _key = 'qaramia_captions_on';
  CaptionPrefNotifier() : super(true) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key);
    if (stored != null) state = stored;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

final captionPrefProvider =
    StateNotifierProvider<CaptionPrefNotifier, bool>((_) => CaptionPrefNotifier());
