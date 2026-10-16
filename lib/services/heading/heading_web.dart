// Web (iPhone Safari / Android Chrome): DeviceOrientation events.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

final _ctrl = StreamController<double>.broadcast();
bool _listening = false;

void _onOrientation(web.Event e) {
  final o = e as JSObject;
  // iOS Safari gives a true compass heading directly.
  final webkit = o.getProperty<JSNumber?>('webkitCompassHeading'.toJS);
  if (webkit != null) {
    _ctrl.add(webkit.toDartDouble % 360);
    return;
  }
  // Android Chrome: absolute alpha (counter-clockwise from north).
  final absolute = o.getProperty<JSBoolean?>('absolute'.toJS)?.toDart ?? false;
  final alpha = o.getProperty<JSNumber?>('alpha'.toJS);
  if (alpha != null && (absolute || e.type == 'deviceorientationabsolute')) {
    _ctrl.add((360 - alpha.toDartDouble) % 360);
  }
}

void _listen() {
  if (_listening) return;
  _listening = true;
  web.window.addEventListener('deviceorientationabsolute', _onOrientation.toJS);
  web.window.addEventListener('deviceorientation', _onOrientation.toJS);
}

JSObject? get _doe => globalContext.getProperty<JSObject?>('DeviceOrientationEvent'.toJS);

Stream<double>? platformHeadingStream() {
  if (!headingNeedsTap) _listen();
  return _ctrl.stream;
}

/// iPhone Safari only allows the compass after the user taps (permission prompt).
bool get headingNeedsTap {
  final d = _doe;
  return d != null && d.has('requestPermission') && !_listening;
}

Future<bool> requestHeadingPermission() async {
  final d = _doe;
  if (d == null || !d.has('requestPermission')) {
    _listen();
    return true;
  }
  try {
    // Must be called directly from the tap handler (no await before it).
    final result = await d.callMethod<JSPromise<JSString>>('requestPermission'.toJS).toDart;
    final ok = result.toDart == 'granted';
    if (ok) _listen();
    return ok;
  } catch (_) {
    return false;
  }
}
