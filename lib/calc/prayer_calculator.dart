/// Prayer time calculation: Darimi (Samastha calendars) vs Karachi.
///
/// Follows the step-by-step method: day number → sun position →
/// Dhuhr → one hour-angle formula for every other time. Every step is
/// written to a log so the numbers can be checked by hand.
library;

import 'dart:math' as math;

import 'time_format.dart';

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _sin(double d) => math.sin(_rad(d));
double _cos(double d) => math.cos(_rad(d));
double _tan(double d) => math.tan(_rad(d));

enum Prayer {
  fajr('Fajr (Subh)', roundUp: true),
  sunrise('Sunrise', roundUp: false),
  dhuhr('Dhuhr', roundUp: true),
  asr('Asr', roundUp: true),
  maghrib('Maghrib', roundUp: true),
  isha('Isha', roundUp: true);

  const Prayer(this.label, {required this.roundUp});
  final String label;

  /// Prayer start times round up to the next minute; sunrise rounds down.
  final bool roundUp;
}

/// The numbers that define each method.
class Rules {
  static const karachiFajr = 18.0;
  static const karachiIsha = 18.0;
  static const darimiFajr = 20.0;
  static const darimiIsha = 18.0;

  /// Sunrise/sunset: 34′ refraction + 16′ sun radius.
  static const sunset = 0.833;

  /// Darimi: geometric sunset + 4 min (44′ between horizons + 16′ radius = 1°).
  static const darimiMaghribMinutes = 4.0;

  /// Shafi'i Asr: shadow = 1 × length + noon shadow.
  static const asrShadowFactor = 1.0;

  /// Horizon dip in degrees per √metre of elevation.
  static const dipPerSqrtMetre = 0.0347;
}

/// Sun's declination and equation of time for a date (at local noon).
class SunPosition {
  const SunPosition._({
    required this.jd0,
    required this.jd,
    required this.d,
    required this.g,
    required this.q,
    required this.l,
    required this.e,
    required this.ra,
    required this.declination,
    required this.eqt,
  });

  factory SunPosition.at(DateTime date, double longitude) {
    var y = date.year, m = date.month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + a ~/ 4;
    final jd0 = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        date.day +
        b -
        1524.5;
    final jd = jd0 + 0.5 - longitude / 360;
    final d = jd - 2451545.0;

    final g = (357.529 + 0.98560028 * d) % 360;
    final q = (280.459 + 0.98564736 * d) % 360;
    final l = (q + 1.915 * _sin(g) + 0.020 * _sin(2 * g)) % 360;
    final e = 23.439 - 0.00000036 * d;
    final ra = (_deg(math.atan2(_cos(e) * _sin(l), _cos(l))) / 15) % 24;
    final declination = _deg(math.asin(_sin(e) * _sin(l)));
    final eqt = (q / 15 - ra + 12) % 24 - 12;

    return SunPosition._(
      jd0: jd0,
      jd: jd,
      d: d,
      g: g,
      q: q,
      l: l,
      e: e,
      ra: ra,
      declination: declination,
      eqt: eqt,
    );
  }

  final double jd0, jd, d, g, q, l, e, ra;

  /// Degrees north (+) or south (−) of the equator.
  final double declination;

  /// Equation of time in hours (+ means the sun is ahead of the clock).
  final double eqt;
}

class CalcInput {
  const CalcInput({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.elevation,
    this.applyElevation = true,
    this.locationSource = 'manual',
    this.elevationSource = 'manual',
    this.timezoneSource = 'device',
  });

  final DateTime date;
  final double latitude;
  final double longitude;

  /// Hours from UTC, e.g. 5.5 for IST.
  final double timezone;

  /// Metres above sea level.
  final double elevation;

  /// Apply the elevation dip to Darimi's sunrise and Maghrib.
  final bool applyElevation;

  final String locationSource;
  final String elevationSource;
  final String timezoneSource;
}

class PrayerRow {
  const PrayerRow({
    required this.prayer,
    required this.darimi,
    required this.karachi,
    required this.rule,
    required this.reason,
  });

  final Prayer prayer;

  /// Local time in decimal hours; null when the sun never reaches the angle.
  final double? darimi;
  final double? karachi;

  /// Short label of what differs, e.g. "20° vs 18°".
  final String rule;

  /// Why the two methods give different (or the same) times.
  final String reason;

  /// Darimi − Karachi in seconds.
  int? get diffSeconds => darimi == null || karachi == null
      ? null
      : toSeconds(darimi!) - toSeconds(karachi!);
}

enum LogKind { header, line, note }

