import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GPSService {
  StreamSubscription<Position>? _subscription;

  bool get isRunning => _subscription != null;

  Future<void> start({
    required Function(Position) onData,
    AndroidSettings? locationSettings,
  }) async {
    /// prevent duplicate streams
    if (_subscription != null) {
      return;
    }

    /// check location service
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        "Location service is disabled",
      );
    }

    /// check permissions
    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      throw Exception(
        "Location permission denied",
      );
    }

    /// use provided settings OR fallback
    final settings =
        locationSettings ??
        AndroidSettings(
          accuracy:
              LocationAccuracy.bestForNavigation,

          distanceFilter: 2,

          intervalDuration:
              const Duration(milliseconds: 250),

          foregroundNotificationConfig:
              const ForegroundNotificationConfig(
                notificationText:
                    "ApexLog is logging telemetry",

                notificationTitle:
                    "Telemetry Recording",

                enableWakeLock: true,

                enableWifiLock: true,
              ),
        );

    _subscription =
        Geolocator.getPositionStream(
          locationSettings: settings,
        ).listen(
          onData,

          onError: (error) {
            stop();
          },
        );
  }

  Future<void> stop() async {
    await _subscription?.cancel();

    _subscription = null;
  }
}