import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';

class SupabaseException implements Exception {
  final int? statusCode;
  final String message;
  SupabaseException(this.message, [this.statusCode]);
  @override
  String toString() => statusCode != null ? 'HTTP $statusCode // $message' : message;
}

/// Thin REST client for the STPG Supabase project (mirrors the original OkHttp calls).
class SupabaseApi {
  static const _base = StpgConfig.supabaseUrl;
  static final http.Client _client = http.Client();

  static Map<String, String> _headers([String? token, Map<String, String>? extra]) => {
        'apikey': StpgConfig.supabasePublishableKey,
        'Authorization': 'Bearer ${token ?? StpgConfig.supabasePublishableKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?extra,
      };

  static String extractError(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        for (final k in ['msg', 'message', 'error_description', 'error']) {
          final v = j[k];
          if (v is String && v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return body.isEmpty ? 'Supabase request failed' : body;
  }

  static dynamic _check(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw SupabaseException(extractError(r.body), r.statusCode);
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  static Future<dynamic> _get(String path, String token) async =>
      _check(await _client.get(Uri.parse('$_base$path'), headers: _headers(token)));

  static Future<dynamic> _send(String method, String path, String? token, Object? body,
      {Map<String, String>? extra}) async {
    final req = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll(_headers(token, extra))
      ..body = body == null ? '' : jsonEncode(body);
    final res = await http.Response.fromStream(await _client.send(req));
    return _check(res);
  }

  /// Generic PostgREST call (throws [SupabaseException], so `app.authed` can refresh on 401).
  static Future<dynamic> rest(String method, String path, String token, [Object? body, Map<String, String>? extra]) =>
      method == 'GET' ? _get(path, token) : _send(method, path, token, body, extra: extra);

  // ---------- Auth ----------
  static StpgSession _parseSession(dynamic j) {
    if (j is! Map) throw SupabaseException('LOGIN FAILED // Invalid server response');
    final access = j['access_token'] as String?;
    final refresh = j['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw SupabaseException('LOGIN FAILED // Session token missing');
    }
    return StpgSession(access, refresh);
  }

  static Future<StpgSession> signIn(String email, String password) async => _parseSession(
      await _send('POST', '/auth/v1/token?grant_type=password', null, {'email': email, 'password': password}));

  static Future<StpgSession> refresh(String refreshToken) async => _parseSession(await _send(
      'POST', '/auth/v1/token?grant_type=refresh_token', null, {'refresh_token': refreshToken}));

  static Future<String> currentUserId(String token) async {
    final j = await _get('/auth/v1/user', token);
    final id = (j is Map) ? j['id'] as String? : null;
    if (id == null || id.isEmpty) throw SupabaseException('AUTH ERROR // Driver ID missing');
    return id;
  }

  // ---------- Dispatch ----------
  static Future<List<StpgDispatch>> fetchDispatches(String token) async {
    final j = await _get(
        '/rest/v1/stpg_dispatches?select=id,subject,message,recipient_type,created_at&order=created_at.desc',
        token);
    return (j as List).map((e) => StpgDispatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createAdminDispatch(String token, String subject, String message) async {
    await _send('POST', '/rest/v1/stpg_dispatches', token,
        {'subject': subject, 'message': message, 'recipient_type': 'all'});
  }

  static Future<bool> isStpgAdmin(String token) async {
    final j = await _send('POST', '/rest/v1/rpc/is_stpg_admin', token, <String, dynamic>{});
    return j == true;
  }

  // ---------- Missions ----------
  static Future<StpgMission?> fetchActiveMission(String token) async {
    final j = await _get(
        '/rest/v1/stpg_missions?select=id,title,instructions,deadline,status&status=eq.ACTIVE&order=updated_at.desc&limit=1',
        token);
    final list = j as List;
    return list.isEmpty ? null : StpgMission.fromJson(list.first as Map<String, dynamic>);
  }

  static Future<StpgMissionInteraction?> fetchMissionInteraction(
      String token, String missionId, String userId) async {
    final j = await _get(
        '/rest/v1/stpg_mission_interactions?select=first_viewed_at,completed_at&mission_id=eq.$missionId&user_id=eq.$userId',
        token);
    final list = j as List;
    return list.isEmpty ? null : StpgMissionInteraction.fromJson(list.first as Map<String, dynamic>);
  }

  static Future<void> markMissionViewed(String token, String missionId, String userId) async {
    await _send('POST', '/rest/v1/stpg_mission_interactions?on_conflict=mission_id,user_id', token,
        {'mission_id': missionId, 'user_id': userId, 'first_viewed_at': utcNow()},
        extra: {'Prefer': 'resolution=ignore-duplicates,return=minimal'});
  }

  static Future<void> completeMissionInteraction(String token, String missionId, String userId) async {
    final existing = await fetchMissionInteraction(token, missionId, userId);
    if (existing == null) {
      await _send('POST', '/rest/v1/stpg_mission_interactions', token, {
        'mission_id': missionId,
        'user_id': userId,
        'first_viewed_at': utcNow(),
        'completed_at': utcNow(),
      });
    } else {
      await _send('PATCH', '/rest/v1/stpg_mission_interactions?mission_id=eq.$missionId&user_id=eq.$userId',
          token, {'completed_at': utcNow()});
    }
  }

  // ---------- Assistance ----------
  static const _assistSelect =
      'select=id,user_id,request_type,message,latitude,longitude,status,created_at';

  static Future<StpgAssistanceRequest?> fetchActiveAssistanceRequest(String token, String userId) async {
    final j = await _get(
        '/rest/v1/stpg_assistance_requests?$_assistSelect&user_id=eq.$userId&status=eq.ACTIVE&order=created_at.desc&limit=1',
        token);
    final list = j as List;
    return list.isEmpty ? null : StpgAssistanceRequest.fromJson(list.first as Map<String, dynamic>);
  }

  static Future<List<StpgAssistanceRequest>> fetchAllActiveAssistanceRequests(String token) async {
    final j = await _get(
        '/rest/v1/stpg_assistance_requests?$_assistSelect&status=eq.ACTIVE&order=created_at.desc', token);
    return (j as List).map((e) => StpgAssistanceRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createAssistanceRequest(String token, String userId, String requestType,
      String message, double lat, double lng) async {
    await _send('POST', '/rest/v1/stpg_assistance_requests', token, {
      'user_id': userId,
      'request_type': requestType,
      'message': message,
      'latitude': lat,
      'longitude': lng,
      'status': 'ACTIVE',
    });
  }

  static Future<void> cancelAssistanceRequest(String token, String requestId) async {
    await _send('PATCH', '/rest/v1/stpg_assistance_requests?id=eq.$requestId', token, {'status': 'CANCELLED'});
  }

  static Future<void> resolveAssistanceRequest(String token, String requestId) async {
    await _send('PATCH', '/rest/v1/stpg_assistance_requests?id=eq.$requestId', token, {'status': 'RESOLVED'});
  }

  // ---------- Store orders (admin) ----------
  static Future<List<StpgStoreOrder>> fetchRecentStoreOrders(String token, {int limit = 25}) async {
    final j = await _get('/rest/v1/store_orders?select=*&order=created_at.desc&limit=$limit', token);
    return (j as List).map((e) => StpgStoreOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------- Driver profile ----------
  static Future<DriverCommandProfile?> fetchDriverProfile(String token) async {
    final userId = await currentUserId(token);
    final j = await _get(
        '/rest/v1/founding_drivers?select=user_id,full_name,driver_number,vehicle&user_id=eq.$userId', token);
    final list = j as List;
    String? badge;
    try {
      final b = await _get('/rest/v1/driver_badge_media?select=badge_photo_path&user_id=eq.$userId', token);
      if (b is List && b.isNotEmpty) badge = (b.first as Map)['badge_photo_path'] as String?;
    } catch (_) {}
    if (list.isEmpty) {
      return DriverCommandProfile(userId: userId, fullName: '', vehicle: '', badgePhotoPath: badge);
    }
    final m = list.first as Map<String, dynamic>;
    return DriverCommandProfile(
      userId: userId,
      fullName: '${m['full_name'] ?? ''}',
      vehicle: '${m['vehicle'] ?? ''}',
      driverNumber: (m['driver_number'] as num?)?.toInt(),
      badgePhotoPath: badge,
    );
  }

  static Future<Uint8List?> fetchPrivateBadgePhoto(String token, String path) async {
    final j = await _send('POST', '/storage/v1/object/sign/driver-badge-photos/$path', token, {'expiresIn': 3600});
    final signed = (j is Map) ? (j['signedURL'] ?? j['signedUrl']) as String? : null;
    if (signed == null) return null;
    final url = signed.startsWith('http') ? signed : '$_base/storage/v1$signed';
    final r = await _client.get(Uri.parse(url));
    return r.statusCode == 200 ? r.bodyBytes : null;
  }

  // ---------- GMRS radio ----------
  static Future<int?> fetchSharedGmrsChannel(String token) async {
    final j = await _get('/rest/v1/stpg_radio_settings?id=eq.global&select=channel&limit=1', token);
    final list = j as List;
    if (list.isEmpty) throw SupabaseException('Shared radio setup is missing. Run the supplied Supabase SQL migration.');
    return ((list.first as Map)['channel'] as num?)?.toInt();
  }

  static Future<int> updateSharedGmrsChannel(String token, int channel) async {
    final j = await _send('PATCH', '/rest/v1/stpg_radio_settings?id=eq.global&select=channel', token,
        {'channel': channel},
        extra: {'Prefer': 'return=representation'});
    if (j is! List || j.isEmpty) {
      throw SupabaseException('The server did not confirm this channel. Check admin access and database setup.');
    }
    return ((j.first as Map)['channel'] as num).toInt();
  }

  static String utcNow() => DateTime.now().toUtc().toIso8601String();
}
