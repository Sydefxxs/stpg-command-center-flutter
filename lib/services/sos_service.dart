import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/supabase_api.dart';
import '../config.dart';
import '../state/app_state.dart';

/// One-tap SOS: creates an ACTIVE "SOS" assistance request and keeps its
/// coordinates updated every [StpgConfig.sosBeaconSeconds] until cancelled
/// or resolved by STPG Command.
class SosService {
  SosService._();
  static final instance = SosService._();

  static const _prefKey = 'sos_request_id';

  /// True while an SOS beacon is broadcasting.
  final ValueNotifier<bool> active = ValueNotifier(false);

  /// Time of the last successful location update.
  final ValueNotifier<DateTime?> lastSent = ValueNotifier(null);

  String? _requestId;
  Timer? _timer;
  bool _busy = false;

  /// After login: resume a beacon if this driver still has an ACTIVE SOS request.
  Future<void> restore(AppState app) async {
    final id = app.prefs.getString(_prefKey);
    if (id == null) return;
    try {
      final req = await app.authed((t) async =>
          SupabaseApi.fetchActiveAssistanceRequest(t, await app.ensureUserId()));
      if (req != null && req.id == id && req.requestType == 'SOS') {
        _begin(app, id);
      } else {
        await _clear(app);
      }
    } catch (_) {
      // Network trouble: keep the id and try again next launch.
    }
  }

  /// Create an SOS assistance request and start sending location updates. Returns error text or null.
  Future<String?> start(AppState app, {String type = 'SOS', String message = ''}) async {
    if (active.value || _busy) return null;
    final gps = app.gps;
    if (!gps.hasFix) return 'WAITING FOR GPS LOCK...';
    _busy = true;
    try {
      final userId = await app.ensureUserId();
      await app.authed((t) => SupabaseApi.createAssistanceRequest(
            t,
            userId,
            type,
            message.trim().isEmpty ? 'SOS BEACON ACTIVE' : message.trim(),
            gps.latitude,
            gps.longitude,
          ));
      final req = await app.authed((t) => SupabaseApi.fetchActiveAssistanceRequest(t, userId));
      if (req == null) return 'SYSTEM ERROR // SOS request was not confirmed';
      await app.prefs.setString(_prefKey, req.id);
      lastSent.value = DateTime.now();
      _begin(app, req.id);
      return null;
    } on SupabaseException catch (e) {
      return 'SYSTEM ERROR // ${e.message}';
    } catch (e) {
      return 'NETWORK ERROR // $e';
    } finally {
      _busy = false;
    }
  }

  /// Cancel the SOS request and stop the beacon. Returns error text or null.
  Future<String?> stop(AppState app) async {
    final id = _requestId;
    if (id == null) {
      await _clear(app);
      return null;
    }
    try {
      await app.authed((t) => SupabaseApi.cancelAssistanceRequest(t, id));
      await _clear(app);
      return null;
    } on SupabaseException catch (e) {
      return 'SYSTEM ERROR // ${e.message}';
    } catch (e) {
      return 'NETWORK ERROR // $e';
    }
  }

  void _begin(AppState app, String id) {
    _requestId = id;
    active.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: StpgConfig.sosBeaconSeconds), (_) => _tick(app));
  }

  Future<void> _tick(AppState app) async {
    final id = _requestId;
    if (id == null || app.session == null) return;
    final gps = app.gps;
    try {
      // Stop if STPG Command resolved (or the driver cancelled) the request elsewhere.
      final req = await app.authed((t) async =>
          SupabaseApi.fetchActiveAssistanceRequest(t, await app.ensureUserId()));
      if (req == null || req.id != id) {
        await _clear(app);
        return;
      }
      if (!gps.hasFix) return;
      await app.authed((t) => _patch(t, id, {'latitude': gps.latitude, 'longitude': gps.longitude}));
      lastSent.value = DateTime.now();
    } catch (_) {
      // Offline: the next tick sends the newest position.
    }
  }

  static Future<void> _patch(String token, String id, Map<String, dynamic> body) async {
    final r = await http.patch(
      Uri.parse('${StpgConfig.supabaseUrl}/rest/v1/stpg_assistance_requests?id=eq.$id'),
      headers: {
        'apikey': StpgConfig.supabasePublishableKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw SupabaseException(SupabaseApi.extractError(r.body), r.statusCode);
    }
  }

  Future<void> _clear(AppState app) async {
    _timer?.cancel();
    _timer = null;
    _requestId = null;
    active.value = false;
    lastSent.value = null;
    await app.prefs.remove(_prefKey);
  }
}
