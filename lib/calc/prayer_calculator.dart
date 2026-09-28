/// Prayer time calculation: Sunni (Samastha calendars, per Darimi), Karachi and
/// Mujahid practice, side by side.
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

enum Method {
  sunni('Sunni', 'Dr. Musthafa Darimi, Suprabhaatham (~2020)'),
  karachi('Karachi', 'Univ. of Islamic Sciences, Karachi, with Shafi\'i Asr'),
  mujahid(
    'Mujahid',
    'T.P.M. Rafi, Shabab Weekly (~2021), and Darimi\'s '
        'account of Mujahid practice',
  );

  const Method(this.label, this.source);
  final String label;
  final String source;
}

/// The numbers that define each method.
class Rules {
  static const sunniFajr = 20.0;
  static const karachiFajr = 18.0;
  static const mujahidFajr = 18.0;

  /// Rafi's preferred true-dawn angle (Dr. Ilyas). Logged only.
  static const mujahidFajrPreferred = 16.5;

  /// Rafi says Sunni mosques give Fajr at 19°. Logged only.
  static const rafiSunniFajr = 19.0;

  static const sunniIsha = 18.0;
  static const karachiIsha = 18.0;
  static const mujahidIsha = 18.0;

  /// Sunrise/sunset: 34′ refraction + 16′ sun radius (zenith distance 90°50′).
  static const sunset = 0.833;

  /// Sunni (Darimi): geometric sunset + 4 min (44′ between horizons + 16′ radius = 1°).
  static const sunniMaghribMinutes = 4.0;

  /// Shafi'i Asr: shadow = 1 × length + noon shadow.
  static const asrShadowFactor = 1.0;

  /// Horizon dip in degrees per √metre of elevation.
  static const dipPerSqrtMetre = 0.0347;

  /// Rafi: sunset about 1 min later for every 1500 m of height.
  static const rafiMetresPerMinute = 1500.0;
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
    final jd0 =
        (365.25 * (y + 4716)).floor() +
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

  /// Apply the elevation dip to the Sunni sunrise and Maghrib.
  final bool applyElevation;

  final String locationSource;
  final String elevationSource;
  final String timezoneSource;
}

/// One method's time for one prayer, with its rule and reason.
class MethodTime {
  const MethodTime(this.time, this.rule, this.reason);

  /// Local time in decimal hours; null when the sun never reaches the angle.
  final double? time;

  /// Short label of the rule, e.g. "20°".
  final String rule;

  /// The rule in words, with where it comes from.
  final String reason;
}

class PrayerRow {
  const PrayerRow({required this.prayer, required this.methods, this.note});

  final Prayer prayer;
  final Map<Method, MethodTime> methods;

  /// Extra information, e.g. an alternative angle that is not used.
  final String? note;

  MethodTime operator [](Method m) => methods[m]!;

  /// Seconds later (+) or earlier (−) than Sunni.
  int? diffFromSunni(Method m) {
    final t = this[m].time, s = this[Method.sunni].time;
    return t == null || s == null ? null : toSeconds(t) - toSeconds(s);
  }
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

  String get logText =>
      log
          .map(
            (l) => switch (l.kind) {
              LogKind.header => '\n== ${l.text} ==',
              LogKind.line => l.text,
              LogKind.note => '   » ${l.text}',
            },
          )
          .join('\n')
          .trim();
}

