import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while something needs it (route active, Drive Mode, convoy map).
class WakeService {
  WakeService._();
  static final instance = WakeService._();

  final Set<String> _holders = {};

  void hold(String tag) {
    if (_holders.add(tag) && _holders.length == 1) _set(true);
  }

  void release(String tag) {
    if (_holders.remove(tag) && _holders.isEmpty) _set(false);
  }

  Future<void> _set(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {}
  }
}
