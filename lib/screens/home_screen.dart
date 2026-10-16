import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../dialogs/alert_overlays.dart';
import '../dialogs/driver_profile_dialog.dart';
import '../dialogs/gmrs_dialog.dart';
import '../dialogs/mission_controls_dialog.dart';
import '../dialogs/weather_dialog.dart';
import '../models.dart';
import '../services/gps_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/compass_hud.dart';
import '../widgets/stpg_widgets.dart';

/// Tour targets (index = tour step; 0 has no target).
const _tMission = 1;
const _tDriver = 2;
const _tSystem = 3;
const _tGps = 4;
const _tTheme = 5;
const _tWeather = 6;
const _tGmrs = 7;
const _tNav = 8;
const _tComms = 9;

const _tourSteps = <(String, String)>[
  ('WELCOME TO STPG',
      'Your Raptor Command Center is ready. This guided tour moves with the controls so you can learn the cockpit in place.'),
  ('MISSION STATUS', 'Your current mission state and Driver Portal sync status are shown here.'),
  ('FOUNDING DRIVER', 'Your founding driver number and profile live here. Tap DRIVER PROFILE to view your badge.'),
  ('SYSTEM STATUS', 'GPS, network and command links report their status here.'),
  ('GPS POSITION', 'Your live coordinates and speed update as you drive.'),
  ('THEME CONTROL',
      'This real control also stays visible. It changes the HUD theme without changing the automatic Raptor environment.'),
  ('LIVE WEATHER', 'Weather follows your GPS location. Severe conditions can automatically change the Raptor environment.'),
  ('GMRS CHANNEL', 'The shared STPG radio channel. Set your physical radio to match.'),
  ('NAVIGATION', 'Open maps, trails and field-navigation tools from this command tile.'),
  ('COMMS', 'COMMAND CHANNEL // Receive STPG command updates and open the live Dispatch feed.'),
];

/// Vertical alignment of the tour card (wide layout) per step, kept inside the center column.
const _tourAlignY = <double>[0, -0.25, -0.4, -0.05, 0.25, -0.25, 0.0, 0.2, 0.4, 0.4];

