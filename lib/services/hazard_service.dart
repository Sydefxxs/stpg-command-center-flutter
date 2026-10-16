import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/supabase_api.dart';
import '../state/app_state.dart';

class Hazard {
  final String id, userId, kind;
  final String? note, driverName;
  final double latitude, longitude;
  final DateTime createdAt;
  const Hazard({
    required this.id,
    required this.userId,
    required this.kind,
    this.note,
    this.driverName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });
}

/// Shared hazard pins (table `stpg_hazards`, migration 003). Pins expire after 12 hours.
class HazardService {
  HazardService._();
  static final instance = HazardService._();

  static const kinds = ['WASHOUT', 'DEEP SAND', 'MUD', 'ROCKS', 'WATER CROSSING', 'LIVESTOCK', 'DEBRIS', 'POLICE', 'OTHER'];
  static const _table = '/rest/v1/stpg_hazards';

  final ValueNotifier<List<Hazard>> hazards = ValueNotifier(const []);
  final ValueNotifier<String?> error = ValueNotifier(null);
  AppState? _app;
  Timer? _timer;
  bool _busy = false;

  void start(AppState app) {
    _app = app;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _app = null;
    hazards.value = const [];
  }

  String _describe(Object e) {
    final s = '$e';
    if (s.contains('PGRST205') || s.toLowerCase().contains('stpg_hazards')) {
      return 'HAZARD TABLE MISSING // RUN SUPABASE MIGRATION 003';
    }
    return 'HAZARDS OFFLINE';
  }

  Future<void> refresh() async {
    final app = _app;
    if (app == null || _busy) return;
    _busy = true;
    try {
      final now = Uri.encodeQueryComponent(DateTime.now().toUtc().toIso8601String());
      final j = await app.authed((t) =>
          SupabaseApi.rest('GET', '$_table?select=*&expires_at=gt.$now&order=created_at.desc&limit=200', t));
      final out = <Hazard>[];
      if (j is List) {
        for (final e in j) {
          if (e is! Map) continue;
          final lat = (e['latitude'] as num?)?.toDouble();
          final lng = (e['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          out.add(Hazard(
            id: '${e['id']}',
            userId: '${e['user_id']}',
            kind: '${e['kind'] ?? 'OTHER'}',
            note: e['note'] as String?,
            driverName: e['driver_name'] as String?,
            latitude: lat,
            longitude: lng,
            createdAt: DateTime.tryParse('${e['created_at']}')?.toLocal() ?? DateTime.now(),
          ));
        }
      }
      hazards.value = out;
      error.value = null;
    } catch (e) {
      error.value = _describe(e);
    } finally {
      _busy = false;
    }
  }

  /// Drops a pin at the driver's current position. Returns an error message, or null on success.
  Future<String?> drop(String kind, {String? note}) async {
    final app = _app;
    if (app == null) return 'NOT SIGNED IN';
    final g = app.gps;
    if (!g.hasFix) return 'NO GPS FIX YET';
    try {
      await app.authed((t) => SupabaseApi.rest('POST', _table, t, {
            'kind': kind,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            'latitude': g.latitude,
            'longitude': g.longitude,
            'driver_name': app.driverProfile?.fullName,
          }, {'Prefer': 'return=minimal'}));
      await refresh();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  Future<String?> remove(String id) async {
    final app = _app;
    if (app == null) return 'NOT SIGNED IN';
    try {
      await app.authed((t) => SupabaseApi.rest('DELETE', '$_table?id=eq.$id', t, null, {'Prefer': 'return=minimal'}));
      await refresh();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }
}
