import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/supabase_api.dart';
import '../api/weather_api.dart';
import '../config.dart';
import '../models.dart';
import '../services/gps_service.dart';
import '../services/hazard_service.dart';
import '../services/heading_service.dart';
import '../services/session_store.dart';
import '../services/route_guidance.dart';
import '../services/voice_service.dart';
import '../services/convoy_service.dart';
import '../services/mission_tracker.dart';
import '../services/push_service.dart';
import '../services/sos_service.dart';
import '../theme.dart';

enum CommandScreen { home, navigation, comms, dispatch, missions, assistanceCommand, fieldAssistance, orders, vehicle, convoy, trips, drive }

enum AuthStage { booting, checking, loggedOut, loggedIn }

/// The 13 Raptor environments (background images).
const raptorEnvironments = [
  'DAY', 'SUNRISE', 'SUNSET', 'NIGHT', 'CLOUDY', 'FOG', 'RAIN', 'HEAVY_RAIN', 'THUNDER', 'DUST', 'COLD_DRY', 'SNOW', 'EXTREME_HEAT',
];

String environmentAsset(String key) {
  const files = {
    'DAY': 'day', 'SUNRISE': 'sunrise', 'SUNSET': 'sunset', 'NIGHT': 'night', 'CLOUDY': 'cloudy', 'FOG': 'fog',
    'RAIN': 'rain', 'HEAVY_RAIN': 'heavy_rain', 'THUNDER': 'thunder', 'DUST': 'dust', 'COLD_DRY': 'cold',
    'SNOW': 'freezing', 'EXTREME_HEAT': 'extreme_heat',
  };
  return 'assets/images/stpg_weather_${files[key] ?? 'day'}.webp';
}

/// Single app-wide state object. Screens read it through [AppScope.of].
class AppState extends ChangeNotifier {
  static const _kTheme = 'theme_mode';
  static const _kImageMode = 'image_mode';
  static const _kImageIndex = 'image_index';
  static const kHomeTourDone = 'home_tour_completed_v3';
  static const kCommsTourDone = 'comms_tour_completed_v1';

  late SharedPreferences prefs;
  late SessionStore _sessions;
  Future<StpgSession>? _refreshing;

  // ---------- Auth ----------
  AuthStage stage = AuthStage.booting;
  StpgSession? session;
  String? userId;
  bool isAdmin = false;
  DriverCommandProfile? driverProfile;
  Uint8List? badgePhoto;

  String get token => session?.accessToken ?? '';
  String get driverNumberText =>
      driverProfile?.driverNumber != null ? driverProfile!.driverNumber!.toString().padLeft(3, '0') : '---';

  /// Vehicle name with the original app's "null" bug fixed.
  String get vehicleName {
    final v = driverProfile?.vehicle.trim() ?? '';
    return (v.isEmpty || v.toLowerCase() == 'null') ? '2025 RAPTOR' : v.toUpperCase();
  }

  bool get hasAssignedVehicle {
    final v = driverProfile?.vehicle.trim() ?? '';
    return v.isNotEmpty && v.toLowerCase() != 'null';
  }

  // ---------- Navigation ----------
  CommandScreen screen = CommandScreen.home;
  final List<CommandScreen> _history = [];

  void go(CommandScreen s) {
    if (s == screen) return;
    if (s == CommandScreen.home) {
      _history.clear();
    } else {
      _history.add(screen);
    }
    screen = s;
    notifyListeners();
  }

  /// Back one screen (fixes the original app exiting on Android back). Returns false at Home.
  bool back() {
    if (screen == CommandScreen.home) return false;
    screen = _history.isNotEmpty ? _history.removeLast() : CommandScreen.home;
    notifyListeners();
    return true;
  }

  // ---------- Theme & backgrounds ----------
  String themeMode = 'AUTO'; // DAY / NIGHT / AUTO
  String imageMode = 'WEATHER'; // WEATHER / SLIDESHOW
  int slideshowIndex = 0;
  Timer? _slideshowTimer;
  Timer? _clockTimer;

  bool get isDay {
    if (themeMode == 'DAY') return true;
    if (themeMode == 'NIGHT') return false;
    final phase = WeatherApi.solarPhase(weather?.sunriseLocal, weather?.sunsetLocal);
    return phase != 'NIGHT';
  }

  void setThemeMode(String mode) {
    themeMode = mode;
    prefs.setString(_kTheme, mode);
    _applyDay();
    notifyListeners();
  }

  /// Tap AUTO → slideshow; hold AUTO → live weather (same gestures as the original).
  void setImageMode(String mode) {
    imageMode = mode;
    prefs.setString(_kImageMode, mode);
    _restartSlideshow();
    notifyListeners();
  }

  void _restartSlideshow() {
    _slideshowTimer?.cancel();
    if (imageMode != 'SLIDESHOW') return;
    _slideshowTimer = Timer.periodic(const Duration(milliseconds: StpgConfig.imageIntervalMs), (_) {
      slideshowIndex = (slideshowIndex + 1) % raptorEnvironments.length;
      prefs.setInt(_kImageIndex, slideshowIndex);
      notifyListeners();
    });
  }