const double _panelOpacity = 0.92;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<GlobalKey> _keys = List<GlobalKey>.generate(10, (_) => GlobalKey());
  int _lastTourStep = -1;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 900;
    final tourOn = app.homeTourStep >= 0;

    if (narrow && app.homeTourStep != _lastTourStep) {
      final step = app.homeTourStep;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || step < 1 || step >= _keys.length) return;
        final ctx = _keys[step].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.15);
        }
      });
    }
    _lastTourStep = app.homeTourStep;

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(app),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
        if (tourOn) IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.4))),
        SafeArea(child: narrow ? _narrowLayout(app, size) : _wideLayout(app)),
        if (tourOn) _tourOverlay(app, size, narrow),
        if (app.assistanceAlert != null)
          AssistanceAlertOverlay(
            request: app.assistanceAlert!,
            onView: () {
              app.go(CommandScreen.assistanceCommand);
              app.dismissAssistanceAlert();
            },
            onDismiss: app.dismissAssistanceAlert,
          ),
        if (app.orderAlert != null)
          StoreOrderAlertOverlay(
            order: app.orderAlert!,
            onView: () {
              app.go(CommandScreen.orders);
              app.dismissOrderAlert();
            },
            onDismiss: app.dismissOrderAlert,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- background

  Widget _background(AppState app) {
    final key = app.environmentKey;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: SizedBox.expand(
        key: ValueKey(key),
        child: Image.asset(
          environmentAsset(key),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => ColoredBox(color: Stpg.black),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tour wrapper

  /// Marks a widget as tour target [target]: dims it when another step is active,
  /// blocks taps while the tour runs (except the theme pills on their own step).
  Widget _t(AppState app, int target, Widget child) {
    final step = app.homeTourStep;
    final keyed = KeyedSubtree(key: _keys[target], child: child);
    if (step < 0) return keyed;
    final isTarget = step == target;
    final interactive = isTarget && target == _tTheme;
    return AbsorbPointer(
      absorbing: !interactive,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isTarget ? 1 : (step == 0 ? 0.7 : 0.4),
        child: keyed,
      ),
    );
  }

  bool _hl(AppState app, int target) => app.homeTourStep == target;

  // ---------------------------------------------------------------- layouts

  Widget _wideLayout(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      child: Column(
        children: [
          _header(app, narrow: false),
          const SizedBox(height: 12),
          _t(app, _tMission, _missionBar(app)),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 316,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      _t(app, _tDriver, _driverCard(app)),
                      const SizedBox(height: 12),
                      _t(app, _tSystem, _systemCard(app)),
                      const SizedBox(height: 12),
                      _t(app, _tGps, _gpsCard(app)),
                    ]),
                  ),
                ),
                Expanded(
                  child: Stack(children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CompassHud(headingDegrees: app.gps.bearingDegrees),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(padding: EdgeInsets.only(bottom: 8), child: _RaptorPill()),
                    ),
                  ]),
                ),
                SizedBox(
                  width: 356,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      _vehicleCard(app),
                      const SizedBox(height: 12),
                      _t(app, _tWeather, _weatherCard(app)),
                      const SizedBox(height: 12),
                      _t(app, _tGmrs, _commsCard(app)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _tilesRow(app),
        ],
      ),
    );
  }

  Widget _narrowLayout(AppState app, Size size) {
    if (size.width < 600) return _phoneLayout(app, size);
    final cols = size.width >= 440 ? 2 : 1;
    final cardWidth = (size.width - 32 - (cols - 1) * 12) / cols;
    Widget sized(Widget c) => SizedBox(width: cardWidth, child: c);

    final tiles = [
      _t(app, _tNav, _navTile(app)),
      _t(app, _tComms, _commsTile(app)),
      _vehicleTile(app),
      _updateTile(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(app, narrow: true),
          const _LocationBar(),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Stack(children: [
              Align(alignment: Alignment.topCenter, child: CompassHud(headingDegrees: app.gps.bearingDegrees)),
              const Align(alignment: Alignment.bottomCenter, child: _RaptorPill()),
            ]),
          ),
          const SizedBox(height: 12),
          _t(app, _tMission, _missionBar(app)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              sized(_t(app, _tDriver, _driverCard(app))),
              sized(_t(app, _tSystem, _systemCard(app))),
              sized(_t(app, _tGps, _gpsCard(app))),
              sized(_vehicleCard(app)),
              sized(_t(app, _tWeather, _weatherCard(app))),
              sized(_t(app, _tGmrs, _commsCard(app))),
            ],
          ),
          const SizedBox(height: 12),
          if (cols == 2) ...[
            Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 12), Expanded(child: tiles[1])]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 12), Expanded(child: tiles[3])]),
          ] else
            for (final t in tiles) ...[t, const SizedBox(height: 12)],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- phone layout

  /// Phone portrait: truck hero, compact 2-column cards, small command buttons.
  Widget _phoneLayout(AppState app, Size size) {
    final gps = app.gps;
    final w = app.weather;
    final ch = app.radio.channel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(app, narrow: true),
        const _LocationBar(),
        SizedBox(
          height: size.height * 0.30,
          child: Stack(children: [
            Align(alignment: Alignment.topCenter, child: CompassHud(headingDegrees: gps.bearingDegrees)),
            const Align(alignment: Alignment.bottomCenter, child: _RaptorPill()),
          ]),
        ),
        const SizedBox(height: 10),
        _t(app, _tMission, _missionBar(app)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _t(app, _tDriver, _mini(app, _tDriver, StpgIcons.driver, 'DRIVER', app.driverNumberText,
                sub: 'PROFILE ›', valueColor: Stpg.orange, onTap: () => showDriverProfileDialog(context))),
            _t(app, _tWeather, _mini(app, _tWeather, weatherIconFor(w, app.isDay), 'WEATHER',
                w?.temperatureF != null ? '${w!.temperatureF}°F' : '--°',
                sub: w == null ? 'LOADING…' : '${w.condition} • ${w.windMph ?? '--'} MPH',
                onTap: () => showWeatherDialog(context))),
            _t(app, _tGps, _mini(app, _tGps, StpgIcons.gps, 'GPS', gps.hasFix ? 'LOCKED' : 'SEARCHING',
                valueColor: gps.hasFix ? Stpg.green : Stpg.orange,
                sub: gps.hasFix
                    ? '${gps.latitude.toStringAsFixed(4)}, ${gps.longitude.toStringAsFixed(4)}'
                    : 'TAP TO ALLOW LOCATION',
                onTap: gps.hasFix ? null : () => GpsService.instance.retry())),
            _t(app, _tGmrs, _mini(app, _tGmrs, StpgIcons.comms, 'GMRS CHANNEL', ch != null ? '$ch' : '--',
                valueColor: Stpg.orange, sub: app.radio.syncLabel, onTap: () => showGmrsDialog(context))),
            _mini(app, -1, StpgIcons.vehicle, 'VEHICLE', app.vehicleName,
                sub: 'MODE NORMAL', onTap: () => app.go(CommandScreen.vehicle)),
            _t(app, _tSystem, _mini(app, _tSystem, StpgIcons.system, 'SYSTEM', 'ONLINE',
                valueColor: Stpg.green, sub: 'NETWORK • COMMAND READY')),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            _t(app, _tNav, _phoneTile(StpgIcons.navigation, 'NAVIGATION', () => app.go(CommandScreen.navigation),
                selected: true, highlighted: _hl(app, _tNav))),
            _t(app, _tComms, _phoneTile(StpgIcons.comms, 'COMMS', () => app.go(CommandScreen.comms),
                highlighted: _hl(app, _tComms),
                badge: app.isAdmin && app.activeAssistance.isNotEmpty ? '${app.activeAssistance.length}' : null)),
            _phoneTile(StpgIcons.vehicle, 'VEHICLE', () => app.go(CommandScreen.vehicle)),
            _phoneTile(StpgIcons.update, 'UPDATE', () async {
              try {
                await launchUrl(Uri.parse(StpgConfig.commandCenterUrl), mode: LaunchMode.externalApplication);
              } catch (_) {}
            }),
          ],
        ),
      ]),
    );
  }

  Widget _mini(AppState app, int target, IconData icon, String label, String value,
      {String? sub, Color? valueColor, VoidCallback? onTap}) {
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: target >= 0 && _hl(app, target),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, size: 15, color: Stpg.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Stpg.label(size: 10, color: Stpg.orange, spacing: 1.4)),
          ),
        ]),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Stpg.title(size: 24, color: valueColor, spacing: 0.8)),
        ),
        if (sub != null)
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 9.5, spacing: 0.8)),
      ]),
    );
  }

  Widget _phoneTile(IconData icon, String title, VoidCallback onTap,
      {bool selected = false, bool highlighted = false, String? badge}) {
    return StpgPanel(
      onTap: onTap,
      highlighted: highlighted || selected,
      color: selected ? Stpg.activePanel : null,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: selected ? Stpg.orange : Stpg.text),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Stpg.title(size: 14, color: selected ? Stpg.orange : Stpg.text, spacing: 1)),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Stpg.red, borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: Stpg.label(size: 10, color: Colors.white, spacing: 0)),
          ),
      ]),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _logo() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'STPG',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
          color: Stpg.orange,
        ),
      ),
      const SizedBox(width: 10),
      Text('SOUTH TEXAS\nPROVING GROUNDS', style: Stpg.label(size: 10, color: Stpg.text, spacing: 1.6)),
    ]);
  }

  Widget _header(AppState app, {required bool narrow}) {
    final title = Text(
      'RAPTOR COMMAND CENTER',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Stpg.title(size: narrow ? 18 : 24, spacing: 2.4),
    );
    final pills = _t(app, _tTheme, _themeControl(app, narrow: narrow));

    return StpgPanel(
      opacity: 0.85,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: 10),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: _logo())),
              const SizedBox(height: 8),
              title,
              const SizedBox(height: 10),
              Center(child: pills),
            ])
          : Row(children: [
              Expanded(
                flex: 3,
                child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: _logo())),
              ),
              Expanded(flex: 4, child: title),
              Expanded(
                flex: 3,
                child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: pills)),
              ),
            ]),
    );
  }

  Widget _themeControl(AppState app, {required bool narrow}) {
    Widget pill(String label, {required VoidCallback onTap, VoidCallback? onLongPress}) {
      final selected = app.themeMode == label;
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Stpg.orange : Stpg.deepPanel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Stpg.orange : Stpg.border, width: 1.4),
          ),
          child: Text(label, style: Stpg.label(size: 12, color: selected ? Colors.white : Stpg.text, spacing: 1.8)),
        ),
      );
    }

    final modeLabel = 'AUTO // BACKGROUNDS · ${app.imageMode}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          pill('DAY', onTap: () => app.setThemeMode('DAY')),
          const SizedBox(width: 8),
          pill('NIGHT', onTap: () => app.setThemeMode('NIGHT')),
          const SizedBox(width: 8),
          pill(
            'AUTO',
            onTap: () {
              app.setThemeMode('AUTO');
              app.setImageMode('SLIDESHOW');
            },
            onLongPress: () {
              app.setThemeMode('AUTO');
              app.setImageMode('WEATHER');
              ScaffoldMessenger.maybeOf(context)
                ?..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Live weather backgrounds enabled')));
            },
          ),
        ]),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => app.setImageMode(app.imageMode == 'WEATHER' ? 'SLIDESHOW' : 'WEATHER'),
          child: Text(modeLabel, style: Stpg.label(size: 10, color: Stpg.gray, spacing: 1.4)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- mission bar

  Widget _missionBar(AppState app) {
    final trip = app.trip;
    final active = trip.active;
    void openMission() => showMissionControlsDialog(context);

    final status = Text.rich(
      TextSpan(children: [
        TextSpan(text: 'MISSION: ', style: Stpg.label(size: 14, color: Stpg.text, spacing: 1.8)),
        TextSpan(text: active ? 'ACTIVE' : 'STANDBY', style: Stpg.label(size: 14, color: Stpg.orange, spacing: 1.8)),
      ]),
    );

    final convoy = InkWell(
      onTap: openMission,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.route, size: 20, color: Stpg.orange),
          const SizedBox(width: 8),
          Flexible(
            child: Text('COASTAL CONVOY',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 15, spacing: 1.6)),
          ),
        ]),
      ),
    );

    final progress = active
        ? Text('${trip.miles.toStringAsFixed(1)} MI • ${missionDuration(trip.elapsedSeconds)}',
            style: Stpg.label(size: 14, color: Stpg.text, spacing: 1.2))
        : null;

    final button = SizedBox(
      width: 220,
      child: StpgButton(
        active ? '■ END MISSION' : '▶ START MISSION',
        filled: true,
        expand: true,
        height: 44,
        onTap: openMission,
      ),
    );

    final divider = Container(width: 1, height: 28, color: Stpg.border);

    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tMission),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 720) {
          return Row(children: [
            status,
            const SizedBox(width: 16),
            divider,
            const SizedBox(width: 16),
            Flexible(child: convoy),
            if (progress != null) ...[const SizedBox(width: 20), Flexible(child: progress)],
            const Spacer(),
            const SizedBox(width: 12),
            button,
          ]);
        }
        return Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [status, convoy, ?progress, button],
        );
      }),
    );
  }

  // ---------------------------------------------------------------- cards

  Widget _driverCard(AppState app) {
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tDriver),
      onTap: () => showDriverProfileDialog(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardHeader(icon: StpgIcons.driver, title: 'FOUNDING DRIVER'),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(app.driverNumberText, style: Stpg.title(size: 54, color: Stpg.orange, spacing: 2)),
        ),
        const SizedBox(height: 4),
        Text('DRIVER PROFILE ›', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
      ]),
    );
  }

  Widget _systemCard(AppState app) {
    final fix = app.gps.hasFix;
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tSystem),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CardHeader(icon: StpgIcons.system, title: 'SYSTEM STATUS'),
        const SizedBox(height: 8),
        StatusLine('GPS', fix ? 'READY' : 'SEARCHING', good: fix ? true : null, size: 14),
        const StatusLine('NETWORK', 'ONLINE', size: 14),
        const StatusLine('COMMAND', 'READY', size: 14),
      ]),
    );
  }

  String _coord(double v, String pos, String neg) => '${v.abs().toStringAsFixed(4)}° ${v >= 0 ? pos : neg}';

  Widget _gpsCard(AppState app) {
    final gps = app.gps;
    final lat = gps.hasFix ? _coord(gps.latitude, 'N', 'S') : '--.----°';
    final lng = gps.hasFix ? _coord(gps.longitude, 'E', 'W') : '--.----°';
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tGps),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CardHeader(icon: StpgIcons.gps, title: 'GPS POSITION'),
        const SizedBox(height: 8),
        Text(lat, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 19, spacing: 1)),
        const SizedBox(height: 2),
        Text(lng, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 19, spacing: 1)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          Text(gps.hasFix ? 'TRACK: LIVE' : 'TRACK: SEARCHING',
              style: Stpg.label(size: 12, color: Stpg.orange, spacing: 1.6)),
          Text('SPD // ${gps.speedMph ?? 0} MPH', style: Stpg.label(size: 12, color: Stpg.text, spacing: 1.6)),
        ]),
      ]),
    );
  }

  Widget _vehicleCard(AppState app) {
    return StpgPanel(
      opacity: _panelOpacity,
      onTap: () => app.go(CommandScreen.vehicle),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CardHeader(icon: StpgIcons.vehicle, title: 'VEHICLE'),
        const SizedBox(height: 8),
        Text(app.vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 20)),
        const SizedBox(height: 6),
        Text('MODE NORMAL', style: Stpg.label(size: 12, color: Stpg.text, spacing: 1.6)),
        const SizedBox(height: 2),
        Text('RANGE —', style: Stpg.label(size: 12, spacing: 1.6)),
      ]),
    );
  }

  Widget _weatherCard(AppState app) {
    final w = app.weather;
    final temp = w?.temperatureF != null ? '${w!.temperatureF}°F' : '--°';
    final condition = w == null ? 'WEATHER OFFLINE' : w.condition;
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tWeather),
      onTap: () => showWeatherDialog(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeader(icon: weatherIconFor(w, app.isDay), title: 'WEATHER'),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(temp, style: Stpg.title(size: 34, spacing: 1)),
        ),
        const SizedBox(height: 2),
        Text(condition,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 13, color: Stpg.orange, spacing: 1.8)),
        const SizedBox(height: 4),
        Text('WIND ${w?.windMph != null ? w!.windMph : '--'} MPH',
            style: Stpg.label(size: 12, color: Stpg.text, spacing: 1.6)),
      ]),
    );
  }

  Widget _commsCard(AppState app) {
    final ch = app.radio.channel;
    return StpgPanel(
      opacity: _panelOpacity,
      highlighted: _hl(app, _tGmrs),
      onTap: () => showGmrsDialog(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CardHeader(icon: StpgIcons.comms, title: 'COMMS'),
        const SizedBox(height: 8),
        Text('GMRS CHANNEL', style: Stpg.label(size: 11, color: Stpg.text, spacing: 1.8)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(ch != null ? '$ch' : '--', style: Stpg.title(size: 42, color: Stpg.orange, spacing: 1)),
        ),
        Text(app.radio.syncLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 10, spacing: 1.4)),
      ]),
    );
  }

  // ---------------------------------------------------------------- tiles

  Widget _navTile(AppState app) => CommandTile(
        icon: StpgIcons.navigation,
        title: 'NAVIGATION',
        subtitle: 'MAPS // TRAILS',
        selected: true,
        highlighted: _hl(app, _tNav),
        onTap: () => app.go(CommandScreen.navigation),
      );

  Widget _commsTile(AppState app) {
    final count = app.isAdmin ? app.activeAssistance.length : 0;
    return CommandTile(
      icon: StpgIcons.comms,
      title: 'COMMS',
      subtitle: 'DISPATCH // DRIVERS',
      highlighted: _hl(app, _tComms),
      badge: count > 0 ? '$count' : null,
      onTap: () => app.go(CommandScreen.comms),
    );
  }

  Widget _vehicleTile(AppState app) => CommandTile(
        icon: StpgIcons.vehicle,
        title: 'VEHICLE',
        subtitle: app.hasAssignedVehicle ? app.vehicleName : 'NO VEHICLE ASSIGNED',
        onTap: () => app.go(CommandScreen.vehicle),
      );

  Widget _updateTile() => CommandTile(
        icon: StpgIcons.update,
        title: 'UPDATE APP',
        subtitle: 'DRIVESTPG.COM',
        onTap: () async {
          try {
            await launchUrl(Uri.parse(StpgConfig.commandCenterUrl), mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
      );

  Widget _tilesRow(AppState app) {
    return Row(children: [
      Expanded(child: _t(app, _tNav, _navTile(app))),
      const SizedBox(width: 12),
      Expanded(child: _t(app, _tComms, _commsTile(app))),
      const SizedBox(width: 12),
      Expanded(child: _vehicleTile(app)),
      const SizedBox(width: 12),
      Expanded(child: _updateTile()),
    ]);
  }

  // ---------------------------------------------------------------- tour card

  Widget _tourOverlay(AppState app, Size size, bool narrow) {
    final step = app.homeTourStep.clamp(0, _tourSteps.length - 1);
    final last = step == _tourSteps.length - 1;
    final (title, body) = _tourSteps[step];

    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Stpg.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Stpg.orange, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${(step + 1).toString().padLeft(2, '0')} / ${_tourSteps.length}',
            style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 6),
        Text(title, style: Stpg.title(size: 20, spacing: 1.4)),
        const SizedBox(height: 8),
        Text(body,
            style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: Stpg.text)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StpgButton('SKIP', color: Stpg.gray, height: 40, onTap: app.endHomeTour),
          if (step > 0) StpgButton('‹ BACK', height: 40, onTap: () => app.setHomeTourStep(step - 1)),
          StpgButton(
            last ? 'CONTINUE TO COMMS ›' : 'NEXT ›',
            filled: true,
            height: 40,
            onTap: () {
              if (last) {
                app.endHomeTour();
                app.go(CommandScreen.comms);
              } else {
                app.setHomeTourStep(step + 1);
              }
            },
          ),
        ]),
      ]),
    );

    if (narrow) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: card),
          ),
        ),
      );
    }

    final width = (size.width - 744).clamp(320.0, 420.0);
    return SafeArea(
      child: Align(
        alignment: Alignment(0, _tourAlignY[step]),
        child: Padding(
          // Shift left 20 px so the card sits in the center column between the side panels.
          padding: const EdgeInsets.only(right: 40, top: 8, bottom: 8),
          child: SizedBox(width: width, child: card),
        ),
      ),
    );
  }
}

/// "STPG RAPTOR • 2025" tag near the bottom of the center area.
class _RaptorPill extends StatelessWidget {
  const _RaptorPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Stpg.orange, width: 1.2),
      ),
      child: Text('STPG RAPTOR • 2025', style: Stpg.label(size: 12, color: Colors.white, spacing: 2.2)),
    );
  }
}

/// Shown when location is blocked: tap to ask the browser/phone again.
class _LocationBar extends StatelessWidget {
  const _LocationBar();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: GpsService.instance.error,
      builder: (context, err, _) {
        if (err == null || app.gps.hasFix) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: StpgPanel(
            onTap: () => GpsService.instance.retry(),
            borderColor: Stpg.orange,
            color: Stpg.activePanel,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.location_off, color: Stpg.orange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('LOCATION OFF — TAP TO ALLOW', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 1.2)),
              ),
            ]),
          ),
        );
      },
    );
  }
}
