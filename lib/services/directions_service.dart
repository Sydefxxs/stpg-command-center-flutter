import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

class RouteStep {
  final String instruction;
  final int distanceMeters;
  final LatLng start;
  const RouteStep(this.instruction, this.distanceMeters, this.start);
}

class RouteResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteStep> steps;
  const RouteResult(this.points, this.distanceMeters, this.durationSeconds, this.steps);
}

class DirectionsService {
  /// Driving route from [from] through [stops] (in order). Throws on failure.
  static Future<RouteResult> route(LatLng from, List<LatLng> stops) async {
    if (stops.isEmpty) throw Exception('No destination');
    try {
      return StpgConfig.hasGoogleMaps ? await _google(from, stops) : await _osrm(from, stops);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Routing failed ($e)');
    }
  }

  static String _ll(LatLng p) => '${p.latitude},${p.longitude}';

  static Future<RouteResult> _google(LatLng from, List<LatLng> stops) async {
    final params = <String, String>{
      'origin': _ll(from),
      'destination': _ll(stops.last),
      'mode': 'driving',
      'key': StpgConfig.googleMapsApiKey,
    };
    if (stops.length > 1) {
      params['waypoints'] = stops.sublist(0, stops.length - 1).map(_ll).join('|');
    }
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Directions HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final msg = body['error_message'] as String?;
      throw Exception(msg == null ? 'Directions $status' : 'Directions $status: $msg');
    }
    final routes = body['routes'] as List? ?? const [];
    if (routes.isEmpty) throw Exception('No route found');
    final r = routes.first as Map<String, dynamic>;
    final points = decodePolyline((r['overview_polyline'] as Map)['points'] as String);
    var dist = 0, dur = 0;
    final steps = <RouteStep>[];
    for (final leg in (r['legs'] as List? ?? const [])) {
      dist += ((leg['distance'] as Map?)?['value'] as num? ?? 0).toInt();
      dur += ((leg['duration'] as Map?)?['value'] as num? ?? 0).toInt();
      for (final s in (leg['steps'] as List? ?? const [])) {
        final loc = s['start_location'] as Map;
        steps.add(RouteStep(
          _stripHtml(s['html_instructions'] as String? ?? ''),
          ((s['distance'] as Map?)?['value'] as num? ?? 0).toInt(),
          LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
        ));
      }
    }
    return RouteResult(points, dist, dur, steps);
  }

  static String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<div[^>]*>'), ' - ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Google encoded polyline decoder (precision 1e5).
  static List<LatLng> decodePolyline(String encoded) {
    final out = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      var shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      out.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return out;
  }

  static Future<RouteResult> _osrm(LatLng from, List<LatLng> stops) async {
    final coords = [from, ...stops].map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true');
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) throw Exception('Routing HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') throw Exception(body['message'] as String? ?? 'No route found (${body['code']})');
    final routes = body['routes'] as List? ?? const [];
    if (routes.isEmpty) throw Exception('No route found');
    final r = routes.first as Map<String, dynamic>;
    final points = [
      for (final c in ((r['geometry'] as Map)['coordinates'] as List))
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    final steps = <RouteStep>[];
    for (final leg in (r['legs'] as List? ?? const [])) {
      for (final s in (leg['steps'] as List? ?? const [])) {
        final m = s['maneuver'] as Map;
        final loc = m['location'] as List;
        steps.add(RouteStep(
          _osrmInstruction(m['type'] as String? ?? '', m['modifier'] as String?, s['name'] as String? ?? ''),
          (s['distance'] as num? ?? 0).round(),
          LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
        ));
      }
    }
    return RouteResult(points, (r['distance'] as num? ?? 0).round(), (r['duration'] as num? ?? 0).round(), steps);
  }

  static String _osrmInstruction(String type, String? modifier, String name) {
    final road = name.trim();
    final onto = road.isEmpty ? '' : ' ONTO $road';
    final mod = (modifier ?? '').toUpperCase();
    switch (type) {
      case 'depart':
        return road.isEmpty ? 'HEAD OUT' : 'HEAD OUT ON $road';
      case 'arrive':
        return 'ARRIVE AT DESTINATION${mod.isEmpty ? '' : ' ON THE $mod'}';
      case 'turn':
        if (modifier == 'uturn') return 'MAKE A U-TURN$onto';
        return mod.isEmpty ? 'TURN$onto' : 'TURN $mod$onto';
      case 'end of road':
        return mod.isEmpty ? 'AT END OF ROAD$onto' : 'AT END OF ROAD TURN $mod$onto';
      case 'fork':
        return mod.isEmpty ? 'TAKE THE FORK$onto' : 'KEEP $mod AT THE FORK$onto';
      case 'merge':
        return 'MERGE${mod.isEmpty ? '' : ' $mod'}$onto';
      case 'on ramp':
        return 'TAKE THE RAMP${mod.isEmpty ? '' : ' $mod'}$onto';
      case 'off ramp':
        return 'TAKE THE EXIT${mod.isEmpty ? '' : ' $mod'}$onto';
      case 'roundabout':
      case 'rotary':
        return 'ENTER THE ROUNDABOUT$onto';
      case 'continue':
      case 'new name':
        return road.isEmpty ? 'CONTINUE' : 'CONTINUE ONTO $road';
      default:
        if (mod.isNotEmpty) return 'TURN $mod$onto';
        return road.isEmpty ? 'CONTINUE' : 'CONTINUE ONTO $road';
    }
  }
}
