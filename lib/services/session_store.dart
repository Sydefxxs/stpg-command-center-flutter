import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the sign-in tokens: Keychain (iOS) / encrypted storage (Android);
/// the browser's local storage on the web, where nothing safer exists.
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage();
  static const _kAccess = 'stpg_session_access';
  static const _kRefresh = 'stpg_session_refresh';

  Future<(String?, String?)> read() async {
    if (kIsWeb) return (_prefs.getString(_kAccess), _prefs.getString(_kRefresh));
    try {
      final a = await _secure.read(key: _kAccess);
      final r = await _secure.read(key: _kRefresh);
      if (a != null && r != null) return (a, r);
    } catch (_) {}
    // One-time move of tokens saved by older versions in plain preferences.
    final a = _prefs.getString(_kAccess), r = _prefs.getString(_kRefresh);
    if (a != null && r != null) {
      await write(a, r);
      await _prefs.remove(_kAccess);
      await _prefs.remove(_kRefresh);
    }
    return (a, r);
  }

  Future<void> write(String access, String refresh) async {
    if (kIsWeb) {
      await _prefs.setString(_kAccess, access);
      await _prefs.setString(_kRefresh, refresh);
      return;
    }
    try {
      await _secure.write(key: _kAccess, value: access);
      await _secure.write(key: _kRefresh, value: refresh);
    } catch (_) {}
  }

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    if (kIsWeb) return;
    try {
      await _secure.delete(key: _kAccess);
      await _secure.delete(key: _kRefresh);
    } catch (_) {}
  }
}