class LogLine {
  const LogLine(this.kind, this.text);
  final LogKind kind;
  final String text;
}

class CalcResult {
  const CalcResult({
    required this.input,
    required this.sun,
    required this.dip,
    required this.rows,
    required this.log,
  });

  final CalcInput input;
  final SunPosition sun;

  /// Elevation dip in degrees.
  final double dip;
  final List<PrayerRow> rows;
  final List<LogLine> log;

  String get logText => log
      .map((l) => switch (l.kind) {
            LogKind.header => '\n== ${l.text} ==',
            LogKind.line => l.text,
            LogKind.note => '   » ${l.text}',
          })
      .join('\n')
      .trim();
}

typedef _HourAngle = ({double cosH, double? h, double? t});

const _k = 'Karachi/Mujahid';
const _d = 'Darimi';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "+ 5.50" or "− 5.50" for use inside a written-out sum.
String _plus(double v, int decimals) =>
    v < 0 ? '− ${fmt(-v, decimals)}' : '+ ${fmt(v, decimals)}';
String _minus(double v, int decimals) =>
    v < 0 ? '+ ${fmt(-v, decimals)}' : '− ${fmt(v, decimals)}';

CalcResult calculatePrayerTimes(CalcInput input) {
  final log = <LogLine>[];
  void header(String t) => log.add(LogLine(LogKind.header, t));
  void line(String t) => log.add(LogLine(LogKind.line, t));
  void note(String t) => log.add(LogLine(LogKind.note, t));

  final phi = input.latitude;
  final lon = input.longitude;
  final tz = input.timezone;
  final sun = SunPosition.at(input.date, lon);
  final dec = sun.declination;

  // ── Inputs ────────────────────────────────────────────────────────────
  header('Inputs');
  line('Date          ${_date(input.date)}');
  line('Latitude  φ   ${fmt(phi, 6)}°  (${input.locationSource})');
  line('Longitude λ   ${fmt(lon, 6)}°');
  line('Time zone     ${tz < 0 ? '−' : '+'}${tz.abs().toStringAsFixed(2)} h  '
      '(${input.timezoneSource})');
  line('Elevation h   ${input.elevation.toStringAsFixed(1)} m  '
      '(${input.elevationSource})');

  // ── Step 1 ────────────────────────────────────────────────────────────
  header('Step 1 · Day number');
  line('JD at 0h UT       = ${sun.jd0.toStringAsFixed(1)}');
  line('JD at local noon  = JD + 0.5 − λ/360 = ${sun.jd.toStringAsFixed(5)}');
  line('D = JD − 2451545  = ${sun.d.toStringAsFixed(5)}');

  // ── Step 2 ────────────────────────────────────────────────────────────
  header('Step 2 · Sun position');
  line('g   = 357.529 + 0.98560028·D         = ${fmt(sun.g)}°');
  line('q   = 280.459 + 0.98564736·D         = ${fmt(sun.q)}°');
  line('L   = q + 1.915·sin g + 0.020·sin 2g = ${fmt(sun.l)}°');
  line('e   = 23.439 − 0.00000036·D          = ${fmt(sun.e)}°');
  line('RA  = atan2(cos e·sin L, cos L) / 15 = ${fmt(sun.ra)} h');
  line('δ   = asin(sin e·sin L)              = ${fmt(dec)}°');
  line('EqT = q/15 − RA                      = ${fmt(sun.eqt, 5)} h '
      '(${fmt(sun.eqt * 60, 2)} min)');
  note('δ: how far north/south the sun is. EqT: how far the real sun '
      'runs ahead of the clock.');

  // ── Step 3 ────────────────────────────────────────────────────────────
  header('Step 3 · Dhuhr (solar noon)');
  final dhuhr = 12 + tz - lon / 15 - sun.eqt;
  line('Dhuhr = 12 + TZ − λ/15 − EqT');
  line('      = 12 ${_plus(tz, 2)} ${_minus(lon / 15, 5)} '
      '${_minus(sun.eqt, 5)} = ${fmt(dhuhr, 5)} h → ${hms(dhuhr)}');

  // ── Step 4 ────────────────────────────────────────────────────────────
  header('Step 4 · One formula for the rest');
  final sinSin = _sin(phi) * _sin(dec);
  final cosCos = _cos(phi) * _cos(dec);
  line('cos H = (sin a − sin φ·sin δ) / (cos φ·cos δ),   T = H / 15');
  line('sin φ·sin δ = ${fmt(sinSin, 6)}');
  line('cos φ·cos δ = ${fmt(cosCos, 6)}');
  note('a = sun altitude (negative = below the horizon). '
      'Morning = Dhuhr − T, evening = Dhuhr + T.');

  _HourAngle ha(double a) {
    final c = (_sin(a) - sinSin) / cosCos;
    if (c < -1 || c > 1) return (cosH: c, h: null, t: null);
    final h = _deg(math.acos(c));
    return (cosH: c, h: h, t: h / 15);
  }

  double? morning(_HourAngle r) => r.t == null ? null : dhuhr - r.t!;
  double? evening(_HourAngle r) => r.t == null ? null : dhuhr + r.t!;

  String haLine(String who, double a, _HourAngle r, double? time) {
    final base = '${who.padRight(15)} a = ${fmt(a, 3).padLeft(7)}°  '
        'cos H = ${fmt(r.cosH, 5)}';
    if (r.t == null) return '$base  → sun never reaches this angle today';
    return '$base  H = ${fmt(r.h!, 3)}°  T = ${span(r.t!)}  → ${hms(time!)}';
  }

  final rows = <PrayerRow>[];
  void addRow(PrayerRow row) {
    rows.add(row);
    final diff = row.diffSeconds;
    note('Δ ${diff == null ? 'n/a' : signedDiff(diff)} · ${row.reason}');
  }

  final dip = Rules.dipPerSqrtMetre * math.sqrt(math.max(0, input.elevation));
  final useDip = input.applyElevation && dip > 0;

  // ── Fajr ──────────────────────────────────────────────────────────────
  header('Step 5 · Fajr (Subh)');
  final kFajrHa = ha(-Rules.karachiFajr);
  final dFajrHa = ha(-Rules.darimiFajr);
  final kFajr = morning(kFajrHa);
  final dFajr = morning(dFajrHa);
  line(haLine(_k, -Rules.karachiFajr, kFajrHa, kFajr));
  line(haLine(_d, -Rules.darimiFajr, dFajrHa, dFajr));
  addRow(PrayerRow(
    prayer: Prayer.fajr,
    darimi: dFajr,
    karachi: kFajr,
    rule: '20° vs 18°',
    reason: 'Darimi takes true dawn (fajr sadiq) when the sun is 20° below '
        'the true horizon (19° from the visible horizon to the sun\'s upper '
        'edge). Karachi and Mujahid practice use 18°. The sun is at 20° '
        'earlier, so Fajr starts earlier.',
  ));

  // ── Sunrise ───────────────────────────────────────────────────────────
  header('Step 5 · Sunrise');
  final sunHa = ha(-Rules.sunset);
  final kSunrise = morning(sunHa);
  line(haLine(_k, -Rules.sunset, sunHa, kSunrise));
  double? dSunrise = kSunrise;
  double elevShift = 0;
  if (useDip) {
    line('Elevation dip = ${Rules.dipPerSqrtMetre} × √'
        '${input.elevation.toStringAsFixed(1)} = ${fmt(dip, 3)}°');
    final dipHa = ha(-(Rules.sunset + dip));
    dSunrise = morning(dipHa);
    line(haLine(_d, -(Rules.sunset + dip), dipHa, dSunrise));
    if (dipHa.t != null && sunHa.t != null) elevShift = dipHa.t! - sunHa.t!;
  } else {
    line('${_d.padRight(15)} same as Karachi (elevation correction '
        '${input.applyElevation ? 'is 0 at 0 m' : 'turned off'})');
  }
  addRow(PrayerRow(
    prayer: Prayer.sunrise,
    darimi: dSunrise,
    karachi: kSunrise,
    rule: useDip ? 'elevation ${input.elevation.round()} m' : 'same',
    reason: useDip
        ? 'Both use 0.833° (34′ refraction + 16′ sun radius). Darimi also '
            'lowers the horizon by the elevation dip (${fmt(dip, 3)}° at '
            '${input.elevation.round()} m): from higher up you see the sun '
            'sooner. Karachi ignores elevation. Fajr ends earlier (safe side).'
        : 'Same rule: sun 0.833° below the horizon.',
  ));

  // ── Dhuhr ─────────────────────────────────────────────────────────────
  header('Step 5 · Dhuhr');
  line('Both            → ${hms(dhuhr)}  (from Step 3)');
  addRow(PrayerRow(
    prayer: Prayer.dhuhr,
    darimi: dhuhr,
    karachi: dhuhr,
    rule: 'same',
    reason: 'Same rule: the sun crosses the meridian (zawal). '
        'Some apps add 1 min as a margin.',
  ));

  // ── Asr ───────────────────────────────────────────────────────────────
  header('Step 5 · Asr (Shafi\'i)');
  final gap = (phi - dec).abs();
  final x = Rules.asrShadowFactor + _tan(gap);
  final asrAlt = _deg(math.atan(1 / x));
  final asrHa = ha(asrAlt);
  final asr = evening(asrHa);
  line('|φ − δ| = ${fmt(gap)}°   tan|φ − δ| = ${fmt(_tan(gap), 5)}');
  line('a = arccot(1 + tan|φ − δ|) = arccot(${fmt(x, 5)}) = '
      '${fmt(asrAlt, 3)}°');
  line(haLine('Both', asrAlt, asrHa, asr));
  final hanafi = evening(ha(_deg(math.atan(1 / (2 + _tan(gap))))));
  if (hanafi != null) {
    note('For reference only: Hanafi (shadow factor 2) would be '
        '${hms(hanafi)}. Not used.');
  }
  addRow(PrayerRow(
    prayer: Prayer.asr,
    darimi: asr,
    karachi: asr,
    rule: 'same',
    reason: 'Same rule: Shafi\'i Asr, shadow = 1 × length + noon shadow.',
  ));

  // ── Maghrib ───────────────────────────────────────────────────────────
  header('Step 5 · Maghrib');
  final kMaghrib = evening(sunHa);
  line(haLine(_k, -Rules.sunset, sunHa, kMaghrib));
  final geoHa = ha(0);
  final geoSunset = evening(geoHa);
  double? dMaghrib;
  if (geoSunset != null) {
    line(haLine('$_d (geom.)', 0, geoHa, geoSunset));
    dMaghrib = geoSunset + Rules.darimiMaghribMinutes / 60;
    line('${_d.padRight(15)} + ${Rules.darimiMaghribMinutes.round()} min '
        '→ ${hms(dMaghrib)}');
    if (elevShift > 0) {
      dMaghrib += elevShift;
      line('${_d.padRight(15)} + elevation '
          '${signedDiff(toSeconds(elevShift))} → ${hms(dMaghrib)}');
    }
  }
  addRow(PrayerRow(
    prayer: Prayer.maghrib,
    darimi: dMaghrib,
    karachi: kMaghrib,
    rule: '+4 min rule${elevShift > 0 ? ' + elevation' : ''}',
    reason: 'Karachi and Mujahid practice: sunset with the sun 0.833° below '
        'the horizon (zenith distance 90°50′). Darimi: geometric sunset (sun '
        'centre on the true horizon) + 4 min, since 44′ between the horizons '
        '+ 16′ sun radius = 1° ≈ 4 min'
        '${elevShift > 0 ? ', then the elevation shift (${signedDiff(toSeconds(elevShift))})' : ''}. '
        'Maghrib starts later (safe side).',
  ));

  // ── Isha ──────────────────────────────────────────────────────────────
  header('Step 5 · Isha');
  final ishaHa = ha(-Rules.darimiIsha);
  final isha = evening(ishaHa);
  line(haLine('Both', -Rules.darimiIsha, ishaHa, isha));
  addRow(PrayerRow(
    prayer: Prayer.isha,
    darimi: isha,
    karachi: evening(ha(-Rules.karachiIsha)),
    rule: 'same',
    reason: 'Same angle. Darimi: red twilight disappears at 18° below the true '
        'horizon (17° after the visible sunset). Karachi also uses 18°.',
  ));

  // ── Summary ───────────────────────────────────────────────────────────
  header('Summary');
  line('${'Prayer'.padRight(12)}${'Darimi'.padRight(11)}'
      '${'Karachi'.padRight(11)}Δ');
  for (final r in rows) {
    String t(double? v) => (v == null ? '—' : hms(v)).padRight(11);
    final diff = r.diffSeconds;
    line('${r.prayer.label.padRight(12)}${t(r.darimi)}${t(r.karachi)}'
        '${diff == null ? '—' : signedDiff(diff)}');
  }
  note('"Karachi/Mujahid": Shabab Weekly gives Fajr at 18° and Maghrib at '
      'sunset (90°50′); Darimi reports they use 18° for Isha. That matches '
      'Karachi, so one column shows both.');
  note('Times are for this exact point. Printed Samastha calendars give one '
      'time per zone (Kozhikode, Kasaragod, Kochi, Thiruvananthapuram), so '
      'they can differ by a few minutes.');
  note('On screen, prayer start times round up and sunrise rounds down.');

  return CalcResult(input: input, sun: sun, dip: dip, rows: rows, log: log);
}
