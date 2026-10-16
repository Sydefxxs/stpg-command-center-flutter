import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/supabase_api.dart';
import '../config.dart';
import '../state/app_state.dart';
import 'sos_service.dart';

class ConvoyDriver {
  final String userId;
  final String name;
  final int? driverNumber;
  final double latitude, longitude;
  final int? speedMph, heading;
  final DateTime updatedAt;
  final bool sos;
  const ConvoyDriver({
    required this.userId,
    required this.name,
    this.driverNumber,
    required this.latitude,
    required this.longitude,
    this.speedMph,
    this.heading,
    required this.updatedAt,
    this.sos = false,
  });
}

class ConvoyService {
  ConvoyService._();
  static final instance = ConvoyService._();

  static const _prefKey = 'convoy_sharing';
  static const _table = '/rest/v1/stpg_driver_locations';

  /// Other drivers (and self) with recent positions.
  final ValueNotifier<List<ConvoyDriver>> drivers = ValueNotifier(const []);
  /// Null when sharing works, otherwise a short error (e.g. table missing).
  final ValueNotifier<String?> error = ValueNotifier(null);
  /// User can turn location sharing off.
  final ValueNotifier<bool> sharing = ValueNotifier(true);

  final http.Client _client = http.Client();
  AppState? _app;
  Timer? _shareTimer, _pollTimer;
  bool _sharingBusy = false, _polling = false;
  bool _offlineSent = false;
  bool _listening = false;
  int _gen = 0;

  Future<void> start(AppState app) async {
    await stop();
    _app = app;
    final gen = ++_gen;
    try {
      sharing.value = app.prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
    if (!_listening) {
      sharing.addListener(_onSharingChanged);
      _listening = true;
    }
    _offlineSent = !sharing.value;
    _shareTimer = Timer.periodic(const Duration(seconds: StpgConfig.convoyShareSeconds), (_) {
      if (gen == _gen) _share();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (gen == _gen) _poll();
    });
    unawaited(_share());
    unawaited(_poll());
  }

  Future<void> stop() async {
    _gen++;
    _shareTimer?.cancel();
    _pollTimer?.cancel();
    _shareTimer = null;
    _pollTimer = null;
    if (_listening) {
      sharing.removeListener(_onSharingChanged);
      _listening = false;
    }
    _app = null;
    drivers.value = const [];
    error.value = null;
  }

  void _onSharingChanged() {
    final app = _app;
    if (app == null) return;
    try {
      app.prefs.setBool(_prefKey, sharing.value);
    } catch (_) {}
    if (!sharing.value) {
      if (!_offlineSent) unawaited(_sendOffline());
    } else {
      _offlineSent = false;
      unawaited(_share());
    }
  }

  Future<dynamic> _rest(String method, String path, String token, Object? body,
      {Map<String, String>? extra}) async {
    final req = http.Request(method, Uri.parse('${StpgConfig.supabaseUrl}$path'))
      ..headers.addAll({
        'apikey': StpgConfig.supabasePublishableKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?extra,
      })
      ..body = body == null ? '' : jsonEncode(body);
    final res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 15)));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = SupabaseApi.extractError(res.body);
      final missing = res.statusCode == 404 ||
          res.body.contains('PGRST205') ||
          msg.toLowerCase().contains('does not exist') ||
          msg.toLowerCase().contains('could not find the table');
      throw _ConvoyHttpError(res.statusCode, msg, missing);
    }
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  void _setError(Object e) {
    if (e is _ConvoyHttpError && (e.status == 401 || e.status == 403 || e.message.contains('row-level security'))) {
      error.value = 'CONVOY LOCKED // ACCOUNT NOT APPROVED YET — ASK AN STPG ADMIN';
    } else if (e is _ConvoyHttpError && e.missing) {
      error.value = 'CONVOY TABLE MISSING // RUN SUPABASE MIGRATION 001';
    } else if (e is _ConvoyHttpError) {
      error.value = 'CONVOY OFFLINE // ${e.message}';
    } else {
      error.value = 'CONVOY OFFLINE // ${e is TimeoutException ? 'Request timed out' : e}';
    }
  }

  Future<void> _share() async {
    final app = _app;
    if (app == null || _sharingBusy || !sharing.value || !app.gps.hasFix) return;
    _sharingBusy = true;
    final gen = _gen;
    try {
      final g = app.gps;
      final uid = await app.ensureUserId();
      await app.authed((t) => _rest('POST', '$_table?on_conflict=user_id', t, {
            'user_id': uid,
            'driver_name': app.driverProfile?.fullName,
            'driver_number': app.driverProfile?.driverNumber,
            'latitude': g.latitude,
            'longitude': g.longitude,
            'speed_mph': g.speedMph,
            'heading': g.bearingDegrees,
            'accuracy_ft': g.accuracyFeet,
            'sos': SosService.instance.active.value,
            'sharing': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, extra: {'Prefer': 'resolution=merge-duplicates,return=minimal'}));
      if (gen == _gen) error.value = null;
    } catch (e) {
      if (gen == _gen) _setError(e);
    } finally {
      _sharingBusy = false;
    }
  }

  Future<void> _sendOffline() async {
    final app = _app;
    if (app == null) return;
    _offlineSent = true;
    try {
      final uid = await app.ensureUserId();
      await app.authed((t) => _rest('PATCH', '$_table?user_id=eq.$uid', t, {'sharing': false},
          extra: {'Prefer': 'return=minimal'}));
    } catch (e) {
      _offlineSent = false;
    }
  }

  Future<void> _poll() async {
    final app = _app;
    if (app == null || _polling) return;
    _polling = true;
    final gen = _gen;
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(minutes: 30)).toIso8601String();
      final path =
          '$_table?select=*&updated_at=gte.${Uri.encodeQueryComponent(since)}&order=updated_at.desc';
      final j = await app.authed((t) => _rest('GET', path, t, null));
      if (gen != _gen) return;
      final out = <ConvoyDriver>[];
      if (j is List) {
        for (final e in j) {
          if (e is! Map) continue;
          final lat = (e['latitude'] as num?)?.toDouble();
          final lng = (e['longitude'] as num?)?.toDouble();
          final ts = DateTime.tryParse('${e['updated_at'] ?? ''}');
          if (lat == null || lng == null || ts == null) continue;
          final number = (e['driver_number'] as num?)?.toInt();
          final name = '${e['driver_name'] ?? ''}'.trim();
          out.add(ConvoyDriver(
            userId: '${e['user_id']}',
            name: name.isNotEmpty ? name : 'DRIVER',
            driverNumber: number,
            latitude: lat,
            longitude: lng,
            speedMph: (e['speed_mph'] as num?)?.toInt(),
            heading: (e['heading'] as num?)?.toInt(),
            updatedAt: ts.toLocal(),
            sos: e['sos'] == true,
          ));
        }
      }
      drivers.value = out;
      if (error.value != null && !_sharingBusy) error.value = null;
    } catch (e) {
      if (gen == _gen) _setError(e);
    } finally {
      _polling = false;
    }
  }
}

class _ConvoyHttpError implements Exception {
  final int status;
  final String message;
  final bool missing;
  _ConvoyHttpError(this.status, this.message, this.missing);
  @override
  String toString() => message;
}
