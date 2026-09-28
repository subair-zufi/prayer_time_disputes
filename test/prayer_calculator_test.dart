import 'package:darimi_prayer_times/calc/prayer_calculator.dart';
import 'package:darimi_prayer_times/calc/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Worked example: 28 Sep 2026, 11.7235° N 75.6320° E, IST, 57 m.
void main() {
  final result = calculatePrayerTimes(CalcInput(
    date: DateTime(2026, 9, 28),
    latitude: 11.723456514344237,
    longitude: 75.63203559650596,
    timezone: 5.5,
    elevation: 57,
  ));
  PrayerRow row(Prayer p) => result.rows.firstWhere((r) => r.prayer == p);

  test('sun position', () {
    expect(result.sun.declination, closeTo(-2.0541, 0.0001));
    expect(result.sun.eqt * 60, closeTo(9.29, 0.01));
  });

  test('Darimi vs Karachi times match the worked example', () {
    final expected = {
      Prayer.fajr: ('04:58:10', '05:06:20'),
      Prayer.sunrise: ('06:15:24', '06:16:29'),
      Prayer.dhuhr: ('12:18:11', '12:18:11'),
      Prayer.asr: ('15:36:49', '15:36:49'),
      Prayer.maghrib: ('18:21:33', '18:19:53'),
      Prayer.isha: ('19:30:01', '19:30:01'),
    };
    expected.forEach((prayer, times) {
      expect(hms(row(prayer).darimi!), times.$1, reason: '${prayer.label} Darimi');
      expect(hms(row(prayer).karachi!), times.$2, reason: '${prayer.label} Karachi');
    });
  });

  test('differences', () {
    expect(signedDiff(row(Prayer.fajr).diffSeconds!), '−8m 10s');
    expect(signedDiff(row(Prayer.maghrib).diffSeconds!), '+1m 40s');
    expect(row(Prayer.isha).diffSeconds, 0);
  });

  test('display rounding: prayers up, sunrise down', () {
    expect(hm(row(Prayer.fajr).darimi!, roundUp: true), '04:59');
    expect(hm(row(Prayer.sunrise).darimi!, roundUp: false), '06:15');
    expect(hm(row(Prayer.maghrib).darimi!, roundUp: true), '18:22');
  });

  test('elevation off makes sunrise equal', () {
    final noElev = calculatePrayerTimes(CalcInput(
      date: DateTime(2026, 9, 28),
      latitude: 11.723456514344237,
      longitude: 75.63203559650596,
      timezone: 5.5,
      elevation: 57,
      applyElevation: false,
    ));
    final sunrise = noElev.rows.firstWhere((r) => r.prayer == Prayer.sunrise);
    expect(sunrise.diffSeconds, 0);
    final maghrib = noElev.rows.firstWhere((r) => r.prayer == Prayer.maghrib);
    expect(hms(maghrib.darimi!), '18:20:28');
  });
}
