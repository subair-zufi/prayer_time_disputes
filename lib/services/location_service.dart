import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.canOpenSettings = false});
  final String message;

  /// Permission was denied for good; only the system settings can fix it.
  final bool canOpenSettings;

  @override
  String toString() => message;
}

class LocationService {
  /// True when permission is already granted (no prompt shown).
  static Future<bool> hasPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      // Some browsers do not support the Permissions API.
      return false;
    }
  }

  /// Asks for permission if needed, then returns the current position.
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
          'Location services are turned off. Turn them on and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        kIsWeb
            ? 'Location is blocked for this site. Allow it from the address '
                'bar (site settings) and try again.'
            : 'Location permission is permanently denied. Allow it in the '
                'app settings.',
        canOpenSettings: !kIsWeb,
      );
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      throw LocationFailure('Could not get your location: $e');
    }
  }
}