  void _applyDay() => Stpg.day = isDay;

  /// Background environment key for the home screen.
  String get environmentKey {
    if (imageMode == 'SLIDESHOW') return raptorEnvironments[slideshowIndex % raptorEnvironments.length];
    final w = weather;
    final phase = WeatherApi.solarPhase(w?.sunriseLocal, w?.sunsetLocal);
    if (w == null) return phase;
    final c = w.weatherCode ?? -1;
    final t = w.temperatureF;
    if (c >= 95) return 'THUNDER';
    if ([65, 67, 82].contains(c)) return 'HEAVY_RAIN';
    if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return 'RAIN';
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return 'SNOW';
    if (c == 45 || c == 48) return 'FOG';
    if (t != null && t >= 100) return 'EXTREME_HEAT';
    if ((w.windMph ?? 0) >= 30) return 'DUST';
    if (t != null && t <= 40) return 'COLD_DRY';
    if (c == 3 && phase == 'DAY') return 'CLOUDY';
    return phase;
  }

  // ---------- GPS & weather ----------
  LiveGps gps = const LiveGps();
  MissionWeather? weather;
  String? weatherError;
  DateTime? _weatherAt;

  bool _hadFix = false;

  void _onGps() {
    gps = GpsService.instance.live.value;
    if (gps.hasFix && !_hadFix) {
      _hadFix = true;
      _weatherAt = null; // refresh for the real position on first fix
    }
    if (gps.hasFix && (_weatherAt == null || DateTime.now().difference(_weatherAt!) > const Duration(minutes: 10))) {
      refreshWeather();
    }
    notifyListeners();
  }

  /// Weather for the GPS position, or for San Antonio until the first fix.
  Future<void> refreshWeather() async {
    _weatherAt = DateTime.now();
    final lat = gps.hasFix ? gps.latitude : 29.4252;
    final lng = gps.hasFix ? gps.longitude : -98.4946;
    try {
      weather = await WeatherApi.fetch(lat, lng);
      weatherError = null;
    } catch (e) {
      weatherError = 'WEATHER OFFLINE';
    }
    _applyDay();
    notifyListeners();
  }

  // ---------- GMRS radio ----------
  GmrsChannelState radio = const GmrsChannelState();
  Timer? _radioTimer;

  Future<void> _pollRadio() async {
    if (session == null || radio.saving) return;
    try {
      final ch = await _authed((t) => SupabaseApi.fetchSharedGmrsChannel(t));
      radio = GmrsChannelState(channel: ch, loaded: true);
    } catch (e) {
      radio = radio.copyWith(syncError: e.toString());
    }
    notifyListeners();
  }

  /// Admin only. Returns null on success or an error message.
  Future<String?> saveRadioChannel(int channel) async {
    radio = radio.copyWith(saving: true, clearSaveError: true, clearNotice: true);
    notifyListeners();
    try {
      final ch = await _authed((t) => SupabaseApi.updateSharedGmrsChannel(t, channel));
      radio = GmrsChannelState(channel: ch, loaded: true, notice: 'Saved. Connected tablets refresh within about 5 seconds.');
      notifyListeners();
      return null;
    } catch (e) {
      radio = radio.copyWith(saving: false, saveError: e.toString());
      notifyListeners();
      return e.toString();
    }
  }

  // ---------- Admin alerts ----------
  List<StpgAssistanceRequest> activeAssistance = [];
  StpgAssistanceRequest? assistanceAlert;
  StpgStoreOrder? orderAlert;
  final Set<String> _seenAssistance = {};
  final Set<String> _seenOrders = {};
  bool _alertsPrimed = false;
  Timer? _alertTimer;

  Future<void> _pollAlerts() async {
    if (session == null || !isAdmin) return;
    try {
      final reqs = await _authed((t) => SupabaseApi.fetchAllActiveAssistanceRequests(t));
      activeAssistance = reqs;
      for (final r in reqs) {
        if (_seenAssistance.add(r.id) && _alertsPrimed) assistanceAlert = r;
      }
    } catch (_) {}
    try {
      final orders = await _authed((t) => SupabaseApi.fetchRecentStoreOrders(t, limit: 10));
      for (final o in orders) {
        if (_seenOrders.add(o.id) && _alertsPrimed) orderAlert = o;
      }
    } catch (_) {}
    _alertsPrimed = true;
    notifyListeners();
  }

  void dismissAssistanceAlert() {
    assistanceAlert = null;
    notifyListeners();
  }

  void dismissOrderAlert() {
    orderAlert = null;
    notifyListeners();
  }

  // ---------- Mission trip ----------
  MissionTripState get trip => MissionTracker.instance.state.value;

  // ---------- Tours ----------
  int homeTourStep = -1; // -1 = hidden
  void startHomeTour() {
    homeTourStep = 0;
    go(CommandScreen.home);
    notifyListeners();
  }

  void setHomeTourStep(int step) {
    homeTourStep = step;
    notifyListeners();
  }

  void endHomeTour() {
    homeTourStep = -1;
    prefs.setBool(kHomeTourDone, true);
    notifyListeners();
  }

