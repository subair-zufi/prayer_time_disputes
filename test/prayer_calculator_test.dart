import 'package:darimi_prayer_times/calc/prayer_calculator.dart';
import 'package:darimi_prayer_times/calc/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Worked example: 28 Sep 2026, 11.7235° N 75.6320° E, IST, 57 m.
void main() {
  CalcInput example({bool applyElevation = true}) => CalcInput(
    date: DateTime(2026, 9, 28),
    latitude: 11.723456514344237,
    longitude: 75.63203559650596,
    timezone: 5.5,
    elevation: 57,
    applyElevation: applyElevation,
  );
  final result = calculatePrayerTimes(example());
  PrayerRow row(Prayer p) => result.rows.firstWhere((r) => r.prayer == p);
  String at(Prayer p, Method m) => hms(row(p)[m].time!);

  test('sun position', () {
    expect(result.sun.declination, closeTo(-2.0541, 0.0001));
    expect(result.sun.eqt * 60, closeTo(9.29, 0.01));
  });

  test('times match the worked example', () {
    // (Sunni, Karachi, Mujahid). Mujahid equals Karachi except Rafi's
    // 1 min per 1500 m: 57 m moves sunrise and Maghrib by 2.3 s.
    final expected = {
      Prayer.fajr: ('04:58:10', '05:06:20', '05:06:20'),
      Prayer.sunrise: ('06:15:24', '06:16:29', '06:16:26'),
      Prayer.dhuhr: ('12:18:11', '12:18:11', '12:18:11'),
      Prayer.asr: ('15:36:49', '15:36:49', '15:36:49'),
      Prayer.maghrib: ('18:21:33', '18:19:53', '18:19:55'),
      Prayer.isha: ('19:30:01', '19:30:01', '19:30:01'),
    };
    expected.forEach((prayer, times) {
      expect(
        at(prayer, Method.sunni),
        times.$1,
        reason: '${prayer.label} Sunni',
      );
      expect(
        at(prayer, Method.karachi),
        times.$2,
        reason: '${prayer.label} Karachi',
      );
      expect(
        at(prayer, Method.mujahid),
        times.$3,
        reason: '${prayer.label} Mujahid',
      );
    });
  });

  test('differences are measured from Sunni', () {
    expect(
      signedDiff(row(Prayer.fajr).diffFromSunni(Method.karachi)!),
      '+8m 10s',
    );
    expect(
      signedDiff(row(Prayer.maghrib).diffFromSunni(Method.mujahid)!),
      '−1m 38s',
    );
    expect(row(Prayer.isha).diffFromSunni(Method.mujahid), 0);
    expect(row(Prayer.fajr).diffFromSunni(Method.sunni), 0);
  });

  test('Rafi\'s 16.5° Fajr and the 19° reading are logged, not used', () {
    expect(row(Prayer.fajr).note, contains('05:12:28'));
    expect(result.logText, contains('05:02:15'));
  });

  test('Mujahid: Rafi\'s 1 min per 1500 m, even with Sunni elevation off', () {
    CalcInput at(double elevation) => CalcInput(
      date: DateTime(2026, 9, 28),
      latitude: 11.723456514344237,
      longitude: 75.63203559650596,
      timezone: 5.5,
      elevation: elevation,
      applyElevation: false,
    );
    int seconds(CalcResult r, Prayer p) => toSeconds(
      r.rows.firstWhere((x) => x.prayer == p)[Method.mujahid].time!,
    );
    final sea = calculatePrayerTimes(at(0));
    final hill = calculatePrayerTimes(at(1500));
    expect(seconds(hill, Prayer.sunrise) - seconds(sea, Prayer.sunrise), -60);
    expect(seconds(hill, Prayer.maghrib) - seconds(sea, Prayer.maghrib), 60);
    expect(seconds(hill, Prayer.fajr), seconds(sea, Prayer.fajr));
    expect(seconds(hill, Prayer.isha), seconds(sea, Prayer.isha));
  });

  test('display rounding: prayers up, sunrise down', () {
    expect(hm(row(Prayer.fajr)[Method.sunni].time!, roundUp: true), '04:59');
    expect(
      hm(row(Prayer.sunrise)[Method.sunni].time!, roundUp: false),
      '06:15',
    );
    expect(hm(row(Prayer.maghrib)[Method.sunni].time!, roundUp: true), '18:22');
  });

  test('elevation off: sunrise equal, Maghrib is sunset + 4 min', () {
    final off = calculatePrayerTimes(example(applyElevation: false));
    final sunrise = off.rows.firstWhere((r) => r.prayer == Prayer.sunrise);
    expect(sunrise.diffFromSunni(Method.karachi), 0);
    final maghrib = off.rows.firstWhere((r) => r.prayer == Prayer.maghrib);
    expect(hms(maghrib[Method.sunni].time!), '18:20:28');
    expect(off.logText, contains('(turned off)'));
  });
}
