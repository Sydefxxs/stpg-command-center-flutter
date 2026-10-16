import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class WeatherApi {
  static Future<MissionWeather> fetch(double lat, double lng) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&daily=sunrise,sunset&forecast_days=1&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto');
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception('WEATHER HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>?;
    if (cur == null) throw Exception('WEATHER DATA MISSING');
    final daily = j['daily'] as Map<String, dynamic>?;
    String? first(String k) {
      final v = daily?[k];
      return (v is List && v.isNotEmpty) ? v.first as String? : null;
    }

    final code = (cur['weather_code'] as num?)?.toInt();
    return MissionWeather(
      temperatureF: (cur['temperature_2m'] as num?)?.round(),
      humidityPercent: (cur['relative_humidity_2m'] as num?)?.round(),
      windMph: (cur['wind_speed_10m'] as num?)?.round(),
      weatherCode: code,
      condition: weatherCodeLabel(code),
      sunriseLocal: first('sunrise'),
      sunsetLocal: first('sunset'),
    );
  }

  static String weatherCodeLabel(int? code) {
    switch (code) {
      case 0:
        return 'CLEAR';
      case 1:
        return 'MAINLY CLEAR';
      case 2:
        return 'PARTLY CLOUDY';
      case 3:
        return 'OVERCAST';
      case 45:
      case 48:
        return 'FOG';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'DRIZZLE';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'RAIN';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'SNOW';
      case 80:
      case 81:
      case 82:
        return 'RAIN SHOWERS';
      case 85:
      case 86:
        return 'SNOW SHOWERS';
      case 95:
      case 96:
      case 99:
        return 'THUNDERSTORM';
      default:
        return 'CONDITIONS LIVE';
    }
  }

  static int? _localMinutes(String? iso) {
    if (iso == null) return null;
    final t = iso.contains('T') ? iso.split('T').last : iso;
    final p = t.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }

  static bool isLocalDaytime() {
    final h = DateTime.now().hour;
    return h >= 6 && h < 19;
  }

  /// DAY / SUNRISE / SUNSET / NIGHT, with 45-minute golden-hour windows (same as original).
  static String solarPhase(String? sunrise, String? sunset) {
    final now = DateTime.now();
    final n = now.hour * 60 + now.minute;
    final rise = _localMinutes(sunrise), set = _localMinutes(sunset);
    if (rise == null || set == null) return isLocalDaytime() ? 'DAY' : 'NIGHT';
    if (n < rise) return 'NIGHT';
    if (n < rise + 45) return 'SUNRISE';
    if (n < set) return 'DAY';
    return n < set + 45 ? 'SUNSET' : 'NIGHT';
  }

  static String formatLocalTime(String? iso) {
    final m = _localMinutes(iso);
    if (m == null) return '--';
    final h = m ~/ 60, min = m % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${min.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }
}
