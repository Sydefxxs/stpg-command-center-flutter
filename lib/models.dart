class StpgSession {
  final String accessToken;
  final String refreshToken;
  const StpgSession(this.accessToken, this.refreshToken);
}

class StpgDispatch {
  final String id, subject, message, recipientType, createdAt;
  StpgDispatch.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        subject = '${j['subject'] ?? ''}',
        message = '${j['message'] ?? ''}',
        recipientType = '${j['recipient_type'] ?? ''}',
        createdAt = '${j['created_at'] ?? ''}';
}

class StpgMission {
  final String id, title, instructions, deadline, status;
  StpgMission.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        title = '${j['title'] ?? ''}',
        instructions = '${j['instructions'] ?? ''}',
        deadline = '${j['deadline'] ?? ''}',
        status = '${j['status'] ?? ''}';
}

class StpgMissionInteraction {
  final String? firstViewedAt, completedAt;
  StpgMissionInteraction.fromJson(Map<String, dynamic> j)
      : firstViewedAt = j['first_viewed_at'] as String?,
        completedAt = j['completed_at'] as String?;
}

class StpgAssistanceRequest {
  final String id, userId, requestType, message, status, createdAt;
  final double latitude, longitude;
  StpgAssistanceRequest.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        userId = '${j['user_id'] ?? ''}',
        requestType = '${j['request_type'] ?? ''}',
        message = '${j['message'] ?? ''}',
        status = '${j['status'] ?? ''}',
        createdAt = '${j['created_at'] ?? ''}',
        latitude = (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude = (j['longitude'] as num?)?.toDouble() ?? 0;
}

class StpgStoreOrder {
  final String id, createdAt, customerName, customerAddress, city, state, postalCode, country,
      email, phone, productName, vendor, orderStatus, paymentStatus;
  final int quantity;
  StpgStoreOrder.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        createdAt = '${j['created_at'] ?? ''}',
        customerName = '${j['customer_name'] ?? ''}',
        customerAddress = '${j['customer_address'] ?? ''}',
        city = '${j['city'] ?? ''}',
        state = '${j['state'] ?? ''}',
        postalCode = '${j['postal_code'] ?? ''}',
        country = '${j['country'] ?? ''}',
        email = '${j['email'] ?? ''}',
        phone = '${j['phone'] ?? ''}',
        productName = '${j['product_name'] ?? ''}',
        vendor = '${j['vendor'] ?? ''}',
        orderStatus = '${j['order_status'] ?? ''}',
        paymentStatus = '${j['payment_status'] ?? ''}',
        quantity = (j['quantity'] as num?)?.toInt() ?? 0;
}

class DriverCommandProfile {
  final String userId, fullName, vehicle;
  final int? driverNumber;
  final String? badgePhotoPath;
  const DriverCommandProfile({
    required this.userId,
    required this.fullName,
    required this.vehicle,
    this.driverNumber,
    this.badgePhotoPath,
  });
}

class GmrsChannelState {
  final int? channel;
  final bool loaded, saving;
  final String? syncError, saveError, notice;
  const GmrsChannelState({
    this.channel,
    this.loaded = false,
    this.saving = false,
    this.syncError,
    this.saveError,
    this.notice,
  });
  GmrsChannelState copyWith({
    int? channel,
    bool? loaded,
    bool? saving,
    String? syncError,
    bool clearSyncError = false,
    String? saveError,
    bool clearSaveError = false,
    String? notice,
    bool clearNotice = false,
  }) =>
      GmrsChannelState(
        channel: channel ?? this.channel,
        loaded: loaded ?? this.loaded,
        saving: saving ?? this.saving,
        syncError: clearSyncError ? null : (syncError ?? this.syncError),
        saveError: clearSaveError ? null : (saveError ?? this.saveError),
        notice: clearNotice ? null : (notice ?? this.notice),
      );

  String get syncLabel {
    if (saving) return 'SAVING CHANNEL…';
    if (syncError != null && loaded) return 'SYNC UNAVAILABLE • LAST RECEIVED';
    if (syncError != null) return 'CHANNEL SYNC UNAVAILABLE';
    if (!loaded) return 'SYNCING CHANNEL…';
    if (channel == null) return 'NO SHARED CHANNEL SET';
    return 'SHARED STPG CHANNEL';
  }
}

class LiveGps {
  final bool hasPermission, hasFix;
  final double latitude, longitude;
  final int? accuracyFeet, altitudeFeet, speedMph, bearingDegrees;
  const LiveGps({
    this.hasPermission = false,
    this.hasFix = false,
    this.latitude = 0,
    this.longitude = 0,
    this.accuracyFeet,
    this.altitudeFeet,
    this.speedMph,
    this.bearingDegrees,
  });
}

class MissionWeather {
  final int? temperatureF, weatherCode, windMph, humidityPercent;
  final String condition;
  final String? sunriseLocal, sunsetLocal;
  const MissionWeather({
    this.temperatureF,
    this.weatherCode,
    this.windMph,
    this.humidityPercent,
    this.condition = 'CONDITIONS LIVE',
    this.sunriseLocal,
    this.sunsetLocal,
  });
}

class ConvoyStop {
  final String name;
  final double latitude, longitude;
  const ConvoyStop(this.name, this.latitude, this.longitude);
}

class MissionTripState {
  final String tripId;
  final bool active, saving;
  final String status;
  final int startedAt, elapsedSeconds, pointCount;
  final double distanceMeters;
  final String gpxFileName, error;
  const MissionTripState({
    this.tripId = '',
    this.active = false,
    this.saving = false,
    this.status = 'STANDBY',
    this.startedAt = 0,
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.pointCount = 0,
    this.gpxFileName = '',
    this.error = '',
  });

  MissionTripState copyWith({
    String? tripId,
    bool? active,
    bool? saving,
    String? status,
    int? startedAt,
    int? elapsedSeconds,
    double? distanceMeters,
    int? pointCount,
    String? gpxFileName,
    String? error,
  }) =>
      MissionTripState(
        tripId: tripId ?? this.tripId,
        active: active ?? this.active,
        saving: saving ?? this.saving,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        pointCount: pointCount ?? this.pointCount,
        gpxFileName: gpxFileName ?? this.gpxFileName,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'active': active,
        'saving': saving,
        'status': status,
        'startedAt': startedAt,
        'elapsedSeconds': elapsedSeconds,
        'distanceMeters': distanceMeters,
        'pointCount': pointCount,
        'gpxFileName': gpxFileName,
        'error': error,
      };

  static MissionTripState fromJson(Map<String, dynamic> j) => MissionTripState(
        tripId: j['tripId'] ?? '',
        active: j['active'] ?? false,
        saving: j['saving'] ?? false,
        status: j['status'] ?? 'STANDBY',
        startedAt: (j['startedAt'] as num?)?.toInt() ?? 0,
        elapsedSeconds: (j['elapsedSeconds'] as num?)?.toInt() ?? 0,
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        pointCount: (j['pointCount'] as num?)?.toInt() ?? 0,
        gpxFileName: j['gpxFileName'] ?? '',
        error: j['error'] ?? '',
      );

  double get miles => distanceMeters / 1609.344;
}

String missionDuration(int seconds) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';
}