  // ---------- Lifecycle ----------
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    _sessions = SessionStore(prefs);
    themeMode = prefs.getString(_kTheme) ?? 'AUTO';
    imageMode = prefs.getString(_kImageMode) ?? 'WEATHER';
    slideshowIndex = prefs.getInt(_kImageIndex) ?? 0;
    _applyDay();
    _restartSlideshow();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _applyDay();
      notifyListeners();
    });

    GpsService.instance.live.addListener(_onGps);
    MissionTracker.instance.state.addListener(notifyListeners);
    unawaited(MissionTracker.instance.restore());
  }

  /// Called by the boot screen when its animation finishes.
  Future<void> finishBoot() async {
    stage = AuthStage.checking;
    notifyListeners();
    final (access, refresh) = await _sessions.read();
    if (access != null && refresh != null) {
      try {
        final s = await SupabaseApi.refresh(refresh);
        await _onSignedIn(s);
        return;
      } catch (_) {
        await _clearSession();
      }
    }
    stage = AuthStage.loggedOut;
    notifyListeners();
  }

  /// Returns null on success or an error message for the login screen.
  Future<String?> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return 'ENTER YOUR DRIVER EMAIL AND PASSWORD';
    try {
      final s = await SupabaseApi.signIn(email.trim(), password);
      await _onSignedIn(s);
      return null;
    } on SupabaseException catch (e) {
      return e.message;
    } catch (e) {
      return 'NETWORK ERROR // $e';
    }
  }

  Future<void> _onSignedIn(StpgSession s) async {
    session = s;
    await _sessions.write(s.accessToken, s.refreshToken);
    stage = AuthStage.loggedIn;
    screen = CommandScreen.home;
    notifyListeners();
    unawaited(GpsService.instance.start());
    HeadingService.instance.start();
    RouteGuidance.instance.start();
    unawaited(VoiceService.instance.init());
    HazardService.instance.start(this);
    unawaited(refreshWeather());
    unawaited(_loadProfile());
    unawaited(_pollRadio());
    _radioTimer?.cancel();
    _radioTimer = Timer.periodic(const Duration(seconds: StpgConfig.radioPollSeconds), (_) => _pollRadio());
    try {
      isAdmin = await _authed((t) => SupabaseApi.isStpgAdmin(t));
    } catch (_) {
      isAdmin = false;
    }
    notifyListeners();
    if (isAdmin) {
      unawaited(_pollAlerts());
      _alertTimer?.cancel();
      _alertTimer = Timer.periodic(const Duration(seconds: StpgConfig.alertPollSeconds), (_) => _pollAlerts());
    }
    unawaited(ConvoyService.instance.start(this));
    unawaited(PushService.instance.init(this));
    unawaited(SosService.instance.restore(this));
    if (!(prefs.getBool(kHomeTourDone) ?? false)) {
      homeTourStep = 0;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    try {
      driverProfile = await _authed((t) => SupabaseApi.fetchDriverProfile(t));
      userId = driverProfile?.userId;
      notifyListeners();
      final path = driverProfile?.badgePhotoPath;
      if (path != null && path.isNotEmpty) {
        badgePhoto = await _authed((t) => SupabaseApi.fetchPrivateBadgePhoto(t, path));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String> ensureUserId() async {
    if (userId != null) return userId!;
    userId = await _authed((t) => SupabaseApi.currentUserId(t));
    return userId!;
  }

  Future<void> signOut() async {
    await ConvoyService.instance.stop();
    HazardService.instance.stop();
    RouteGuidance.instance.clear();
    await PushService.instance.unregister(this);
    _radioTimer?.cancel();
    _alertTimer?.cancel();
    await _clearSession();
    session = null;
    userId = null;
    isAdmin = false;
    driverProfile = null;
    badgePhoto = null;
    radio = const GmrsChannelState();
    _history.clear();
    screen = CommandScreen.home;
    stage = AuthStage.loggedOut;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await _sessions.clear();
  }

  /// Runs an authenticated call; on 401 (expired JWT) refreshes the session once and retries.
  Future<T> _authed<T>(Future<T> Function(String token) call) async {
    try {
      return await call(token);
    } on SupabaseException catch (e) {
      if (e.statusCode != 401 || session == null) rethrow;
      // Several pollers can hit an expired token at once; refresh only once
      // (refresh tokens are single-use, a second refresh would sign the driver out).
      final pending = _refreshing ??= _refreshSession(session!.refreshToken);
      try {
        final s = await pending;
        return call(s.accessToken);
      } finally {
        if (identical(_refreshing, pending)) _refreshing = null;
      }
    }
  }

  Future<StpgSession> _refreshSession(String refreshToken) async {
    final s = await SupabaseApi.refresh(refreshToken);
    session = s;
    await _sessions.write(s.accessToken, s.refreshToken);
    return s;
  }

  /// Public wrapper so screens get automatic token refresh too.
  Future<T> authed<T>(Future<T> Function(String token) call) => _authed(call);

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _clockTimer?.cancel();
    _radioTimer?.cancel();
    _alertTimer?.cancel();
    GpsService.instance.live.removeListener(_onGps);
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (use inside callbacks).
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
