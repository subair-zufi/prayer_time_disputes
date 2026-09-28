import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings, saved on the device.
class AppSettings extends ChangeNotifier {
  bool manualLocation = false;
  double? latitude;
  double? longitude;

  bool manualElevation = false;
  double elevation = 0;

  /// Apply the elevation dip to the Sunni sunrise and Maghrib.
  bool applyElevation = true;

  static const _manualLocation = 'manualLocation';
  static const _latitude = 'latitude';
  static const _longitude = 'longitude';
  static const _manualElevation = 'manualElevation';
  static const _elevation = 'elevation';
  static const _applyElevation = 'applyElevation';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    manualLocation = p.getBool(_manualLocation) ?? false;
    latitude = p.getDouble(_latitude);
    longitude = p.getDouble(_longitude);
    manualElevation = p.getBool(_manualElevation) ?? false;
    elevation = p.getDouble(_elevation) ?? 0;
    applyElevation = p.getBool(_applyElevation) ?? true;
  }

  Future<void> save({
    required bool manualLocation,
    double? latitude,
    double? longitude,
    required bool manualElevation,
    required double elevation,
    required bool applyElevation,
  }) async {
    this.manualLocation = manualLocation;
    this.latitude = latitude;
    this.longitude = longitude;
    this.manualElevation = manualElevation;
    this.elevation = elevation;
    this.applyElevation = applyElevation;

    final p = await SharedPreferences.getInstance();
    await p.setBool(_manualLocation, manualLocation);
    if (latitude != null) await p.setDouble(_latitude, latitude);
    if (longitude != null) await p.setDouble(_longitude, longitude);
    await p.setBool(_manualElevation, manualElevation);
    await p.setDouble(_elevation, elevation);
    await p.setBool(_applyElevation, applyElevation);
    notifyListeners();
  }
}
