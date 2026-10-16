import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/weather_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// Sun / moon / cloud / rain icon for the current conditions.
IconData weatherIconFor(MissionWeather? w, bool day) {
  if (w == null) return Icons.cloud_off_outlined;
  final c = w.weatherCode ?? -1;
  if (c >= 95) return Icons.thunderstorm_outlined;
  if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return Icons.water_drop_outlined;
  if ((c >= 71 && c <= 77) || c == 85 || c == 86) return Icons.ac_unit;
  if (c == 45 || c == 48 || c == 3) return Icons.cloud_outlined;
  if (c == 2) return day ? Icons.wb_cloudy_outlined : Icons.cloud_outlined;
  return day ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
}

/// "STPG LIVE WEATHER // DETAILS" modal.
Future<void> showWeatherDialog(BuildContext context) {
  return showStpgDialog<void>(
    context,
    maxWidth: 480,
    builder: (ctx) {
      final app = AppScope.of(ctx);
      final w = app.weather;
      final gps = app.gps;
      final temp = w?.temperatureF != null ? '${w!.temperatureF}°F' : '--°';
      final condition = w == null ? 'WEATHER OFFLINE' : w.condition;
      final location = gps.hasFix
          ? '${gps.latitude.toStringAsFixed(4)}, ${gps.longitude.toStringAsFixed(4)}'
          : '--';

      Widget row(String label, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(label, style: Stpg.label(size: 12, spacing: 1.8))),
              const SizedBox(width: 12),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Stpg.title(size: 15, spacing: 1)),
              ),
            ]),
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('STPG LIVE WEATHER // DETAILS', style: Stpg.title(size: 18, color: Stpg.orange, spacing: 1.6)),
          const SizedBox(height: 16),
          Row(children: [
            Icon(weatherIconFor(w, app.isDay), size: 56, color: Stpg.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(temp, style: Stpg.title(size: 54, spacing: 1)),
                ),
                Text(condition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Stpg.label(size: 14, color: Stpg.orange, spacing: 2)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Divider(color: Stpg.border, height: 1),
          row('WIND SPEED', w?.windMph != null ? '${w!.windMph} MPH' : '--'),
          row('HUMIDITY', w?.humidityPercent != null ? '${w!.humidityPercent}%' : '--'),
          row('SUNRISE LOCAL', WeatherApi.formatLocalTime(w?.sunriseLocal)),
          row('SUNSET LOCAL', WeatherApi.formatLocalTime(w?.sunsetLocal)),
          row('GPS LOCATION', location),
          const SizedBox(height: 14),
          StpgButton(
            'OPEN WEATHER',
            expand: true,
            filled: true,
            onTap: gps.hasFix
                ? () async {
                    final uri = Uri.parse(
                        'https://weather.com/weather/today/l/${gps.latitude.toStringAsFixed(4)},${gps.longitude.toStringAsFixed(4)}');
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                : null,
          ),
          const SizedBox(height: 10),
          StpgButton('CLOSE', expand: true, onTap: () => Navigator.of(ctx).pop()),
        ],
      );
    },
  );
}
