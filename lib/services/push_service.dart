import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../api/supabase_api.dart';
import '../config.dart';
import '../state/app_state.dart';

/// Background isolate handler. Notification messages are shown by the OS; nothing to do.
@pragma('vm:entry-point')
Future<void> _bg(RemoteMessage message) async {}

class PushService {
  PushService._();
  static final instance = PushService._();

  /// False when Firebase config files are missing (app then works without push).
  static bool configured = false;

  static const _channelId = 'stpg_alerts';
  static const _channelName = 'STPG Alerts';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _listening = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;

  /// Called in main() before runApp. Must never throw (Firebase may be unconfigured).
  static Future<void> initFirebase() async {
    if (kIsWeb) return;
    try {
      final opts = StpgConfig.firebaseOptions;
      // Options come from build settings (see docs/SETUP.md); without them we fall back
      // to google-services.json / GoogleService-Info.plist if those files are present.
      opts != null ? await Firebase.initializeApp(options: opts) : await Firebase.initializeApp();
      configured = true;
      FirebaseMessaging.onBackgroundMessage(_bg);
    } catch (_) {
      configured = false;
    }
  }

  /// After login: request permission, register this device token with Supabase, listen for messages.
  Future<void> init(AppState app) async {
    if (kIsWeb || !configured) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ));

      // iOS: show system banner while foregrounded too would duplicate our local one; keep it off.
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

      final token = await fm.getToken();
      if (token != null) {
        _token = token;
        await _upsert(app, token);
      }

      if (!_listening) {
        _listening = true;
        _refreshSub = fm.onTokenRefresh.listen((t) {
          _token = t;
          unawaited(_upsert(app, t));
        }, onError: (_) {});
        _fgSub = FirebaseMessaging.onMessage.listen(_showForeground, onError: (_) {});
        _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => _navigate(app, m), onError: (_) {});
      }

      final initial = await fm.getInitialMessage();
      if (initial != null) _navigate(app, initial);
    } catch (_) {
      // Never throw: push is optional.
    }
  }

  /// On sign out: remove this device token.
  Future<void> unregister(AppState app) async {
    try {
      await _refreshSub?.cancel();
      await _fgSub?.cancel();
      await _openSub?.cancel();
      _refreshSub = _fgSub = _openSub = null;
      _listening = false;
      if (kIsWeb || !configured) return;
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await app.authed((t) async {
        final res = await http.delete(
          Uri.parse('${StpgConfig.supabaseUrl}/rest/v1/stpg_push_tokens?token=eq.${Uri.encodeQueryComponent(token)}'),
          headers: _headers(t),
        );
        if (res.statusCode == 401) throw SupabaseException('Unauthorized', 401);
        return null;
      });
    } catch (_) {}
    _token = null;
  }

  // ---------------------------------------------------------------------------

  Map<String, String> _headers(String token, {bool json = false}) => {
        'apikey': StpgConfig.supabasePublishableKey,
        'Authorization': 'Bearer $token',
        if (json) 'Content-Type': 'application/json',
      };

  Future<void> _upsert(AppState app, String token) async {
    try {
      final userId = await app.ensureUserId();
      final body = jsonEncode({
        'token': token,
        'user_id': userId,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await app.authed((t) async {
        final res = await http.post(
          Uri.parse('${StpgConfig.supabaseUrl}/rest/v1/stpg_push_tokens?on_conflict=token'),
          headers: {
            ..._headers(t, json: true),
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: body,
        );
        if (res.statusCode == 401) throw SupabaseException('Unauthorized', 401);
        return null;
      });
    } catch (_) {}
  }

  Future<void> _showForeground(RemoteMessage m) async {
    try {
      final n = m.notification;
      if (n == null) return;
      await _local.show(
        id: m.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (_) {}
  }

  void _navigate(AppState app, RemoteMessage m) {
    try {
      final target = switch ('${m.data['screen'] ?? ''}') {
        'dispatch' => CommandScreen.dispatch,
        'missions' => CommandScreen.missions,
        'assistance' => CommandScreen.assistanceCommand,
        'orders' => CommandScreen.orders,
        'convoy' => CommandScreen.convoy,
        _ => null,
      };
      if (target != null) app.go(target);
    } catch (_) {}
  }
}