typedef _HourAngle = ({double cosH, double? h, double? t});

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
  line(
    'Time zone     ${tz < 0 ? '−' : '+'}${tz.abs().toStringAsFixed(2)} h  '
    '(${input.timezoneSource})',
  );
  line(
    'Elevation h   ${input.elevation.toStringAsFixed(1)} m  '
    '(${input.elevationSource})',
  );

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
  line(
    'EqT = q/15 − RA                      = ${fmt(sun.eqt, 5)} h '
    '(${fmt(sun.eqt * 60, 2)} min)',
  );
  note(
    'δ: how far north/south the sun is. EqT: how far the real sun '
    'runs ahead of the clock.',
  );

  // ── Step 3 ────────────────────────────────────────────────────────────
  header('Step 3 · Dhuhr (solar noon)');
  final dhuhr = 12 + tz - lon / 15 - sun.eqt;
  line('Dhuhr = 12 + TZ − λ/15 − EqT');
  line(
    '      = 12 ${_plus(tz, 2)} ${_minus(lon / 15, 5)} '
    '${_minus(sun.eqt, 5)} = ${fmt(dhuhr, 5)} h → ${hms(dhuhr)}',
  );

  // ── Step 4 ────────────────────────────────────────────────────────────
  header('Step 4 · One formula for the rest');
  final sinSin = _sin(phi) * _sin(dec);
  final cosCos = _cos(phi) * _cos(dec);
  line('cos H = (sin a − sin φ·sin δ) / (cos φ·cos δ),   T = H / 15');
  line('sin φ·sin δ = ${fmt(sinSin, 6)}');
  line('cos φ·cos δ = ${fmt(cosCos, 6)}');
  note(
    'a = sun altitude (negative = below the horizon). '
    'Morning = Dhuhr − T, evening = Dhuhr + T.',
  );

  _HourAngle ha(double a) {
    final c = (_sin(a) - sinSin) / cosCos;
    if (c < -1 || c > 1) return (cosH: c, h: null, t: null);
    final h = _deg(math.acos(c));
    return (cosH: c, h: h, t: h / 15);
  }

  double? morning(_HourAngle r) => r.t == null ? null : dhuhr - r.t!;
  double? evening(_HourAngle r) => r.t == null ? null : dhuhr + r.t!;

  String haLine(String who, double a, _HourAngle r, double? time) {
    final base =
        '${who.padRight(15)} a = ${fmt(a, 3).padLeft(7)}°  '
        'cos H = ${fmt(r.cosH, 5)}';
    if (r.t == null) return '$base  → sun never reaches this angle today';
    return '$base  H = ${fmt(r.h!, 3)}°  T = ${span(r.t!)}  → ${hms(time!)}';
  }

  String? at(double? time) => time == null ? null : hms(time);

  final rows = <PrayerRow>[];
  void addRow(PrayerRow row) {
    rows.add(row);
    for (final m in Method.values) {
      note('${m.label}: ${row[m].reason}');
    }
    String diff(Method m) {
      final s = row.diffFromSunni(m);
      return '${m.label} ${s == null
          ? 'n/a'
          : s == 0
          ? 'same'
          : signedDiff(s)}';
    }

    note('vs Sunni: ${diff(Method.karachi)} · ${diff(Method.mujahid)}');
    if (row.note != null) note(row.note!);
  }

  final dip = Rules.dipPerSqrtMetre * math.sqrt(math.max(0, input.elevation));
  final useDip = input.applyElevation && dip > 0;
  final rafiElevationSeconds =
      math.max(0, input.elevation) / Rules.rafiMetresPerMinute * 60;

  // ── Fajr ──────────────────────────────────────────────────────────────
  header('Step 5 · Fajr (Subh)');
  final sFajrHa = ha(-Rules.sunniFajr);
  final kFajrHa = ha(-Rules.karachiFajr);
  final mFajrHa = ha(-Rules.mujahidFajr);
  final sFajr = morning(sFajrHa);
  final kFajr = morning(kFajrHa);
  final mFajr = morning(mFajrHa);
  line(haLine('Sunni', -Rules.sunniFajr, sFajrHa, sFajr));
  line(haLine('Karachi', -Rules.karachiFajr, kFajrHa, kFajr));
  line(haLine('Mujahid', -Rules.mujahidFajr, mFajrHa, mFajr));
  final preferred = at(morning(ha(-Rules.mujahidFajrPreferred)));
  addRow(
    PrayerRow(
      prayer: Prayer.fajr,
      methods: {
        Method.sunni: MethodTime(
          sFajr,
          '20°',
          'true dawn (fajr sadiq) when the sun\'s centre is 20° below the '
              'true horizon (19° from the visible horizon to its upper edge). '
              'White light appears first at 20°.',
        ),
        Method.karachi: MethodTime(
          kFajr,
          '18°',
          'the method\'s Fajr angle, 18°.',
        ),
        Method.mujahid: MethodTime(
          mFajr,
          '18°',
          '18°. Darimi says Mujahids use 18°; Rafi says "18° or below".',
        ),
      },
      note:
          preferred == null
              ? null
              : 'Rafi argues true dawn is nearer 16°–16.5° (Dr. Ilyas). At 16.5° '
                  'Fajr would be $preferred. Shown here only, not used.',
    ),
  );

  // ── Sunrise ───────────────────────────────────────────────────────────
  header('Step 5 · Sunrise');
  final sunHa = ha(-Rules.sunset);
  final dipHa = ha(-(Rules.sunset + dip));
  // How much the elevation dip moves sunrise/sunset, used or not.
  final dipShift =
      dip > 0 && dipHa.t != null && sunHa.t != null ? dipHa.t! - sunHa.t! : 0.0;
  final elevShift = useDip ? dipShift : 0.0;
  final plainSunrise = morning(sunHa);
  double? sSunrise = plainSunrise;
  if (useDip) {
    line(
      'Elevation dip = ${Rules.dipPerSqrtMetre} × √'
      '${input.elevation.toStringAsFixed(1)} = ${fmt(dip, 3)}°',
    );
    sSunrise = morning(dipHa);
    line(haLine('Sunni', -(Rules.sunset + dip), dipHa, sSunrise));
  } else {
    line(haLine('Sunni', -Rules.sunset, sunHa, sSunrise));
  }
  line(haLine('Karachi', -Rules.sunset, sunHa, plainSunrise));
  line(haLine('Mujahid', -Rules.sunset, sunHa, plainSunrise));
  addRow(
    PrayerRow(
      prayer: Prayer.sunrise,
      methods: {
        Method.sunni: MethodTime(
          sSunrise,
          useDip ? '0.833° + dip' : '0.833°',
          useDip
              ? 'sun 0.833° below the horizon, lowered by the elevation dip '
                  '(${fmt(dip, 3)}° at ${input.elevation.round()} m): from '
                  'higher up you see the sun sooner.'
              : 'sun 0.833° below the horizon '
                  '(elevation ${input.applyElevation ? 'is 0' : 'turned off'}).',
        ),
        Method.karachi: MethodTime(
          plainSunrise,
          '0.833°',
          'sun 0.833° below the horizon (34′ refraction + 16′ radius). '
              'Elevation ignored.',
        ),
        Method.mujahid: MethodTime(
          plainSunrise,
          '0.833°',
          'same 0.833°. Rafi puts elevation at about 1 min per 1500 m '
              '(${rafiElevationSeconds.toStringAsFixed(1)} s here), so it is '
              'ignored.',
        ),
      },
    ),
  );

  // ── Dhuhr ─────────────────────────────────────────────────────────────
  header('Step 5 · Dhuhr');
  line('All three       → ${hms(dhuhr)}  (from Step 3)');
  addRow(
    PrayerRow(
      prayer: Prayer.dhuhr,
      methods: {
        Method.sunni: MethodTime(dhuhr, 'noon', 'sun crosses the meridian.'),
        Method.karachi: MethodTime(dhuhr, 'noon', 'sun crosses the meridian.'),
        Method.mujahid: MethodTime(
          dhuhr,
          'noon',
          'per Rafi, the sun crosses the local meridian (highest point).',
        ),
      },
      note: 'Some apps add 1 min as a margin.',
    ),
  );

  // ── Asr ───────────────────────────────────────────────────────────────
  header('Step 5 · Asr');
  final gap = (phi - dec).abs();
  final x = Rules.asrShadowFactor + _tan(gap);
  final asrAlt = _deg(math.atan(1 / x));
  final asrHa = ha(asrAlt);
  final asr = evening(asrHa);
  line('|φ − δ| = ${fmt(gap)}°   tan|φ − δ| = ${fmt(_tan(gap), 5)}');
  line(
    'a = arccot(1 + tan|φ − δ|) = arccot(${fmt(x, 5)}) = '
    '${fmt(asrAlt, 3)}°',
  );
  line(haLine('All three', asrAlt, asrHa, asr));
  final hanafi = at(evening(ha(_deg(math.atan(1 / (2 + _tan(gap)))))));
  addRow(
    PrayerRow(
      prayer: Prayer.asr,
      methods: {
        Method.sunni: MethodTime(
          asr,
          '1× shadow',
          'shadow = 1 × length + noon shadow (Shafi\'i).',
        ),
        Method.karachi: MethodTime(
          asr,
          '1× shadow',
          'Asr set to Shafi\'i (the Karachi method itself only fixes Fajr '
              'and Isha).',
        ),
        Method.mujahid: MethodTime(
          asr,
          '1× shadow',
          'per Rafi, shadow = noon shadow + the object\'s length, the same as '
              'Shafi\'i.',
        ),
      },
      note:
          hanafi == null
              ? null
              : 'Hanafi (shadow factor 2) would be $hanafi. Not used.',
    ),
  );

  // ── Maghrib ───────────────────────────────────────────────────────────
  header('Step 5 · Maghrib');
  final geoHa = ha(0);
  final geoSunset = evening(geoHa);
  double? sMaghrib;
  var shiftText = '';
  if (geoSunset != null) {
    line(haLine('Sunni (geom.)', 0, geoHa, geoSunset));
    final plus4 = geoSunset + Rules.sunniMaghribMinutes / 60;
    sMaghrib = plus4;
    line(
      '${'Sunni'.padRight(15)} + ${Rules.sunniMaghribMinutes.round()} '
      'min → ${hms(plus4)}',
    );
    if (elevShift > 0) {
      sMaghrib = plus4 + elevShift;
      // From the rounded times, so the logged step adds up.
      shiftText = signedDiff(toSeconds(sMaghrib) - toSeconds(plus4));
      line(
        '${'Sunni'.padRight(15)} + elevation $shiftText → '
        '${hms(sMaghrib)}',
      );
    }
  }
  final plainSunset = evening(sunHa);
  line(haLine('Karachi', -Rules.sunset, sunHa, plainSunset));
  line(haLine('Mujahid', -Rules.sunset, sunHa, plainSunset));
  addRow(
    PrayerRow(
      prayer: Prayer.maghrib,
      methods: {
        Method.sunni: MethodTime(
          sMaghrib,
          elevShift > 0 ? '+4 min + dip' : '+4 min',
          'geometric sunset (sun\'s centre on the true horizon) + 4 min, '
          'since 44′ between the horizons + 16′ radius = 1° ≈ 4 min'
          '${shiftText.isEmpty ? '' : ', then the elevation shift ($shiftText)'}.',
        ),
        Method.karachi: MethodTime(
          plainSunset,
          '0.833°',
          'sunset, sun 0.833° below the horizon. Elevation ignored.',
        ),
        Method.mujahid: MethodTime(
          plainSunset,
          '90°50′',
          'per Rafi, zenith distance 90°50′ (= 0.833°), when the whole disc is '
              'below the horizon; calendar seconds are rounded up to the minute.',
        ),
      },
    ),
  );

  // ── Isha ──────────────────────────────────────────────────────────────
  header('Step 5 · Isha');
  final sIshaHa = ha(-Rules.sunniIsha);
  final kIshaHa = ha(-Rules.karachiIsha);
  final mIshaHa = ha(-Rules.mujahidIsha);
  final sIsha = evening(sIshaHa);
  final kIsha = evening(kIshaHa);
  final mIsha = evening(mIshaHa);
  line(haLine('Sunni', -Rules.sunniIsha, sIshaHa, sIsha));
  line(haLine('Karachi', -Rules.karachiIsha, kIshaHa, kIsha));
  line(haLine('Mujahid', -Rules.mujahidIsha, mIshaHa, mIsha));
  addRow(
    PrayerRow(
      prayer: Prayer.isha,
      methods: {
        Method.sunni: MethodTime(
          sIsha,
          '18°',
          'red twilight disappears at 18° below the true horizon (17° after '
              'the visible sunset).',
        ),
        Method.karachi: MethodTime(
          kIsha,
          '18°',
          'the method\'s Isha angle, 18°.',
        ),
        Method.mujahid: MethodTime(
          mIsha,
          '18°',
          '18°. Darimi says Mujahids use 18°; Rafi cites al-Biruni: twilight '
              'ends at 18°.',
        ),
      },
    ),
  );

  // ── Summary ───────────────────────────────────────────────────────────
  header('Summary');
  line(
    '${'Prayer'.padRight(12)}${'Sunni'.padRight(10)}'
    '${'Karachi'.padRight(20)}Mujahid',
  );
  for (final r in rows) {
    String cell(Method m) {
      final t = r[m].time;
      if (t == null) return '—';
      if (m == Method.sunni) return hms(t);
      final s = r.diffFromSunni(m)!;
      return '${hms(t)} (${s == 0 ? 'same' : signedDiff(s)})';
    }

    line(
      '${r.prayer.label.padRight(12)}${cell(Method.sunni).padRight(10)}'
      '${cell(Method.karachi).padRight(20)}${cell(Method.mujahid)}',
    );
  }
  note('Brackets: later (+) or earlier (−) than Sunni.');

  // ── Sources & conflicts ───────────────────────────────────────────────
  header('Sources & conflicts');
  for (final m in Method.values) {
    note('${m.label}: ${m.source}.');
  }
  final sunni19 = at(morning(ha(-Rules.rafiSunniFajr)));
  if (sunni19 != null) {
    note(
      'Conflict: Rafi says Sunni mosques give Fajr at 19°. Darimi gives '
      '20° to the sun\'s centre (= 19° to the visible horizon). This app '
      'uses 20°. Read as 19° to the centre, Fajr would be $sunni19.',
    );
  }
  // Measured on sunrise, the same figure as the Sunrise row's difference.
  final dipSunrise = morning(dipHa);
  if (input.elevation > 0 && plainSunrise != null && dipSunrise != null) {
    final standard = toSeconds(plainSunrise) - toSeconds(dipSunrise);
    note(
      'Conflict: Rafi puts elevation at about 1 min per 1500 m '
      '(${rafiElevationSeconds.toStringAsFixed(1)} s here). The standard '
      'dip formula gives ${signedDiff(standard).replaceFirst('+', '')} '
      'here${useDip ? ' and is used for Sunni' : ' (turned off)'}.',
    );
  }
  note(
    'Darimi (2020) says some Mujahid mosques now follow Sunni times for '
    'Subh and Maghrib, so mosque practice may differ.',
  );
  note(
    'Times are for this exact point. Printed Samastha calendars give one '
    'time per zone (Kozhikode, Kasaragod, Kochi, Thiruvananthapuram), so '
    'they can differ by a few minutes.',
  );
  note('On screen, prayer start times round up and sunrise rounds down.');

  return CalcResult(input: input, sun: sun, dip: dip, rows: rows, log: log);
}
