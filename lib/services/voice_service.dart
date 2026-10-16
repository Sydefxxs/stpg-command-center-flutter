import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spoken guidance (turns, hazards, convoy). Works on Android, iOS and the web app.
class VoiceService {
  VoiceService._();
  static final instance = VoiceService._();

  static const _prefKey = 'voice_guidance';
  final ValueNotifier<bool> enabled = ValueNotifier(true);
  FlutterTts? _tts;
  String _last = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  Future<FlutterTts> _engine() async {
    final t = _tts;
    if (t != null) return t;
    final n = FlutterTts();
    _tts = n;
    try {
      await n.setLanguage('en-US');
      await n.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await n.setVolume(1.0);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Duck music instead of stopping it, and speak even with the ringer on silent.
        await n.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
    } catch (_) {}
    return n;
  }

  Future<void> toggle() async {
    enabled.value = !enabled.value;
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, enabled.value);
    } catch (_) {}
    if (enabled.value) {
      await speak('Voice guidance on', force: true);
    } else {
      await _tts?.stop();
    }
  }

  /// Call straight from a button tap: iPhone Safari only allows speech after a user gesture.
  void prime() {
    if (enabled.value) speak('Command center ready', force: true);
  }

  Future<void> speak(String text, {bool force = false}) async {
    if (!enabled.value || text.trim().isEmpty) return;
    final now = DateTime.now();
    if (!force && text == _last && now.difference(_lastAt).inSeconds < 20) return;
    _last = text;
    _lastAt = now;
    try {
      final t = await _engine();
      await t.speak(text);
    } catch (_) {}
  }
}
