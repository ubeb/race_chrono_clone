import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GPSService {
  StreamSubscription<Position>? _subscription;

  void start({
    required Function(Position) onData,
  }) async {
    LocationPermission permission =
        await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(onData);
  }

  void stop() {
    _subscription?.cancel();
  }
}