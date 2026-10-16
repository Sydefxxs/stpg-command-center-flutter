// Android / iOS: magnetometer via flutter_compass.
import 'package:flutter_compass/flutter_compass.dart';

Stream<double>? platformHeadingStream() =>
    FlutterCompass.events?.where((e) => e.heading != null).map((e) => (e.heading! + 360) % 360);

bool get headingNeedsTap => false;

Future<bool> requestHeadingPermission() async => true;
